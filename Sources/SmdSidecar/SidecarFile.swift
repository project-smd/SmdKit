// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation
import SmdKit
#if canImport(FoundationXML)
import FoundationXML
#endif

/// The sidecar as a file. It is the repository file with a library's facts in it, and it is read
/// and written that way: `ContainerFile` reads the container and writes it, and one pass over the
/// same document reads and writes the `<presentation>` elements under each item — each with where it
/// came from and how it was made — the `<rules>` of each binding an item has, the `smd` path on each
/// child, and the container's `<rules>` reference. Nothing here knows how a container is spelled,
/// what a natural key means, or what a rule says.
///
/// Writing has two modes. **Generate** makes a document from the value. **Update** takes the
/// document that is already on disk and changes only what a library changes — presentations, and
/// which file a child is in — leaving comments, order and anything hand-written alone, and adding
/// an item the document lacks at the end of its sequence. A container's own fields are not
/// rewritten by an update, and nor is which rules it or any of its bindings uses, which a person
/// decides and a placement knows nothing of; a sidecar that has drifted from the repository is the validator's to report, not
/// the writer's to resolve.
///
/// What an update leaves alone has setters of its own, each changing only what it names: the
/// container's own fields, the container's rules, and a binding's rules.
public enum SidecarFile {
    public static let fileName = "container.smd"

    // MARK: - Reading

    public static func sidecar(from data: Data) throws -> Sidecar {
        let container = try ContainerFile.container(from: data)
        let document = try XMLDocument(data: data, options: [])
        guard let root = document.rootElement() else { throw ContainerFileError.notAContainer }

        var sidecar = Sidecar(container: container)
        for item in items(in: root) {
            if let path = item.attribute("smd"), let child = item.attribute("container").flatMap(ContainerID.init) {
                sidecar.children[child] = path
            }
            guard let id = item.attribute("id") else { continue }
            let presentations = try item.elements(forName: "presentation").map(presentation)
            if !presentations.isEmpty {
                sidecar.presentations[id] = presentations
            }
            let bindingRules = try bindingRules(of: item)
            if !bindingRules.isEmpty {
                sidecar.bindingRules[id] = bindingRules
            }
        }
        let rules = root.elements(forName: "rules")
        guard rules.count <= 1 else { throw SidecarFileError.multipleRules }
        sidecar.rules = try rules.first.map(Self.rules)
        return sidecar
    }

    /// The reference a `<rules>` element makes. One that holds rules is refused rather than read for
    /// its attributes: the rules written inside would be dropped without a word.
    private static func rules(_ element: XMLElement) throws -> SidecarRules {
        guard !(element.children ?? []).contains(where: { $0.kind == .element }) else { throw SidecarFileError.inlineRules }
        let path = try element.required("path")
        guard !path.isEmpty else { throw ContainerFileError.invalidValue(element: "rules", attribute: "path", value: path) }
        return SidecarRules(path: path, activeVersion: try element.counting("activeVersion"))
    }

    /// An item's `<rules>`, each a binding's: one per binding, every one naming it.
    private static func bindingRules(of item: XMLElement) throws -> [BindingRules] {
        var found: [BindingRules] = []
        for element in item.elements(forName: "rules") {
            let binding = try element.uuid("binding")
            guard !found.contains(where: { $0.binding == binding }) else { throw SidecarFileError.multipleRules }
            found.append(BindingRules(binding: binding, rules: try rules(element)))
        }
        return found
    }

    private static func presentation(_ element: XMLElement) throws -> Presentation {
        var presentation = Presentation(
            alternative: element.attribute("alternative"),
            profile: element.attribute("profile"),
            file: try element.required("file")
        )
        presentation.source = try element.single("source").map(source)
        presentation.transform = try element.single("transform").map(transform)
        presentation.tracks = try element.elements(forName: "track").map {
            TrackMapping(feature: try $0.required("feature"), audio: try $0.optionalInteger("audio"), subtitle: try $0.optionalInteger("subtitle"))
        }
        presentation.chapters = try element.elements(forName: "chapter").map {
            Chapter(index: try $0.integer("index"), title: try $0.required("title"))
        }
        return presentation
    }

    /// Where a presentation came from: its binding and the copy of the binding's segments.
    private static func source(_ element: XMLElement) throws -> PresentationSource {
        let binding = try element.uuid("binding")
        let segments = try element.elements(forName: "segment").map { segment in
            let key = try segment.pair("scheme", "value").map { NaturalKey(scheme: $0, value: $1) }
            let chapters = try segment.pair("from", "to").map { _, to in
                let span = ChapterSpan(from: try segment.counting("from"), to: try segment.counting("to"))
                guard span.from <= span.to else { throw ContainerFileError.invalidValue(element: "segment", attribute: "to", value: to) }
                return span
            }
            return PresentationSource.Segment(key: key, chapters: chapters)
        }
        guard !segments.isEmpty else { throw ContainerFileError.missingElement(element: "source", child: "segment") }
        return PresentationSource(binding: binding, segments: segments)
    }

    /// How a presentation was made: the ruleset, and each layer naming exactly one subject.
    private static func transform(_ element: XMLElement) throws -> Transform {
        let ruleset = try element.required("ruleset")
        guard !ruleset.isEmpty else { throw ContainerFileError.invalidValue(element: "transform", attribute: "ruleset", value: ruleset) }
        let layers = try element.elements(forName: "layer").map { layer in
            let subject: Transform.Layer.Subject
            switch (layer.attribute("binding"), layer.attribute("container")) {
            case (_?, let container?):
                throw ContainerFileError.invalidValue(element: "layer", attribute: "container", value: container)
            case (_?, nil):
                subject = .binding(try layer.uuid("binding"))
            case (nil, let container?):
                guard let id = ContainerID(container) else { throw ContainerFileError.invalidValue(element: "layer", attribute: "container", value: container) }
                subject = .container(id)
            case (nil, nil):
                throw ContainerFileError.missingAttribute(element: "layer", attribute: "binding")
            }
            return Transform.Layer(subject, version: try layer.counting("version"), digest: layer.attribute("digest"))
        }
        return Transform(ruleset: ruleset, version: try element.counting("version"), layers: layers)
    }

    // MARK: - Writing

    /// A document from the value alone.
    public static func data(for sidecar: Sidecar) throws -> Data {
        let document = try XMLDocument(data: ContainerFile.data(for: sidecar.container), options: [])
        try apply(sidecar, to: document)
        if let root = document.rootElement() {
            let byID = Dictionary(items(in: root).compactMap { item in item.attribute("id").map { ($0, item) } }, uniquingKeysWith: { first, _ in first })
            for (id, bindingRules) in sidecar.bindingRules where !bindingRules.isEmpty {
                guard let item = byID[id] else { throw SidecarFileError.unknownItem(id) }
                for binding in bindingRules { insertBeforePresentations(binding.rules.element(binding: binding.binding), in: item) }
            }
            if let rules = sidecar.rules {
                root.addChild(rules.element())
            }
        }
        return XMLWriter.data(for: document)
    }

    /// The document on disk, with the library's facts brought up to the value's. Refused when the
    /// document describes a different container.
    public static func data(for sidecar: Sidecar, updating existing: Data) throws -> Data {
        let current = try ContainerFile.container(from: existing, expecting: sidecar.container.id)
        _ = current
        let document = try XMLDocument(data: existing, options: [])
        try apply(sidecar, to: document)
        return XMLWriter.data(for: document)
    }

    /// The document on disk with its `<rules>` reference replaced where it stands, added last when it
    /// has none, or removed for nil — and nothing else changed. The one way the rules a container
    /// uses change, so that filing a file never does it by accident.
    public static func data(settingRules rules: SidecarRules?, in existing: Data) throws -> Data {
        _ = try ContainerFile.container(from: existing)
        let document = try XMLDocument(data: existing, options: [])
        guard let root = document.rootElement() else { throw ContainerFileError.notAContainer }
        let present = root.elements(forName: "rules")
        let position = present.first.flatMap { root.children?.firstIndex(of: $0) }
        for element in present { element.detach() }
        if let rules {
            if let position {
                root.insertChild(rules.element(), at: position)
            } else {
                root.addChild(rules.element())
            }
        }
        return XMLWriter.data(for: document)
    }

    /// The document on disk with one item's `<rules>` for one binding replaced where it stands, added
    /// before the item's presentations when it has none, or removed for nil — and nothing else
    /// changed. The one way a binding's rules change, so that filing a file never does it by accident.
    public static func data(settingRules rules: SidecarRules?, binding: String, item id: String, in existing: Data) throws -> Data {
        _ = try ContainerFile.container(from: existing)
        guard UUID(uuidString: binding) != nil else { throw ContainerFileError.invalidValue(element: "rules", attribute: "binding", value: binding) }
        let document = try XMLDocument(data: existing, options: [])
        guard let root = document.rootElement() else { throw ContainerFileError.notAContainer }
        guard let item = items(in: root).first(where: { $0.attribute("id") == id }) else { throw SidecarFileError.unknownItem(id) }
        let present = item.elements(forName: "rules").filter { $0.attribute("binding") == binding }
        let position = present.first.flatMap { item.children?.firstIndex(of: $0) }
        for element in present { element.detach() }
        if let rules {
            if let position {
                item.insertChild(rules.element(binding: binding), at: position)
            } else {
                insertBeforePresentations(rules.element(binding: binding), in: item)
            }
        }
        return XMLWriter.data(for: document)
    }

    /// The document on disk with the container's own fields made the value's — what it says of
    /// itself and its structure, everything `ContainerFile` writes — and the library's facts kept:
    /// each item's presentations and binding rules, each child's `smd` path, and the container's
    /// `<rules>` reference. Refused when the value is another container's. The counterpart of an
    /// update, which keeps the own fields and changes only the facts.
    ///
    /// The value decides what the container holds and in what order. An element whose content the
    /// value does not change is kept as it stands, comments and mixed content inside it included,
    /// and an item it still declares keeps its element wherever the value now puts it, with the
    /// comments before it and its facts. An item the value no longer declares is removed with its
    /// facts — whoever edits a container decides first whether a library may lose them — and a
    /// child's path is kept for a child container the value still holds. What the document holds
    /// that is neither the value's nor a fact the sidecar reads, a comment or an element no reader
    /// knows, stays before the element it stood before, or last when that element is gone.
    public static func data(settingContainer container: Container, in existing: Data) throws -> Data {
        _ = try ContainerFile.container(from: existing, expecting: container.id)
        let document = try XMLDocument(data: existing, options: [])
        guard let root = document.rootElement() else { throw ContainerFileError.notAContainer }
        guard let value = try XMLDocument(data: ContainerFile.data(for: container), options: []).rootElement() else {
            throw ContainerFileError.notAContainer
        }

        // Facts that are keyed by something other than where they stand: a child's path by the
        // container it names, and an item, with its presentations and rules, by its id, wherever
        // in the sequences or extras the value moves it.
        var paths: [String: String] = [:]
        for item in items(in: root) {
            if let child = item.attribute("container"), let path = item.attribute("smd"), paths[child] == nil { paths[child] = path }
        }
        var held: [String: Slot] = [:]
        for holder in root.elements(forName: "sequence") + root.elements(forName: "extras") {
            for slot in slots(of: holder) {
                if let item = slot.element, item.name == "item", let id = item.attribute("id"), held[id] == nil { held[id] = slot }
            }
        }

        merge(root, with: value, held: &held)
        for item in items(in: root) {
            item.removeAttribute(forName: "smd")
            item.set("smd", item.attribute("container").flatMap { paths[$0] })
        }
        return XMLWriter.data(for: document)
    }

    /// An element of the document and the comments, instructions and text that stand before it;
    /// or, with no element, those that stand after the last.
    private struct Slot {
        var leading: [XMLNode]
        var element: XMLElement?
    }

    /// The elements `ContainerFile` writes inside each element it writes children into. Anything
    /// else inside one is not the container's own, and is kept by setting it.
    private static let ownChildren: [String: Set<String>] = [
        "container": ["title", "year", "typeLabel", "outline", "externalRef", "alternatives", "features", "sequence", "extras"],
        "alternatives": ["alternative"],
        "alternative": ["title", "outline"],
        "features": ["feature"],
        "feature": ["title", "participant"],
        "sequence": ["item"],
        "extras": ["item"],
        "item": ["title", "outline", "externalRef"],
    ]

    private static func slots(of element: XMLElement) -> [Slot] {
        var slots: [Slot] = []
        var leading: [XMLNode] = []
        for node in element.children ?? [] {
            if let child = node as? XMLElement, node.kind == .element {
                slots.append(Slot(leading: leading, element: child))
                leading = []
            } else if node.kind != .text || !(node.stringValue ?? "").allSatisfy(\.isWhitespace) {
                leading.append(node)
            }
        }
        if !leading.isEmpty { slots.append(Slot(leading: leading, element: nil)) }
        return slots
    }

    /// What tells one of an element's children from its siblings of the same name.
    private static func key(_ element: XMLElement) -> String {
        let name = element.name ?? ""
        if let id = element.attribute("id") { return "\(name)#id=\(id)" }
        if let ref = element.attribute("ref") { return "\(name)#ref=\(ref)" }
        if name == "externalRef" { return "\(name)#\(element.attribute("provider") ?? "")=\(element.attribute("value") ?? "")" }
        if name == "participant" { return "\(name)#\(element.attribute("name") ?? "")=\(element.attribute("role") ?? "")" }
        return name
    }

    /// Whether the repository reader reads the same from the two: their attributes and their text.
    private static func reads(_ existing: XMLElement, as value: XMLElement) -> Bool {
        func attributes(_ element: XMLElement) -> [String: String] {
            Dictionary((element.attributes ?? []).map { ($0.name ?? "", $0.stringValue ?? "") }, uniquingKeysWith: { first, _ in first })
        }
        func text(_ element: XMLElement) -> String {
            (element.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return existing.name == value.name && attributes(existing) == attributes(value) && text(existing) == text(value)
    }

    /// The existing element given the value's attributes and own children, in the value's order,
    /// keeping its own children the value does not change and every child that is not its own.
    private static func merge(_ existing: XMLElement, with value: XMLElement, held: inout [String: Slot]) {
        existing.attributes = (value.attributes ?? []).map { XMLNode.attribute(withName: $0.name ?? "", stringValue: $0.stringValue ?? "") as! XMLNode }
        let own = ownChildren[existing.name ?? ""] ?? []
        let slots = slots(of: existing)

        var matching: [String: [Slot]] = [:]
        for slot in slots {
            guard let element = slot.element, own.contains(element.name ?? "") else { continue }
            if element.name == "item", element.attribute("id") != nil { continue }
            matching[key(element), default: []].append(slot)
        }

        var placed: [(leading: [XMLNode], element: XMLElement)] = []
        for case let child as XMLElement in value.children ?? [] {
            let slot: Slot?
            if child.name == "item", let id = child.attribute("id") {
                slot = held.removeValue(forKey: id)
            } else if var candidates = matching[key(child)], !candidates.isEmpty {
                slot = candidates.removeFirst()
                matching[key(child)] = candidates
            } else {
                slot = nil
            }
            if let slot, let element = slot.element {
                if ownChildren[child.name ?? ""] != nil {
                    merge(element, with: child, held: &held)
                    placed.append((slot.leading, element))
                } else {
                    placed.append((slot.leading, reads(element, as: child) ? element : child))
                }
            } else {
                placed.append(([], child))
            }
        }

        // What is not the container's own goes before the next of its own elements that is still
        // here, or last.
        var before: [ObjectIdentifier: [Slot]] = [:]
        var last: [Slot] = []
        let kept = Set(placed.map { ObjectIdentifier($0.element) })
        for (index, slot) in slots.enumerated() {
            if let element = slot.element, own.contains(element.name ?? "") { continue }
            let anchor = slots[(index + 1)...].lazy.compactMap(\.element).first { own.contains($0.name ?? "") && kept.contains(ObjectIdentifier($0)) }
            if let anchor { before[ObjectIdentifier(anchor), default: []].append(slot) } else { last.append(slot) }
        }

        var children: [XMLNode] = []
        for (leading, element) in placed {
            for slot in before[ObjectIdentifier(element)] ?? [] { children += slot.leading + (slot.element.map { [$0] } ?? []) }
            children += leading + [element]
        }
        for slot in last { children += slot.leading + (slot.element.map { [$0] } ?? []) }

        for child in existing.children ?? [] { child.detach() }
        for child in children {
            child.detach()
            existing.addChild(child)
        }
    }

    /// An item's `<rules>` go before its presentations, which are the rest of what a library keeps
    /// on it.
    private static func insertBeforePresentations(_ element: XMLElement, in item: XMLElement) {
        if let first = item.elements(forName: "presentation").first, let index = item.children?.firstIndex(of: first) {
            item.insertChild(element, at: index)
        } else {
            item.addChild(element)
        }
    }

    private static func apply(_ sidecar: Sidecar, to document: XMLDocument) throws {
        guard let root = document.rootElement() else { throw ContainerFileError.notAContainer }
        let present = items(in: root)
        var byID: [String: XMLElement] = [:]
        for item in present {
            if let id = item.attribute("id") { byID[id] = item }
        }

        // Items the document lacks: appended to the sequence or extras that hold them, which is
        // created when the document lacks that too.
        for sequence in sidecar.container.sequences {
            for entry in sequence.items {
                guard let id = entry.id?.value, byID[id] == nil else { continue }
                let holder = sequenceElement(in: root, id: sequence.id)
                let element = itemElement(entry)
                holder.addChild(element)
                byID[id] = element
            }
        }
        for entry in sidecar.container.extras {
            guard let id = entry.id?.value, byID[id] == nil else { continue }
            let holder = extrasElement(in: root)
            let element = itemElement(entry)
            holder.addChild(element)
            byID[id] = element
        }

        // The library's facts: the value's replace the document's for every item and child the
        // value's container declares, so a fact the value no longer has is removed. Items only the
        // document has are drift, left with their facts for a validator to report.
        let entries = sidecar.container.sequences.flatMap(\.items) + sidecar.container.extras
        let declared = Set(entries.compactMap { $0.id?.value })
        let held = Set(entries.compactMap { entry -> ContainerID? in
            if case .child(let child) = entry { return child.container }
            return nil
        })
        for (id, item) in byID where declared.contains(id) && sidecar.presentations[id] == nil {
            for existing in item.elements(forName: "presentation") { existing.detach() }
        }
        for (id, presentations) in sidecar.presentations {
            guard let item = byID[id] else { throw SidecarFileError.unknownItem(id) }
            for existing in item.elements(forName: "presentation") { existing.detach() }
            for presentation in presentations { item.addChild(presentationElement(presentation)) }
        }
        for item in byID.values {
            guard let child = item.attribute("container").flatMap(ContainerID.init), held.contains(child) else { continue }
            item.removeAttribute(forName: "smd")
            item.set("smd", sidecar.children[child])
        }
    }

    private static func presentationElement(_ presentation: Presentation) -> XMLElement {
        let element = XMLElement(name: "presentation")
        element.set("alternative", presentation.alternative)
        element.set("profile", presentation.profile)
        element.set("file", presentation.file)
        if let source = presentation.source {
            let child = XMLElement(name: "source")
            child.set("binding", source.binding)
            for segment in source.segments {
                let part = XMLElement(name: "segment")
                part.set("scheme", segment.key?.scheme)
                part.set("value", segment.key?.value)
                part.set("from", segment.chapters.map { String($0.from) })
                part.set("to", segment.chapters.map { String($0.to) })
                child.addChild(part)
            }
            element.addChild(child)
        }
        if let transform = presentation.transform {
            let child = XMLElement(name: "transform")
            child.set("ruleset", transform.ruleset)
            child.set("version", String(transform.version))
            for layer in transform.layers {
                let part = XMLElement(name: "layer")
                switch layer.subject {
                case .binding(let binding): part.set("binding", binding)
                case .container(let container): part.set("container", container.value)
                }
                part.set("version", String(layer.version))
                part.set("digest", layer.digest)
                child.addChild(part)
            }
            element.addChild(child)
        }
        for track in presentation.tracks {
            let child = XMLElement(name: "track")
            child.set("feature", track.feature)
            child.set("audio", track.audio.map(String.init))
            child.set("subtitle", track.subtitle.map(String.init))
            element.addChild(child)
        }
        for chapter in presentation.chapters {
            let child = XMLElement(name: "chapter")
            child.set("index", String(chapter.index))
            child.set("title", chapter.title)
            element.addChild(child)
        }
        return element
    }

    /// An item as `ContainerFile` spells it, for the one the document lacks.
    private static func itemElement(_ entry: Entry) -> XMLElement {
        var container = Container(id: ContainerID.mint(), type: .series, title: Title(rawValue: "-")!)
        container.sequences = [Sequence(items: [entry])]
        let document = try? XMLDocument(data: ContainerFile.data(for: container), options: [])
        let item = document?.rootElement()?.elements(forName: "sequence").first?.elements(forName: "item").first
        item?.detach()
        return item ?? XMLElement(name: "item")
    }

    private static func sequenceElement(in root: XMLElement, id: String?) -> XMLElement {
        if let existing = root.elements(forName: "sequence").first(where: { $0.attribute("id") == id }) {
            return existing
        }
        let element = XMLElement(name: "sequence")
        element.set("id", id)
        if let extras = root.elements(forName: "extras").first, let index = root.children?.firstIndex(of: extras) {
            root.insertChild(element, at: index)
        } else {
            root.addChild(element)
        }
        return element
    }

    private static func extrasElement(in root: XMLElement) -> XMLElement {
        if let existing = root.elements(forName: "extras").first { return existing }
        let element = XMLElement(name: "extras")
        root.addChild(element)
        return element
    }

    private static func items(in root: XMLElement) -> [XMLElement] {
        root.elements(forName: "sequence").flatMap { $0.elements(forName: "item") }
            + root.elements(forName: "extras").flatMap { $0.elements(forName: "item") }
    }
}

public enum SidecarFileError: Error, Equatable, LocalizedError {
    /// A presentation, or a binding's rules, for an item the container does not have.
    case unknownItem(String)
    /// Two `<rules>` elements on one container, or on one item for one binding, with no answer to
    /// which applies.
    case multipleRules
    /// A `<rules>` element holding rules, where it should name the version file that holds them.
    case inlineRules

    public var errorDescription: String? {
        switch self {
        case .unknownItem(let id): "The container has no item \(id) to hold a presentation or rules"
        case .multipleRules: "More than one <rules> element names the same rules: two on the container, or two for one binding on an item"
        case .inlineRules: "A <rules> element holds rules; it names a version file instead, as <rules path=\"rules\" activeVersion=\"1\"/>"
        }
    }
}

// MARK: - XML helpers

private extension XMLElement {
    func set(_ name: String, _ value: String?) {
        guard let value else { return }
        addAttribute(XMLNode.attribute(withName: name, stringValue: value) as! XMLNode)
    }

    func attribute(_ name: String) -> String? {
        attribute(forName: name)?.stringValue
    }

    func required(_ name: String) throws -> String {
        guard let value = attribute(name) else {
            throw ContainerFileError.missingAttribute(element: self.name ?? "?", attribute: name)
        }
        return value
    }

    func integer(_ name: String) throws -> Int {
        let value = try required(name)
        guard let integer = Int(value) else {
            throw ContainerFileError.invalidValue(element: self.name ?? "?", attribute: name, value: value)
        }
        return integer
    }

    /// An integer from one: a version, or a chapter.
    func counting(_ name: String) throws -> Int {
        let value = try integer(name)
        guard value >= 1 else {
            throw ContainerFileError.invalidValue(element: self.name ?? "?", attribute: name, value: String(value))
        }
        return value
    }

    /// An attribute that must be a UUID, kept as written.
    func uuid(_ name: String) throws -> String {
        let value = try required(name)
        guard UUID(uuidString: value) != nil else {
            throw ContainerFileError.invalidValue(element: self.name ?? "?", attribute: name, value: value)
        }
        return value
    }

    /// Two attributes that come together or not at all: nil for neither, and the missing one named
    /// when only one is given.
    func pair(_ first: String, _ second: String) throws -> (String, String)? {
        switch (attribute(first), attribute(second)) {
        case (nil, nil): return nil
        case (let a?, let b?): return (a, b)
        case (nil, _?): throw ContainerFileError.missingAttribute(element: self.name ?? "?", attribute: first)
        case (_?, nil): throw ContainerFileError.missingAttribute(element: self.name ?? "?", attribute: second)
        }
    }

    /// The one child of a name, nil for none, refused when there are more.
    func single(_ child: String) throws -> XMLElement? {
        let found = elements(forName: child)
        guard found.count <= 1 else {
            throw ContainerFileError.invalidValue(element: self.name ?? "?", attribute: child, value: "\(found.count) elements")
        }
        return found.first
    }

    func optionalInteger(_ name: String) throws -> Int? {
        guard let value = attribute(name) else { return nil }
        guard let integer = Int(value) else {
            throw ContainerFileError.invalidValue(element: self.name ?? "?", attribute: name, value: value)
        }
        return integer
    }
}
