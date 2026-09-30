// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// The bytes of a document, written the same way on every platform.
///
/// Foundation's serialiser is not: Darwin writes `<?xml version="1.0" encoding="UTF-8"?>` and
/// indents by four spaces, while Linux's (libxml2) writes `encoding="utf-8" standalone="no"` and
/// indents by two. A file saved unchanged on the other platform would differ on every line, so
/// both writers — `ContainerFile` and the sidecar's — walk the tree themselves through this.
///
/// The form is Darwin's: the declaration without a `standalone` declaration, one element per line
/// indented by four spaces, an element with no content in its compact form, an element holding only
/// text on one line with the text as it is, and a newline at the end. Whitespace-only text between
/// elements is the old indentation and is dropped; an element with other text beside its elements
/// is mixed content, and is written as it stands, with no indentation added inside it.
///
/// Text escapes `&`, `<` and `>`, and a carriage return, which the reader would otherwise fold.
/// Attribute values escape those and `"`, and a tab or line break, which the reader would otherwise
/// read as a space. A character XML 1.0 cannot carry is dropped, since no escape can write it.
package enum XMLWriter {
    package static func data(for document: XMLDocument) -> Data {
        var output = #"<?xml version="1.0" encoding="UTF-8"?>"# + "\n"
        for node in document.children ?? [] where !isWhitespace(node) {
            write(node, depth: 0, to: &output)
            output += "\n"
        }
        return Data(output.utf8)
    }

    private static let indent = "    "

    private static func write(_ node: XMLNode, depth: Int, to output: inout String) {
        switch node.kind {
        case .element:
            guard let element = node as? XMLElement else { return }
            write(element, depth: depth, to: &output)
        case .text:
            output += escaped(node.stringValue ?? "", inAttribute: false)
        case .comment:
            output += "<!--\(node.stringValue ?? "")-->"
        case .processingInstruction:
            let value = node.stringValue ?? ""
            output += "<?\(node.name ?? "")\(value.isEmpty ? "" : " " + value)?>"
        default:
            output += node.xmlString
        }
    }

    private static func write(_ element: XMLElement, depth: Int, to output: inout String) {
        let name = element.name ?? ""
        output += "<\(name)"
        for (name, value) in attributes(of: element) {
            output += " \(name)=\"\(escaped(value, inAttribute: true))\""
        }

        let children = element.children ?? []
        let content = children.filter { !isWhitespace($0) }
        let textOnly = !children.isEmpty && children.allSatisfy { $0.kind == .text }
        if textOnly && children.contains(where: { !($0.stringValue ?? "").isEmpty }) {
            output += ">"
            for child in children { write(child, depth: depth, to: &output) }
            output += "</\(name)>"
        } else if content.isEmpty {
            output += "/>"
        } else if content.contains(where: { $0.kind == .text }) {
            // Mixed content: its whitespace is part of it, so none is added or taken away.
            output += ">"
            for child in children { writeInline(child, to: &output) }
            output += "</\(name)>"
        } else {
            output += ">"
            let inner = String(repeating: indent, count: depth + 1)
            for child in content {
                output += "\n" + inner
                write(child, depth: depth + 1, to: &output)
            }
            output += "\n" + String(repeating: indent, count: depth) + "</\(name)>"
        }
    }

    /// A node inside mixed content: written with nothing added, and nothing dropped either.
    private static func writeInline(_ node: XMLNode, to output: inout String) {
        guard node.kind == .element, let element = node as? XMLElement else {
            write(node, depth: 0, to: &output)
            return
        }
        let name = element.name ?? ""
        output += "<\(name)"
        for (name, value) in attributes(of: element) {
            output += " \(name)=\"\(escaped(value, inAttribute: true))\""
        }
        let children = element.children ?? []
        guard !children.isEmpty else {
            output += "/>"
            return
        }
        output += ">"
        for child in children { writeInline(child, to: &output) }
        output += "</\(name)>"
    }

    /// The element's namespace declarations, then its attributes, in document order. A parser may
    /// report a declaration as an attribute as well, so a name is written once.
    private static func attributes(of element: XMLElement) -> [(String, String)] {
        var result: [(String, String)] = []
        var seen: Set<String> = []
        for namespace in element.namespaces ?? [] {
            let prefix = namespace.name ?? ""
            let name = prefix.isEmpty ? "xmlns" : "xmlns:\(prefix)"
            if seen.insert(name).inserted { result.append((name, namespace.stringValue ?? "")) }
        }
        for attribute in element.attributes ?? [] {
            let name = attribute.name ?? ""
            if seen.insert(name).inserted { result.append((name, attribute.stringValue ?? "")) }
        }
        return result
    }

    private static func isWhitespace(_ node: XMLNode) -> Bool {
        node.kind == .text && (node.stringValue ?? "").allSatisfy { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r\n" || $0 == "\r" }
    }

    private static func escaped(_ string: String, inAttribute: Bool) -> String {
        var result = ""
        result.unicodeScalars.reserveCapacity(string.unicodeScalars.count)
        for scalar in string.unicodeScalars where XMLText.carries(scalar) {
            switch scalar {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\r": result += "&#13;"
            case "\"" where inAttribute: result += "&quot;"
            case "\t" where inAttribute: result += "&#9;"
            case "\n" where inAttribute: result += "&#10;"
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result
    }
}
