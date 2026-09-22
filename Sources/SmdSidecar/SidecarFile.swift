// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation
import SmdKit
#if canImport(FoundationXML)
import FoundationXML
#endif

/// The sidecar as a file. It is the repository file with a library's facts in it, and it is read
/// and written that way: `ContainerFile` reads the container and writes it, and one pass over the
/// same document reads and writes the `<presentation>` elements under each item and the `smd`
/// path on each child. Nothing here knows how a container is spelled.
///
/// Writing has two modes. **Generate** makes a document from the value. **Update** takes the
/// document that is already on disk and changes only what a library changes — presentations, and
/// which file a child is in — leaving comments, order and anything hand-written alone, and adding
/// an item the document lacks at the end of its sequence. A container's own fields are not
/// rewritten by an update; a sidecar that has drifted from the repository is the validator's to
/// report, not the writer's to resolve.
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
        return sidecar
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
        return serialise(document)
    }

    /// The document on disk, with the library's facts brought up to the value's. Refused when the
    /// document describes a different container.
    public static func data(for sidecar: Sidecar, updating existing: Data) throws -> Data {
        let current = try ContainerFile.container(from: existing, expecting: sidecar.container.id)
        _ = current
        let document = try XMLDocument(data: existing, options: [])
        try apply(sidecar, to: document)
        return serialise(document)
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
                guard let id = entry.id, byID[id] == nil else { continue }
                let holder = sequenceElement(in: root, id: sequence.id)
                let element = itemElement(entry)
                holder.addChild(element)
                byID[id] = element
            }
        }
        for entry in sidecar.container.extras {
            guard let id = entry.id, byID[id] == nil else { continue }
            let holder = extrasElement(in: root)
            let element = itemElement(entry)
            holder.addChild(element)
            byID[id] = element
        }

        for (id, presentations) in sidecar.presentations {
            guard let item = byID[id] else { throw SidecarFileError.unknownItem(id) }
            for existing in item.elements(forName: "presentation") { existing.detach() }
            for presentation in presentations { item.addChild(presentationElement(presentation)) }
        }
        for item in byID.values {
            guard let child = item.attribute("container").flatMap(ContainerID.init) else { continue }
            if let path = sidecar.children[child] {
                item.removeAttribute(forName: "smd")
                item.set("smd", path)
            }
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
        var container = Container(id: ContainerID.mint(), type: .series, title: "-")
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

    private static func serialise(_ document: XMLDocument) -> Data {
        document.version = "1.0"
        document.characterEncoding = "UTF-8"
        // A document parsed from data comes back marked standalone; the repository writer does
        // not say so, and a sidecar should read as the same file.
        document.isStandalone = false
        var data = document.xmlData(options: [.nodePrettyPrint, .nodeCompactEmptyElement])
        if data.last != UInt8(ascii: "\n") { data.append(UInt8(ascii: "\n")) }
        return data
    }
}

public enum SidecarFileError: Error, Equatable, LocalizedError {
    /// A presentation for an item the container does not have.
    case unknownItem(String)

    public var errorDescription: String? {
        switch self {
        case .unknownItem(let id): "The container has no item \(id) to hold a presentation"
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
