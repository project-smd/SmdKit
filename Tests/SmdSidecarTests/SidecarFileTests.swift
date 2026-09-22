// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation
import SmdKit
import Testing
@testable import SmdSidecar

struct SidecarFileTests {
    static let seasonID = ContainerID("0123456789abcdef")!

    /// A serial with two cuts, a commentary, three parts and an extra, as a library holds it.
    static let pyramids: Sidecar = {
        var container = Container(id: ContainerID("fedcba9876543210")!, type: .serial, typeLabel: "Story", title: "Pyramids of Mars")
        container.alternatives = [
            Alternative(id: "broadcast", sequence: "parts", title: "Broadcast version"),
            Alternative(id: "se", sequence: "parts", title: "Updated special effects"),
        ]
        container.defaultAlternative = "broadcast"
        container.features = [Feature(id: "commentary1", type: .commentary, title: "Commentary", participants: [Participant(name: "Tom Baker", role: "The Doctor")])]
        container.sequences = [Sequence(id: "parts", items: [
            Entry(id: "part1", type: .episode, title: "Part One"),
            Entry(id: "part2", type: .episode, title: "Part Two"),
            Entry(id: "next", type: .container, container: seasonID),
        ])]
        container.extras = [Entry(id: "now-and-then", type: .featurette, title: "Now and Then")]
        return Sidecar(
            container: container,
            children: [seasonID: "Next/container.smd"],
            presentations: [
                "part1": [
                    Presentation(file: "Part One - Broadcast version.mkv", source: SourceRef(disc: "3F1AC2E9", playlist: "00004.mpls"),
                                 tracks: [TrackMapping(feature: "commentary1", audio: 3)],
                                 chapters: [Chapter(index: 1, title: "Opening titles"), Chapter(index: 2, title: "Sutekh")]),
                    Presentation(profile: "mobile", file: "Part One - Mobile.mkv", tracks: [TrackMapping(feature: "commentary1", audio: 2)]),
                    Presentation(alternative: "se", file: "Part One - Updated special effects.mkv"),
                ],
                "now-and-then": [Presentation(file: "extras/Now and Then.mkv")],
            ]
        )
    }()

    @Test func aSidecarSurvivesTheFile() throws {
        let data = try SidecarFile.data(for: Self.pyramids)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("<presentation file=\"Part One - Broadcast version.mkv\">"))
        #expect(text.contains("<source disc=\"3F1AC2E9\" playlist=\"00004.mpls\"/>"))
        #expect(text.contains("<track feature=\"commentary1\" audio=\"3\"/>"))
        #expect(text.contains("<chapter index=\"2\" title=\"Sutekh\"/>"))
        #expect(text.contains("<presentation profile=\"mobile\" file=\"Part One - Mobile.mkv\">"))
        #expect(text.contains("<presentation alternative=\"se\" file=\"Part One - Updated special effects.mkv\"/>"))
        #expect(text.contains("<item type=\"container\" id=\"next\" container=\"0123456789abcdef\" smd=\"Next/container.smd\"/>"))
        #expect(try SidecarFile.sidecar(from: data) == Self.pyramids)
    }

    @Test func theRepositoryReaderReadsASidecarAsItsContainer() throws {
        // The one-model claim, mechanically: the sidecar is the repository file plus a library's
        // facts, so the repository reader reads it and sees the container, unchanged.
        let data = try SidecarFile.data(for: Self.pyramids)
        #expect(try ContainerFile.container(from: data) == Self.pyramids.container)
    }

    @Test func anUpdateChangesOnlyTheLibrarysFacts() throws {
        let handWritten = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container format="1" id="fedcba9876543210" type="serial">
            <!-- Kept by hand; the tool must leave this alone. -->
            <title>Pyramids of Mars (as I titled it)</title>
            <typeLabel>Story</typeLabel>
            <alternatives default="broadcast">
                <alternative id="broadcast" sequence="parts"><title>Broadcast version</title></alternative>
            </alternatives>
            <sequence id="parts">
                <item type="episode" id="part1">
                    <presentation file="Old name.mkv"/>
                </item>
            </sequence>
        </container>

        """
        var sidecar = Self.pyramids
        sidecar.presentations = ["part1": [Presentation(file: "Part One - Broadcast version.mkv")], "part2": [Presentation(file: "Part Two - Broadcast version.mkv")], "now-and-then": [Presentation(file: "extras/Now and Then.mkv")]]
        let updated = try SidecarFile.data(for: sidecar, updating: Data(handWritten.utf8))
        let text = String(decoding: updated, as: UTF8.self)
        #expect(text.contains("<!-- Kept by hand; the tool must leave this alone. -->"))
        #expect(text.contains("<title>Pyramids of Mars (as I titled it)</title>"), "an update does not rewrite the container's own fields")
        #expect(!text.contains("Old name.mkv"))
        #expect(!text.contains("<alternative id=\"se\""), "an update does not add alternatives either")
        #expect(text.contains("<item type=\"episode\" id=\"part2\">"), "an item the document lacked is added to its sequence")
        #expect(text.contains("<item type=\"container\" id=\"next\" container=\"0123456789abcdef\" smd=\"Next/container.smd\"/>"))
        #expect(text.contains("<extras>"), "and extras are created for an extra the document lacked")

        let read = try SidecarFile.sidecar(from: updated)
        #expect(read.presentations == sidecar.presentations)
        #expect(read.children == sidecar.children)
        #expect(read.container.title == "Pyramids of Mars (as I titled it)")
    }

    @Test func anUpdateRefusesADifferentContainer() throws {
        let other = try SidecarFile.data(for: Sidecar(container: Container(id: ContainerID.mint(), type: .movie, title: "Other")))
        #expect(throws: ContainerFileError.self) { try SidecarFile.data(for: Self.pyramids, updating: other) }
    }

    @Test func aPresentationNeedsAnItemToHoldIt() {
        var sidecar = Self.pyramids
        sidecar.presentations["part9"] = [Presentation(file: "x.mkv")]
        #expect(throws: SidecarFileError.unknownItem("part9")) { try SidecarFile.data(for: sidecar) }
    }

    @Test func displayNamesComeFromTheContainer() {
        let sidecar = Self.pyramids
        let presentations = sidecar.presentations["part1"]!
        #expect(sidecar.displayName(of: presentations[0]) == nil)
        #expect(sidecar.displayName(of: presentations[1]) == "mobile")
        #expect(sidecar.displayName(of: presentations[2]) == "Updated special effects")
        #expect(Set(sidecar.files) == ["Part One - Broadcast version.mkv", "Part One - Mobile.mkv", "Part One - Updated special effects.mkv", "extras/Now and Then.mkv"])
    }
}
