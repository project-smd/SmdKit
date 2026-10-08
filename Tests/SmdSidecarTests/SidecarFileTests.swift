// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation
import SmdKit
import Testing
@testable import SmdSidecar

struct SidecarFileTests {
    static let seasonID = ContainerID("0123456789abcdef")!
    /// The binding part one's broadcast presentation was made from.
    static let partOne = "5b0e7c1a-3d2f-4e8a-9c41-7f0d2e6a91d2"

    /// A serial with two cuts, a commentary, three parts and an extra, as a library holds it.
    static let pyramids: Sidecar = {
        var container = Container(id: ContainerID("fedcba9876543210")!, type: .serial, typeLabel: "Story", title: Title("Pyramids of Mars")!)
        container.alternatives = [
            Alternative(id: "broadcast", sequence: "parts", title: "Broadcast version"),
            Alternative(id: "se", sequence: "parts", title: "Updated special effects"),
        ]
        container.defaultAlternative = "broadcast"
        container.features = [Feature(id: "commentary1", type: .commentary, title: "Commentary", participants: [Participant(name: "Tom Baker", role: "The Doctor")])]
        container.sequences = [Sequence(id: "parts", items: [
            .leaf(Entry.Leaf(id: ItemID("part1")!, type: .episode, title: "Part One")),
            .leaf(Entry.Leaf(id: ItemID("part2")!, type: .episode, title: "Part Two")),
            .child(Entry.Child(id: ItemID("next")!, container: seasonID)),
        ])]
        container.extras = [.leaf(Entry.Leaf(id: ItemID("now-and-then")!, type: .featurette, title: "Now and Then"))]
        return Sidecar(
            container: container,
            children: [seasonID: "Next/container.smd"],
            presentations: [
                "part1": [
                    Presentation(file: "Part One - Broadcast version.mkv",
                                 source: PresentationSource(binding: partOne, segments: [.init(key: NaturalKey(scheme: "discTitle", value: "3F1AC2E9/00004.mpls"))]),
                                 transform: Transform(ruleset: "household", version: 7, layers: [Transform.Layer(.container(ContainerID("fedcba9876543210")!), version: 4, digest: "sha256:41d0")]),
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
        #expect(text.contains("<source binding=\"\(Self.partOne)\">\n                    <segment scheme=\"discTitle\" value=\"3F1AC2E9/00004.mpls\"/>\n                </source>"))
        #expect(text.contains("<transform ruleset=\"household\" version=\"7\">\n                    <layer container=\"fedcba9876543210\" version=\"4\" digest=\"sha256:41d0\"/>"))
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
        #expect(read.container.title == Title("Pyramids of Mars (as I titled it)"))
    }

    @Test func anUpdateRemovesFactsTheValueNoLongerHas() throws {
        let onDisk = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container format="1" id="fedcba9876543210" type="serial">
            <title>Pyramids of Mars</title>
            <sequence id="parts">
                <item type="episode" id="part1"><presentation file="Part One.mkv"/></item>
                <item type="episode" id="part2"><presentation file="Part Two.mkv"/></item>
                <item type="container" id="next" container="0123456789abcdef" smd="Next/container.smd"/>
                <item type="episode" id="part5"><presentation file="Part Five.mkv"/></item>
            </sequence>
        </container>

        """
        var sidecar = Self.pyramids
        sidecar.children = [:]
        sidecar.presentations = ["part1": [Presentation(file: "Part One.mkv")]]
        let read = try SidecarFile.sidecar(from: SidecarFile.data(for: sidecar, updating: Data(onDisk.utf8)))
        #expect(read.presentations["part2"] == nil, "a presentation the value dropped is removed")
        #expect(read.children.isEmpty, "and so is a child path")
        #expect(read.presentations["part1"] == [Presentation(file: "Part One.mkv")])
        #expect(read.presentations["part5"] == [Presentation(file: "Part Five.mkv")], "an item only the document has keeps its facts")
    }

    @Test func aSidecarIsWrittenAsTheRepositoryFileWouldBe() throws {
        let bare = Sidecar(container: Self.pyramids.container)
        let repository = ContainerFile.data(for: bare.container)
        #expect(try SidecarFile.data(for: bare) == repository)

        // The same document as Linux's Foundation serialiser would write it: a declaration that
        // says standalone, and two-space indentation. An update writes the repository's bytes.
        let text = String(decoding: repository, as: UTF8.self)
        let foreign = text
            .replacingOccurrences(of: #"<?xml version="1.0" encoding="UTF-8"?>"#, with: #"<?xml version="1.0" encoding="utf-8" standalone="no"?>"#)
            .replacingOccurrences(of: "    ", with: "  ")
        #expect(foreign != text)
        let updated = try SidecarFile.data(for: bare, updating: Data(foreign.utf8))
        #expect(updated == repository)
        #expect(!String(decoding: updated, as: UTF8.self).contains("standalone"))

        let standalone = text.replacingOccurrences(of: #"encoding="UTF-8"?>"#, with: #"encoding="UTF-8" standalone="yes"?>"#)
        #expect(try SidecarFile.data(for: bare, updating: Data(standalone.utf8)) == repository)
    }

    @Test func anUpdateKeepsMixedContentAsItStands() throws {
        let onDisk = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container format="1" id="fedcba9876543210" type="serial">
            <title>Pyramids of Mars</title>
            <outline>A <em>very</em> old god</outline>
        </container>

        """
        let updated = try SidecarFile.data(for: Sidecar(container: Self.pyramids.container), updating: Data(onDisk.utf8))
        #expect(String(decoding: updated, as: UTF8.self).contains("<outline>A <em>very</em> old god</outline>"))
    }

    @Test func aPresentationKeepsWhitespaceInItsAttributes() throws {
        var sidecar = Self.pyramids
        sidecar.presentations = ["part1": [Presentation(file: "Part\tOne\nof two\r.mkv", chapters: [Chapter(index: 1, title: "A\tB")])]]
        let data = try SidecarFile.data(for: sidecar)
        #expect(try SidecarFile.sidecar(from: data).presentations == sidecar.presentations)
    }

    @Test func anUpdateRefusesADifferentContainer() throws {
        let other = try SidecarFile.data(for: Sidecar(container: Container(id: ContainerID.mint(), type: .movie, title: Title("Other")!)))
        #expect(throws: ContainerFileError.self) { try SidecarFile.data(for: Self.pyramids, updating: other) }
    }

    @Test func anEmptyPresentationListIsNotRecorded() throws {
        var sidecar = Self.pyramids
        sidecar.presentations["part2"] = []
        let read = try SidecarFile.sidecar(from: SidecarFile.data(for: sidecar))
        #expect(read.presentations["part2"] == nil)
        #expect(read.presentations.keys.sorted() == ["now-and-then", "part1"])
        #expect(read != sidecar, "so the value read is not the value written")
    }

    @Test func aPresentationNeedsAnItemToHoldIt() {
        var sidecar = Self.pyramids
        sidecar.presentations["part9"] = [Presentation(file: "x.mkv")]
        #expect(throws: SidecarFileError.unknownItem("part9")) { try SidecarFile.data(for: sidecar) }
    }

    @Test func anEmptySidecarIsMalformed() {
        // Every way into a sidecar reads the container first, so every one refuses zero bytes
        // as the repository reader does, rather than crashing on Linux.
        let malformed = ContainerFileError.malformed("the document is empty")
        #expect(throws: malformed) { try SidecarFile.sidecar(from: Data()) }
        #expect(throws: malformed) { try SidecarFile.data(for: Self.pyramids, updating: Data()) }
        #expect(throws: malformed) { try SidecarFile.data(settingRules: nil, in: Data()) }
    }

    @Test func displayNamesComeFromTheContainer() {
        let sidecar = Self.pyramids
        let presentations = sidecar.presentations["part1"]!
        #expect(sidecar.displayName(of: presentations[0]) == nil)
        #expect(sidecar.displayName(of: presentations[1]) == "mobile")
        #expect(sidecar.displayName(of: presentations[2]) == "Updated special effects")
        #expect(Set(sidecar.files) == ["Part One - Broadcast version.mkv", "Part One - Mobile.mkv", "Part One - Updated special effects.mkv", "extras/Now and Then.mkv"])
    }

    // MARK: - Rules

    /// The restoration's rules at their fourth version, in the folder beside the sidecar.
    static let restoration = SidecarRules(path: "rules", activeVersion: 4)

    @Test func aRulesReferenceNamesItsFile() {
        #expect(Self.restoration.activeFile == "rules/4.xml")
        #expect(Self.restoration.file(version: 2) == "rules/2.xml", "a version the file a presentation names was made by, while another is in force")
        #expect(SidecarRules(path: "Rules for the restoration", activeVersion: 12).activeFile == "Rules for the restoration/12.xml")
        #expect(SidecarRules(activeVersion: 1).path == "rules", "the folder's name in practice")
    }

    @Test func aSidecarWithRulesSurvivesTheFile() throws {
        var sidecar = Self.pyramids
        sidecar.rules = Self.restoration
        let data = try SidecarFile.data(for: sidecar)
        let text = String(decoding: data, as: UTF8.self)
        let extras = try #require(text.range(of: "</extras>"))
        let rules = try #require(text.range(of: "    <rules path=\"rules\" activeVersion=\"4\"/>"))
        #expect(extras.upperBound <= rules.lowerBound, "the rules are named last, after the extras")
        #expect(text.hasSuffix("    <rules path=\"rules\" activeVersion=\"4\"/>\n</container>\n"))
        #expect(try SidecarFile.sidecar(from: data) == sidecar)
        #expect(try ContainerFile.container(from: data) == sidecar.container, "the repository reader ignores the rules")
        #expect(!String(decoding: ContainerFile.data(for: sidecar.container), as: UTF8.self).contains("<rules"), "and the repository file carries none")
    }

    /// A serial's sidecar whose `<container>` holds `rules` as its last child.
    static func document(rules: String) -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <container format="1" id="fedcba9876543210" type="serial">
            <title>Pyramids of Mars</title>
            \(rules)
        </container>

        """.utf8)
    }

    @Test func aRulesReferenceThatNamesNothingIsRefused() {
        #expect(throws: ContainerFileError.missingAttribute(element: "rules", attribute: "path")) {
            try SidecarFile.sidecar(from: Self.document(rules: #"<rules activeVersion="4"/>"#))
        }
        #expect(throws: ContainerFileError.missingAttribute(element: "rules", attribute: "activeVersion")) {
            try SidecarFile.sidecar(from: Self.document(rules: #"<rules path="rules"/>"#))
        }
        #expect(throws: ContainerFileError.invalidValue(element: "rules", attribute: "path", value: "")) {
            try SidecarFile.sidecar(from: Self.document(rules: #"<rules path="" activeVersion="4"/>"#))
        }
        #expect(throws: ContainerFileError.invalidValue(element: "rules", attribute: "activeVersion", value: "0")) {
            try SidecarFile.sidecar(from: Self.document(rules: #"<rules path="rules" activeVersion="0"/>"#))
        }
        #expect(throws: ContainerFileError.invalidValue(element: "rules", attribute: "activeVersion", value: "four")) {
            try SidecarFile.sidecar(from: Self.document(rules: #"<rules path="rules" activeVersion="four"/>"#))
        }
    }

    @Test func rulesWrittenInlineAreRefused() throws {
        // The form an earlier proposal had: the rules themselves inside the element.
        #expect(throws: SidecarFileError.inlineRules) {
            try SidecarFile.sidecar(from: Self.document(rules: #"<rules><video><copy/></video></rules>"#))
        }
        #expect(throws: SidecarFileError.inlineRules, "even when it names a version too") {
            try SidecarFile.sidecar(from: Self.document(rules: #"<rules path="rules" activeVersion="1"><video><copy/></video></rules>"#))
        }
        // A comment inside holds no rules, so it is no reason to refuse.
        #expect(try SidecarFile.sidecar(from: Self.document(rules: #"<rules path="rules" activeVersion="2"><!-- after the restoration --></rules>"#)).rules == SidecarRules(path: "rules", activeVersion: 2))
    }

    @Test func rulesInsideAnItemAreNotTheContainers() throws {
        let onDisk = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container format="1" id="fedcba9876543210" type="serial">
            <title>Pyramids of Mars</title>
            <sequence id="parts">
                <item type="episode" id="part1"><rules binding="\(Self.partOne)" path="rules/bindings/\(Self.partOne)" activeVersion="1"/></item>
            </sequence>
        </container>

        """
        let sidecar = try SidecarFile.sidecar(from: Data(onDisk.utf8))
        #expect(sidecar.rules == nil)
        #expect(sidecar.bindingRules["part1"] == [BindingRules(binding: Self.partOne, rules: SidecarRules(path: "rules/bindings/\(Self.partOne)", activeVersion: 1))], "they are the binding's")
    }

    @Test func twoRulesElementsAreRefused() {
        #expect(throws: SidecarFileError.multipleRules) {
            try SidecarFile.sidecar(from: Self.document(rules: #"<rules path="rules" activeVersion="1"/><rules path="rules" activeVersion="2"/>"#))
        }
    }

    @Test func anUpdateLeavesTheRulesAsTheyStand() throws {
        let onDisk = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container format="1" id="fedcba9876543210" type="serial">
            <title>Pyramids of Mars</title>
            <sequence id="parts">
                <item type="episode" id="part1"/>
                <item type="episode" id="part2"/>
            </sequence>
            <!-- Version 2 keeps the restoration's extras whole. -->
            <rules path="rules" activeVersion="2"/>
        </container>

        """
        // A placement: a new presentation, and a value that says nothing of rules.
        var placement = Sidecar(container: try ContainerFile.container(from: Data(onDisk.utf8)))
        placement.presentations["part2"] = [Presentation(file: "Part Two.mkv")]
        let data = try SidecarFile.data(for: placement, updating: Data(onDisk.utf8))
        let updated = try SidecarFile.sidecar(from: data)
        #expect(updated.rules == SidecarRules(path: "rules", activeVersion: 2), "the reference is kept")
        #expect(String(decoding: data, as: UTF8.self).contains("<!-- Version 2 keeps the restoration's extras whole. -->\n    <rules path=\"rules\" activeVersion=\"2\"/>"), "and the comment before it")
        #expect(updated.presentations["part2"] == [Presentation(file: "Part Two.mkv")])

        // Nor does an update add rules the document does not have.
        var withRules = Self.pyramids
        withRules.rules = Self.restoration
        let bare = try SidecarFile.data(for: Self.pyramids)
        #expect(try SidecarFile.sidecar(from: SidecarFile.data(for: withRules, updating: bare)).rules == nil)
    }

    @Test func settingTheRulesChangesOnlyTheRules() throws {
        let onDisk = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container format="1" id="fedcba9876543210" type="serial">
            <!-- Kept by hand. -->
            <title>Pyramids of Mars</title>
            <rules path="rules" activeVersion="2"/>
            <sequence id="parts">
                <item type="episode" id="part1"><presentation file="Part One.mkv"/></item>
            </sequence>
        </container>

        """
        let before = try SidecarFile.sidecar(from: Data(onDisk.utf8))
        let three = SidecarRules(path: "rules", activeVersion: 3)

        let replaced = try SidecarFile.data(settingRules: three, in: Data(onDisk.utf8))
        let replacedText = String(decoding: replaced, as: UTF8.self)
        #expect(try SidecarFile.sidecar(from: replaced).rules == three)
        #expect(try SidecarFile.sidecar(from: replaced).presentations == before.presentations)
        #expect(replacedText.contains("<!-- Kept by hand. -->"))
        #expect(try #require(replacedText.range(of: "<rules")).lowerBound < #require(replacedText.range(of: "<sequence")).lowerBound, "replaced where it stood")

        let removed = try SidecarFile.data(settingRules: nil, in: Data(onDisk.utf8))
        var expected = before
        expected.rules = nil
        #expect(try SidecarFile.sidecar(from: removed) == expected)

        let added = try SidecarFile.data(settingRules: three, in: removed)
        #expect(String(decoding: added, as: UTF8.self).hasSuffix("    <rules path=\"rules\" activeVersion=\"3\"/>\n</container>\n"), "added last when there was none")
        #expect(try SidecarFile.sidecar(from: added).rules == three)
    }

    // MARK: - Provenance

    static let discTwo = "9d3f0b6e-1c2a-4f7d-8e5b-a2b4c6d8e0f1"
    static let playAll = "c41a2e8b-6d0f-4a3c-b7e9-07fe1d3c5a79"

    /// A sidecar whose items' presentations carry `presentation`'s source and transform.
    static func sidecar(_ presentations: [String: [Presentation]], bindingRules: [String: [BindingRules]] = [:]) -> Sidecar {
        Sidecar(container: pyramids.container, presentations: presentations, bindingRules: bindingRules)
    }

    @Test func aPresentationNamesItsBindingAndItsSegments() throws {
        // A film across two discs, both keyed; and an episode cut from a title nothing can identify.
        let film = PresentationSource(binding: Self.discTwo, segments: [
            .init(key: NaturalKey(scheme: "discTitle", value: "77B01E4C/00800.mpls")),
            .init(key: NaturalKey(scheme: "discTitle", value: "A9C25D10/00800.mpls")),
        ])
        let episode = PresentationSource(binding: Self.playAll, segments: [.init(chapters: ChapterSpan(from: 2, to: 2))])
        let sidecar = Self.sidecar([
            "part1": [Presentation(file: "Part One.mkv", source: film)],
            "part2": [Presentation(file: "Part Two.mkv", source: episode)],
        ])
        let data = try SidecarFile.data(for: sidecar)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(#"<segment scheme="discTitle" value="77B01E4C/00800.mpls"/>"# + "\n                    " + #"<segment scheme="discTitle" value="A9C25D10/00800.mpls"/>"#), "in order")
        #expect(text.contains(#"<source binding="\#(Self.playAll)">"# + "\n                    " + #"<segment from="2" to="2"/>"#), "no key, and a span")
        #expect(try SidecarFile.sidecar(from: data) == sidecar)
    }

    /// A sidecar document whose item `part1` has one presentation holding `inside`.
    static func presentation(holding inside: String) -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <container format="1" id="fedcba9876543210" type="serial">
            <title>Pyramids of Mars</title>
            <sequence id="parts">
                <item type="episode" id="part1"><presentation file="Part One.mkv">\(inside)</presentation></item>
            </sequence>
        </container>

        """.utf8)
    }

    @Test func aMalformedSourceIsRefused() {
        let binding = Self.partOne
        let refusals: [(String, ContainerFileError)] = [
            (#"<source binding="not-a-uuid"><segment/></source>"#, .invalidValue(element: "source", attribute: "binding", value: "not-a-uuid")),
            (#"<source><segment/></source>"#, .missingAttribute(element: "source", attribute: "binding")),
            (#"<source binding="\#(binding)"/>"#, .missingElement(element: "source", child: "segment")),
            (#"<source binding="\#(binding)"><segment scheme="discTitle"/></source>"#, .missingAttribute(element: "segment", attribute: "value")),
            (#"<source binding="\#(binding)"><segment to="2"/></source>"#, .missingAttribute(element: "segment", attribute: "from")),
            (#"<source binding="\#(binding)"><segment from="0" to="2"/></source>"#, .invalidValue(element: "segment", attribute: "from", value: "0")),
            (#"<source binding="\#(binding)"><segment from="3" to="2"/></source>"#, .invalidValue(element: "segment", attribute: "to", value: "2")),
            (#"<source binding="\#(binding)"><segment/></source><source binding="\#(binding)"><segment/></source>"#, .invalidValue(element: "presentation", attribute: "source", value: "2 elements")),
        ]
        for (inside, refusal) in refusals {
            #expect(throws: refusal, "\(inside)") { try SidecarFile.sidecar(from: Self.presentation(holding: inside)) }
        }
    }

    @Test func aPresentationNamesTheRulesThatMadeIt() throws {
        let transform = Transform(ruleset: "household", version: 7, layers: [
            Transform.Layer(.binding(Self.partOne), version: 2, digest: "sha256:77ab"),
            Transform.Layer(.container(Self.seasonID), version: 4),
        ])
        let sidecar = Self.sidecar(["part1": [Presentation(file: "Part One.mkv", transform: transform)]])
        let data = try SidecarFile.data(for: sidecar)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(#"<transform ruleset="household" version="7">"# + "\n                    " + #"<layer binding="\#(Self.partOne)" version="2" digest="sha256:77ab"/>"# + "\n                    " + #"<layer container="0123456789abcdef" version="4"/>"#), "nearest first")
        #expect(try SidecarFile.sidecar(from: data) == sidecar)
        // And through JSON, as a layer is spelt: one subject beside its version.
        let json = try JSONEncoder().encode(transform)
        #expect(try JSONDecoder().decode(Transform.self, from: json) == transform)
        #expect(String(decoding: try JSONEncoder().encode(transform.layers[1]), as: UTF8.self).contains(#""container":"0123456789abcdef""#))
    }

    @Test func aMalformedTransformIsRefused() {
        let binding = Self.partOne
        let refusals: [(String, ContainerFileError)] = [
            (#"<transform version="7"/>"#, .missingAttribute(element: "transform", attribute: "ruleset")),
            (#"<transform ruleset="" version="7"/>"#, .invalidValue(element: "transform", attribute: "ruleset", value: "")),
            (#"<transform ruleset="household" version="0"/>"#, .invalidValue(element: "transform", attribute: "version", value: "0")),
            (#"<transform ruleset="household" version="7"><layer version="1"/></transform>"#, .missingAttribute(element: "layer", attribute: "binding")),
            (#"<transform ruleset="household" version="7"><layer binding="\#(binding)" container="0123456789abcdef" version="1"/></transform>"#, .invalidValue(element: "layer", attribute: "container", value: "0123456789abcdef")),
            (#"<transform ruleset="household" version="7"><layer container="season-14" version="1"/></transform>"#, .invalidValue(element: "layer", attribute: "container", value: "season-14")),
            (#"<transform ruleset="household" version="7"><layer binding="\#(binding)"/></transform>"#, .missingAttribute(element: "layer", attribute: "version")),
            (#"<transform ruleset="household" version="7"/><transform ruleset="household" version="8"/>"#, .invalidValue(element: "presentation", attribute: "transform", value: "2 elements")),
        ]
        for (inside, refusal) in refusals {
            #expect(throws: refusal, "\(inside)") { try SidecarFile.sidecar(from: Self.presentation(holding: inside)) }
        }
    }

    // MARK: - A binding's rules

    static let partOneRules = BindingRules(binding: partOne, rules: SidecarRules(path: "rules/bindings/\(partOne)", activeVersion: 2))

    @Test func aBindingsRulesSurviveTheFile() throws {
        var sidecar = Self.pyramids
        sidecar.bindingRules = ["part1": [Self.partOneRules]]
        let data = try SidecarFile.data(for: sidecar)
        let text = String(decoding: data, as: UTF8.self)
        let rules = try #require(text.range(of: #"<rules binding="\#(Self.partOne)" path="rules/bindings/\#(Self.partOne)" activeVersion="2"/>"#))
        let presentation = try #require(text.range(of: "<presentation file=\"Part One - Broadcast version.mkv\">"))
        #expect(rules.upperBound <= presentation.lowerBound, "before the item's presentations")
        #expect(try SidecarFile.sidecar(from: data) == sidecar)
        #expect(!String(decoding: ContainerFile.data(for: sidecar.container), as: UTF8.self).contains("<rules"), "and the repository file carries none")

        var nowhere = Self.pyramids
        nowhere.bindingRules = ["part9": [Self.partOneRules]]
        #expect(throws: SidecarFileError.unknownItem("part9")) { try SidecarFile.data(for: nowhere) }
    }

    @Test func aBindingsRulesAreRefusedWhenTheyCannotSayWhichApply() throws {
        let path = "rules/bindings/\(Self.partOne)"
        func item(_ rules: String) -> Data {
            Data("""
            <?xml version="1.0" encoding="UTF-8"?>
            <container format="1" id="fedcba9876543210" type="serial">
                <title>Pyramids of Mars</title>
                <sequence id="parts">
                    <item type="episode" id="part1">\(rules)</item>
                </sequence>
            </container>

            """.utf8)
        }
        #expect(throws: SidecarFileError.multipleRules, "two for one binding") {
            try SidecarFile.sidecar(from: item(#"<rules binding="\#(Self.partOne)" path="\#(path)" activeVersion="1"/><rules binding="\#(Self.partOne)" path="\#(path)" activeVersion="2"/>"#))
        }
        #expect(throws: SidecarFileError.inlineRules) {
            try SidecarFile.sidecar(from: item(#"<rules binding="\#(Self.partOne)" path="\#(path)" activeVersion="1"><audio><copy/></audio></rules>"#))
        }
        #expect(throws: ContainerFileError.missingAttribute(element: "rules", attribute: "binding"), "an item's rules are a binding's") {
            try SidecarFile.sidecar(from: item(#"<rules path="rules" activeVersion="1"/>"#))
        }
        // Two bindings of one item, each with its own.
        #expect(try SidecarFile.sidecar(from: item(#"<rules binding="\#(Self.partOne)" path="\#(path)" activeVersion="1"/><rules binding="\#(Self.discTwo)" path="rules/bindings/\#(Self.discTwo)" activeVersion="3"/>"#)).bindingRules["part1"]?.map(\.binding) == [Self.partOne, Self.discTwo])
    }

    @Test func anUpdateLeavesABindingsRulesAsTheyStand() throws {
        var withRules = Self.pyramids
        withRules.bindingRules = ["part1": [Self.partOneRules]]
        let onDisk = try SidecarFile.data(for: withRules)

        // A placement: part one's presentation replaced, and a value that says nothing of rules.
        var placement = Self.pyramids
        placement.presentations["part1"] = [Presentation(file: "Part One - remade.mkv")]
        let data = try SidecarFile.data(for: placement, updating: onDisk)
        let updated = try SidecarFile.sidecar(from: data)
        #expect(updated.bindingRules["part1"] == [Self.partOneRules], "the binding's rules are kept")
        #expect(updated.presentations["part1"] == [Presentation(file: "Part One - remade.mkv")], "and the presentation replaced")

        // Nor does an update add a binding's rules the document does not have.
        let bare = try SidecarFile.data(for: Self.pyramids)
        #expect(try SidecarFile.sidecar(from: SidecarFile.data(for: withRules, updating: bare)).bindingRules.isEmpty)
    }

    @Test func settingABindingsRulesChangesOnlyThoseRules() throws {
        let onDisk = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <container format="1" id="fedcba9876543210" type="serial">
            <title>Pyramids of Mars</title>
            <sequence id="parts">
                <item type="episode" id="part1">
                    <!-- Kept by hand. -->
                    <rules binding="\(Self.partOne)" path="rules/bindings/\(Self.partOne)" activeVersion="2"/>
                    <presentation file="Part One.mkv"/>
                </item>
            </sequence>
        </container>

        """.utf8)
        let before = try SidecarFile.sidecar(from: onDisk)
        let three = SidecarRules(path: "rules/bindings/\(Self.partOne)", activeVersion: 3)

        let replaced = try SidecarFile.data(settingRules: three, binding: Self.partOne, item: "part1", in: onDisk)
        let replacedText = String(decoding: replaced, as: UTF8.self)
        #expect(try SidecarFile.sidecar(from: replaced).bindingRules["part1"] == [BindingRules(binding: Self.partOne, rules: three)])
        #expect(try SidecarFile.sidecar(from: replaced).presentations == before.presentations)
        #expect(replacedText.contains("<!-- Kept by hand. -->"))

        let removed = try SidecarFile.data(settingRules: nil, binding: Self.partOne, item: "part1", in: onDisk)
        var expected = before
        expected.bindingRules = [:]
        #expect(try SidecarFile.sidecar(from: removed) == expected)

        let added = try SidecarFile.data(settingRules: three, binding: Self.discTwo, item: "part1", in: removed)
        let addedText = String(decoding: added, as: UTF8.self)
        #expect(try #require(addedText.range(of: "<rules binding")).lowerBound < #require(addedText.range(of: "<presentation")).lowerBound, "added before the presentations")
        #expect(try SidecarFile.sidecar(from: added).bindingRules["part1"] == [BindingRules(binding: Self.discTwo, rules: three)])

        #expect(throws: SidecarFileError.unknownItem("part9")) { try SidecarFile.data(settingRules: three, binding: Self.partOne, item: "part9", in: onDisk) }
        #expect(throws: ContainerFileError.invalidValue(element: "rules", attribute: "binding", value: "not-a-uuid")) {
            try SidecarFile.data(settingRules: three, binding: "not-a-uuid", item: "part1", in: onDisk)
        }
    }
}

