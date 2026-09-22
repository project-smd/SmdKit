// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation
import SmdKit

/// A container as a library keeps it: the same container the repository holds, plus the facts
/// that are the library's own — which file holds each presentation of each item, and where each
/// child container's sidecar is. `StructuredContainers.md` calls the file an `.smd`; the
/// repository file is that element with these facts taken out, and this is them put back.
public struct Sidecar: Hashable, Sendable {
    public var container: Container
    /// Each child container's sidecar, as a path relative to the folder holding this one:
    /// the `smd` attribute of `<item type="container">`.
    public var children: [ContainerID: String]
    /// The presentations of each item, by the item's id, in the order they are listed.
    public var presentations: [String: [Presentation]]

    public init(container: Container, children: [ContainerID: String] = [:], presentations: [String: [Presentation]] = [:]) {
        self.container = container
        self.children = children
        self.presentations = presentations
    }

    /// The name a presentation is shown under: its alternative's title, or its profile, or
    /// nothing for the unqualified presentation of the default alternative.
    public func displayName(of presentation: Presentation) -> String? {
        if let alternative = presentation.alternative {
            return container.alternatives.first { $0.id == alternative }?.title ?? alternative
        }
        return presentation.profile
    }

    /// Every file a sidecar names, relative to its folder.
    public var files: [String] {
        presentations.values.flatMap { $0.map(\.file) }
    }
}

/// One file for an item: a version, a cut or a profile of it, with the library facts the sidecar
/// keeps about that file and nothing else.
public struct Presentation: Hashable, Sendable, Codable {
    /// The alternative this presentation belongs to; nil for the default.
    public var alternative: String?
    /// `mobile`, `hdr`, `sdr`, `remux`, or whatever a library calls a re-encode; nil for the
    /// presentation to use unless a client asks for something specific.
    public var profile: String?
    /// Relative to the folder holding the sidecar, and never outside the container's folder.
    public var file: String
    /// The disc title this was ripped from, by natural key: the disc's content hash and the
    /// playlist. The one attribute in the format that names something outside the library.
    public var source: SourceRef?
    /// Each of the container's features this file carries, at *this file's* stream indices.
    public var tracks: [TrackMapping]
    public var chapters: [Chapter]

    public init(alternative: String? = nil, profile: String? = nil, file: String, source: SourceRef? = nil, tracks: [TrackMapping] = [], chapters: [Chapter] = []) {
        self.alternative = alternative
        self.profile = profile
        self.file = file
        self.source = source
        self.tracks = tracks
        self.chapters = chapters
    }
}

public struct SourceRef: Hashable, Sendable, Codable {
    public var disc: String
    public var playlist: String

    public init(disc: String, playlist: String) {
        self.disc = disc
        self.playlist = playlist
    }
}

/// A feature mapped to a file's streams, counted from one among streams of each kind — the way a
/// player's menu counts. Absent means the file has no stream of that kind for the feature.
public struct TrackMapping: Hashable, Sendable, Codable {
    public var feature: String
    public var audio: Int?
    public var subtitle: Int?

    public init(feature: String, audio: Int? = nil, subtitle: Int? = nil) {
        self.feature = feature
        self.audio = audio
        self.subtitle = subtitle
    }
}

/// A chapter's name, which is authored knowledge the tool writes into the file at rip time and
/// records here so the verification pass can compare the two.
public struct Chapter: Hashable, Sendable, Codable {
    /// From one.
    public var index: Int
    public var title: String

    public init(index: Int, title: String) {
        self.index = index
        self.title = title
    }
}
