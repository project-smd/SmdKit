// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation
import SmdKit
#if canImport(FoundationXML)
import FoundationXML
#endif

/// The sidecar as a file. It is the repository file with a library's facts in it, and it is read
/// and written that way: `ContainerFile` reads the container and writes it, and one pass over the
/// same document reads and writes the `<presentation>` elements under each item, the `smd`
/// path on each child, and the container's `<rules>` reference. Nothing here knows how a container
/// is spelled, or what a rule says.
///
/// Writing has two modes. **Generate** makes a document from the value. **Update** takes the
/// document that is already on disk and changes only what a library changes — presentations, and
/// which file a child is in — leaving comments, order and anything hand-written alone, and adding
/// an item the document lacks at the end of its sequence. A container's own fields are not
/// rewritten by an update, and nor is which rules it uses, which a person decides and a placement
/// knows nothing of; a sidecar that has drifted from the repository is the validator's to report, not
/// the writer's to resolve.
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
        let version = try element.integer("version")
        guard version >= 1 else { throw ContainerFileError.invalidValue(element: "rules", attribute: "version", value: String(version)) }
        return SidecarRules(path: path, version: version)
    }

    private static func presentation(_ element: XMLElement) throws -> Presentation {
        var presentation = Presentation(
            alternative: element.attribute("alternative"),
            profile: element.attribute("profile"),
            file: try element.required("file")
        )
        if let source = element.elements(forName: "source").first {
            presentation.source = SourceRef(disc: try source.required("disc"), playlist: try source.required("playlist"))
        }
        presentation.tracks = try element.elements(forName: "track").map {
            TrackMapping(feature: try $0.required("feature"), audio: try $0.optionalInteger("audio"), subtitle: try $0.optionalInteger("subtitle"))
        }
        presentation.chapters = try element.elements(forName: "chapter").map {
            Chapter(index: try $0.integer("index"), title: try $0.required("title"))
        }
        return presentation
    }

    // MARK: - Writing

    /// A document from the value alone.
    public static func data(for sidecar: Sidecar) throws -> Data {
        let document = try XMLDocument(data: ContainerFile.data(for: sidecar.container), options: [])
        try apply(sidecar, to: document)
        if let rules = sidecar.rules {
            document.rootElement()?.addChild(rules.element)
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
                root.insertChild(rules.element, at: position)
            } else {
                root.addChild(rules.element)
            }
        }
        return XMLWriter.data(for: document)
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
            child.set("disc", source.disc)
            child.set("playlist", source.playlist)
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
    /// A presentation for an item the container does not have.
    case unknownItem(String)
    /// Two `<rules>` elements on one container, with no answer to which applies.
    case multipleRules
    /// A `<rules>` element holding rules, where it should name the version file that holds them.
    case inlineRules

    public var errorDescription: String? {
        switch self {
        case .unknownItem(let id): "The container has no item \(id) to hold a presentation"
        case .multipleRules: "The container has more than one <rules> element"
        case .inlineRules: "The container's <rules> element holds rules; it names a version file instead, as <rules path=\"rules\" version=\"1\"/>"
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

    func optionalInteger(_ name: String) throws -> Int? {
        guard let value = attribute(name) else { return nil }
        guard let integer = Int(value) else {
            throw ContainerFileError.invalidValue(element: self.name ?? "?", attribute: name, value: value)
        }
        return integer
    }
}
