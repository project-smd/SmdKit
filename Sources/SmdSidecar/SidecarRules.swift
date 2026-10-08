// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation
import SmdKit
#if canImport(FoundationXML)
import FoundationXML
#endif

/// A `<rules>` reference: which version of the encoding rules a library applies to what a container
/// holds, or to what is made from one binding. The rules themselves are not in the sidecar. Each
/// version is a file of its own in a folder beside it, `<path>/<version>.xml`, so a library keeps
/// every version a file was made by, and the sidecar names the folder and, of the versions in it,
/// the one in force:
///
/// ```xml
/// <rules path="rules" activeVersion="4"/>
/// ```
///
/// This package reads neither the folder nor the files: the rules are in the language of the server
/// that applies them, which is the one reader that knows what they mean, and which versions exist is
/// that server's to know.
public struct SidecarRules: Hashable, Sendable, Codable {
    /// The folder of every version of the rules, relative to the sidecar's own folder, as a child's
    /// `smd` path is.
    public var path: String
    /// The version in force, from 1. The others stay in the folder for the files they made.
    public var activeVersion: Int

    public init(path: String = "rules", activeVersion: Int) {
        self.path = path
        self.activeVersion = activeVersion
    }

    /// Any version's file, relative to the sidecar's folder: `rules/2.xml`. A reader needs it to read
    /// the rules a presentation's `<layer>` names while another version is in force.
    public func file(version: Int) -> String {
        "\(path)/\(version).xml"
    }

    /// The file of the version in force: `rules/4.xml`.
    public var activeFile: String {
        file(version: activeVersion)
    }

    /// The reference as the element a document adopts, naming its binding when it is a binding's.
    func element(binding: String? = nil) -> XMLElement {
        let element = XMLElement(name: "rules")
        if let binding {
            element.addAttribute(XMLNode.attribute(withName: "binding", stringValue: binding) as! XMLNode)
        }
        element.addAttribute(XMLNode.attribute(withName: "path", stringValue: path) as! XMLNode)
        element.addAttribute(XMLNode.attribute(withName: "activeVersion", stringValue: String(activeVersion)) as! XMLNode)
        return element
    }
}
