// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import SmdKit

// FoundationXML exists only where Foundation is split into modules, and there the lighter
// FoundationEssentials is all the rest of this file needs.
#if canImport(FoundationXML)
import FoundationEssentials
import FoundationXML
#else
import Foundation
#endif

/// Setting the container's own fields in a sidecar on disk: the value's structure merged into the
/// document's, keeping what the library and whoever edits the file put there.
extension SidecarFile {
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
            if let child = item.attribute("container"), let path = item.attribute("smd"), paths[child] == nil {
                paths[child] = path
            }
        }
        var held: [String: Slot] = [:]
        for holder in root.elements(forName: "sequence") + root.elements(forName: "extras") {
            for slot in slots(of: holder) {
                if let item = slot.element, item.name == "item", let id = item.attribute("id"), held[id] == nil {
                    held[id] = slot
                }
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
        "container": [
            "title", "year", "typeLabel", "outline", "externalRef", "alternatives", "features", "sequence", "extras",
        ],
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
        if name == "externalRef" {
            return "\(name)#\(element.attribute("provider") ?? "")=\(element.attribute("value") ?? "")"
        }
        if name == "participant" {
            return "\(name)#\(element.attribute("name") ?? "")=\(element.attribute("role") ?? "")"
        }
        return name
    }

    /// Whether the repository reader reads the same from the two: their attributes and their text.
    private static func reads(_ existing: XMLElement, as value: XMLElement) -> Bool {
        func attributes(_ element: XMLElement) -> [String: String] {
            Dictionary(
                (element.attributes ?? []).map { ($0.name ?? "", $0.stringValue ?? "") },
                uniquingKeysWith: { first, _ in first }
            )
        }
        func text(_ element: XMLElement) -> String {
            (element.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return existing.name == value.name && attributes(existing) == attributes(value) && text(existing) == text(value)
    }

    /// The existing element given the value's attributes and own children, in the value's order,
    /// keeping its own children the value does not change and every child that is not its own.
    private static func merge(_ existing: XMLElement, with value: XMLElement, held: inout [String: Slot]) {
        existing.attributes = (value.attributes ?? []).map {
            XMLNode.attribute(named: $0.name ?? "", value: $0.stringValue ?? "")
        }
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
            let anchor = slots[(index + 1)...].lazy.compactMap(\.element).first {
                own.contains($0.name ?? "") && kept.contains(ObjectIdentifier($0))
            }
            if let anchor { before[ObjectIdentifier(anchor), default: []].append(slot) } else { last.append(slot) }
        }

        var children: [XMLNode] = []
        for (leading, element) in placed {
            for slot in before[ObjectIdentifier(element)] ?? [] {
                children += slot.leading + (slot.element.map { [$0] } ?? [])
            }
            children += leading + [element]
        }
        for slot in last { children += slot.leading + (slot.element.map { [$0] } ?? []) }

        for child in existing.children ?? [] { child.detach() }
        for child in children {
            child.detach()
            existing.addChild(child)
        }
    }
}
