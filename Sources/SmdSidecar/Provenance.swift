// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation
import SmdKit

/// Where a presentation came from: the binding it was made from, by id, and a copy of the
/// binding's segments, so the file describes itself without the store that holds the binding.
/// `<source binding="…"><segment …/></source>`.
public struct PresentationSource: Hashable, Sendable, Codable {
    /// The binding's id, a UUID, minted wherever the binding was first recorded.
    public var binding: String
    /// The binding's segments, in order; at least one.
    public var segments: [Segment]

    public init(binding: String, segments: [Segment]) {
        self.binding = binding
        self.segments = segments
    }

    /// One segment of a binding: a source, by natural key when it has one, whole or a span of its
    /// chapters.
    public struct Segment: Hashable, Sendable, Codable {
        /// Nil for a source nothing outside its library can identify.
        public var key: NaturalKey?
        /// Nil for the whole source.
        public var chapters: ChapterSpan?

        public init(key: NaturalKey? = nil, chapters: ChapterSpan? = nil) {
            self.key = key
            self.chapters = chapters
        }
    }
}

/// A source's identity as anyone holding it can compute it: a scheme, which says how the value is
/// read, and the value. A disc title's scheme is `discTitle` and its value the disc's content hash
/// and the playlist. This package reads neither.
public struct NaturalKey: Hashable, Sendable, Codable {
    public var scheme: String
    public var value: String

    public init(scheme: String, value: String) {
        self.scheme = scheme
        self.value = value
    }
}

/// Chapters `from` to `to` of a source, inclusive, counted from one.
public struct ChapterSpan: Hashable, Sendable, Codable {
    public var from: Int
    public var to: Int

    public init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }
}

/// How a presentation was made from its binding: the library's ruleset and its version, and every
/// other set of rules that took part, nearest first. `<transform ruleset version><layer …/></transform>`.
/// What the rules say is the encoding server's; this names which made the file.
public struct Transform: Hashable, Sendable, Codable {
    public var ruleset: String
    public var version: Int
    public var layers: [Layer]

    public init(ruleset: String, version: Int, layers: [Layer] = []) {
        self.ruleset = ruleset
        self.version = version
        self.layers = layers
    }

    /// One set of rules that took part: a binding's own or a container's, at the version that made
    /// the file, with the digest of that version's file when its server recorded one.
    public struct Layer: Hashable, Sendable, Codable {
        public enum Subject: Hashable, Sendable {
            case binding(String)
            case container(ContainerID)
        }

        public var subject: Subject
        public var version: Int
        public var digest: String?

        public init(_ subject: Subject, version: Int, digest: String? = nil) {
            self.subject = subject
            self.version = version
            self.digest = digest
        }

        private enum CodingKeys: String, CodingKey {
            case binding, container, version, digest
        }

        // Spelt as the element is: one of `binding` and `container`, beside the version.
        public init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            let binding = try values.decodeIfPresent(String.self, forKey: .binding)
            let container = try values.decodeIfPresent(ContainerID.self, forKey: .container)
            switch (binding, container) {
            case (let binding?, nil): subject = .binding(binding)
            case (nil, let container?): subject = .container(container)
            default:
                throw DecodingError.dataCorruptedError(forKey: .binding, in: values, debugDescription: "a layer names exactly one of a binding and a container")
            }
            version = try values.decode(Int.self, forKey: .version)
            digest = try values.decodeIfPresent(String.self, forKey: .digest)
        }

        public func encode(to encoder: any Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            switch subject {
            case .binding(let binding): try values.encode(binding, forKey: .binding)
            case .container(let container): try values.encode(container, forKey: .container)
            }
            try values.encode(version, forKey: .version)
            try values.encodeIfPresent(digest, forKey: .digest)
        }
    }
}

/// A binding's own rules, named on the item the binding binds: the nearest layer of any file made
/// from it, where a person's decision about that one entry lives.
/// `<rules binding="…" path="…" activeVersion="…"/>` inside an `<item>`.
public struct BindingRules: Hashable, Sendable, Codable {
    /// The binding's id, a UUID.
    public var binding: String
    public var rules: SidecarRules

    public init(binding: String, rules: SidecarRules) {
        self.binding = binding
        self.rules = rules
    }
}
