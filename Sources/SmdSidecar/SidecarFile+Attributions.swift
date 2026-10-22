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

/// Setting a sidecar's attributions and declined references on disk, each kind replaced whole and
/// nothing else changed.
extension SidecarFile {
    /// The document on disk with its `<attribution>` children of `<container>` replaced by the given
    /// ones, where the first of them stood, or before the container's `<rules>` when there were none,
    /// or last — and nothing else changed. The one way attributions change.
    public static func data(settingAttributions attributions: [Attribution], in existing: Data) throws -> Data {
        try data(replacing: "attribution", with: attributions.map(attributionElement), in: existing)
    }

    /// The document on disk with its `<declined>` children of `<container>` replaced by the given
    /// references, placed as `data(settingAttributions:in:)` places attributions, and nothing else
    /// changed. The one way the declined references change.
    public static func data(settingDeclined declined: [ExternalRef], in existing: Data) throws -> Data {
        try data(replacing: "declined", with: declined.map(declinedElement), in: existing)
    }

    private static func data(replacing name: String, with elements: [XMLElement], in existing: Data) throws -> Data {
        _ = try ContainerFile.container(from: existing)
        let document = try XMLDocument(data: existing, options: [])
        guard let root = document.rootElement() else { throw ContainerFileError.notAContainer }
        let present = root.elements(forName: name)
        let anchor = present.first ?? root.elements(forName: "rules").first
        if let anchor, let index = root.children?.firstIndex(of: anchor) {
            for (offset, element) in elements.enumerated() { root.insertChild(element, at: index + offset) }
        } else {
            for element in elements { root.addChild(element) }
        }
        for element in present { element.detach() }
        return XMLWriter.data(for: document)
    }

    static func attributionElement(_ attribution: Attribution) -> XMLElement {
        let element = XMLElement(name: "attribution")
        element.set("subject", attribution.subject.rawValue)
        element.set("provider", attribution.provider.rawValue)
        element.set("value", attribution.value)
        return element
    }

    static func declinedElement(_ ref: ExternalRef) -> XMLElement {
        let element = XMLElement(name: "declined")
        element.set("provider", ref.provider.rawValue)
        element.set("value", ref.value)
        return element
    }
}
