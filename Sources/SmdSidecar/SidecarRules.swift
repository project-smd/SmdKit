// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation
import SmdKit
#if canImport(FoundationXML)
import FoundationXML
#endif

/// A container's `<rules>`: which version of the encoding rules a library applies to what the
/// container holds. The rules themselves are not in the sidecar. Each version is a file of its own
/// in a folder beside it, `<path>/<version>.xml`, so a library keeps every version a file was made
/// by, and the sidecar names the folder and the version in force:
///
/// ```xml
/// <rules path="rules" version="4"/>
/// ```
///
/// This package reads neither the folder nor the files: the rules are in the language of the server
/// that applies them, which is the one reader that knows what they mean, and which versions exist is
/// that server's to know.
public struct SidecarRules: Hashable, Sendable {
    /// The folder of the container's rule versions, relative to the sidecar's own folder, as a
    /// child's `smd` path is.
    public var path: String
    /// The version in force, from 1.
    public var version: Int

    public init(path: String = "rules", version: Int) {
        self.path = path
        self.version = version
    }

    /// The version's file, relative to the sidecar's folder: `rules/4.xml`.
    public var file: String {
        "\(path)/\(version).xml"
    }

    /// The reference as the element a document adopts.
    var element: XMLElement {
        let element = XMLElement(name: "rules")
        element.addAttribute(XMLNode.attribute(withName: "path", stringValue: path) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "version", stringValue: String(version)) as! XMLNode)
        return element
    }
}
