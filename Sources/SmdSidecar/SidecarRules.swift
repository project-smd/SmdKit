// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation
import SmdKit
#if canImport(FoundationXML)
import FoundationXML
#endif

/// A container's `<rules>`: the encoding rules a library applies to what the container holds, kept
/// in its sidecar so they travel with the library. This package carries the element and does not
/// read inside it — the rules are in the language of the server that applies them, which is the
/// one reader that knows what they mean.
///
/// The element is held in one form, as the sidecar writer writes an element at the top of a
/// document: four spaces of indentation for each level, counted from `<rules>` itself, comments
/// kept, the whitespace between elements replaced, mixed content as it stands. So two spellings of
/// one element are equal, a sidecar with rules reads back equal to the one written, and a server
/// that records which rules made a file can hash `xml` and get the same digest whatever the
/// indentation on disk.
public struct SidecarRules: Hashable, Sendable {
    /// The element, in the one form it is held in.
    public let xml: String

    /// Nil unless the text is well-formed XML whose root element is `<rules>`.
    public init?(xml: String) {
        let data = Data(xml.utf8)
        // Nothing is not a document, and on Linux the event parser calls it well-formed and the
        // document parser then crashes on it, so it is refused before either sees it.
        guard !data.isEmpty else { return nil }
        // Well-formedness first, through the event parser, as `ContainerFile` checks it: the
        // document parser on Linux is libxml2 in recovery mode, and closes a truncated element
        // for it.
        let parser = XMLParser(data: data)
        guard parser.parse(), parser.parserError == nil,
              let document = try? XMLDocument(data: data, options: []),
              let root = document.rootElement(), root.name == "rules"
        else { return nil }
        self.init(element: root)
    }

    init(element: XMLElement) {
        xml = XMLWriter.string(for: element)
    }

    /// A fresh copy of the element, detached, for a document to adopt.
    var element: XMLElement {
        // `xml` was written from a parsed `<rules>`, so it parses again to one.
        let root = try! XMLDocument(data: Data(xml.utf8), options: []).rootElement()!
        root.detach()
        return root
    }
}
