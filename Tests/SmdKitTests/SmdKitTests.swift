// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation
import Testing
@testable import SmdKit

/// An item id the test knows to be valid.
func item(_ string: String) -> ItemID { ItemID(rawValue: string)! }

/// A title the test knows to be valid.
func title(_ string: String) -> Title { Title(string)! }

/// The container file and the folder behind it, checked against the worked example in the
/// proposals: Talons as a serial with three cuts, a commentary, a ref and an extra.
struct SmdKitTests {
    static let talons = Container(
        id: ContainerID("6a1f0c2e9b7d4e3a")!,
        type: .serial,
        typeLabel: "Story",
        title: title("The Talons of Weng-Chiang"),
        outline: "Fog-bound Victorian London, a stage magician, and a war criminal from the fifty-first century.",
        externalRefs: [ExternalRef(provider: .wikidata, value: "Q3475469")],
        defaultAlternative: "broadcast",
        alternatives: [
            Alternative(id: "broadcast", sequence: "parts", title: "Broadcast version"),
            Alternative(id: "se", sequence: "parts", title: "Updated special effects", outline: "2010 DVD release."),
            Alternative(id: "omnibus", sequence: "omnibus", title: "Omnibus edition"),
        ],
        features: [
            Feature(id: "commentary1", type: .commentary, title: "Commentary — Louise Jameson, John Bennett, Christopher Barry", participants: [
                Participant(name: "Louise Jameson", role: "Leela"),
                Participant(name: "Christopher Barry", role: "Director"),
            ]),
            Feature(id: "music1", type: .isolatedMusic),
        ],
        sequences: [
            Sequence(id: "parts", items: [
                .leaf(Entry.Leaf(id: item("prequel"), type: .episode, optional: true)),
                .leaf(Entry.Leaf(id: item("part1"), type: .episode, externalRefs: [ExternalRef(provider: .tvdb, value: "1234"), ExternalRef(provider: .tmdb, value: "5678")])),
                .leaf(Entry.Leaf(id: item("part2"), type: .episode, externalRefs: [ExternalRef(provider: .tvdb, value: "1235")])),
            ]),
            Sequence(id: "omnibus", items: [
                .leaf(Entry.Leaf(id: item("omnibus-feature"), type: .episode, title: "Omnibus edition")),
            ]),
            Sequence(id: "dvd-order", exploded: .allowed, items: [
                .ref(EntryRef(item: item("part2"))),
                .ref(EntryRef(item: item("part1"))),
            ]),
        ],
        extrasAnchor: "part1",
        extras: [
            .leaf(Entry.Leaf(id: item("now-and-then"), type: .featurette, title: "Now and Then")),
            .ref(EntryRef(container: ContainerID("0b9e8d7c6f5a4b3c")!, item: item("s14-talons"))),
        ]
    )

    @Test func containerSurvivesTheFile() throws {
        let data = ContainerFile.data(for: Self.talons)
        let text = String(decoding: data, as: UTF8.self)
        // Spelled as the sidecar spells it, with the database's differences and nothing else.
        #expect(text.contains(#"<container format="1" id="6a1f0c2e9b7d4e3a" type="serial">"#))
        #expect(text.contains(#"<externalRef provider="wikidata" value="Q3475469"/>"#))
        #expect(text.contains(#"<alternatives default="broadcast">"#))
        #expect(text.contains(#"<item ref="0b9e8d7c6f5a4b3c#s14-talons""#))
        #expect(text.contains(#"<sequence id="dvd-order" exploded="allowed">"#))
        #expect(!text.contains("presentation"))
        #expect(!text.contains("listed"), "the default is not written")
        #expect(try ContainerFile.container(from: data, expecting: Self.talons.id) == Self.talons)
    }

    @Test func childrenAreNamedByIdentity() throws {
        let child = Container(type: .season, title: title("Season 14"), year: 1976)
        var series = Container(type: .series, title: title("Doctor Who"), year: 1963, yearInTitle: true, listed: false)
        series.sequences = [Sequence(items: [.child(Entry.Child(id: item("season-14"), container: child.id))])]
        let data = ContainerFile.data(for: series)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(#"listed="false""#))
        #expect(text.contains(#"<year inTitle="true">1963</year>"#))
        #expect(series.displayTitle == "Doctor Who (1963)")
        #expect(child.displayTitle == "Season 14")
        #expect(String(decoding: ContainerFile.data(for: child), as: UTF8.self).contains("<year>1976</year>"))
        #expect(text.contains(#"<item type="container" id="season-14" container="\#(child.id)""#))
        let read = try ContainerFile.container(from: data)
        #expect(read == series)
        #expect(read.childContainerIDs == [child.id])
    }

    @Test func fileRefusesWhatItCannotRead() throws {
        func read(_ xml: String, expecting: ContainerID? = nil) throws -> Container {
            try ContainerFile.container(from: Data(xml.utf8), expecting: expecting)
        }
        let id = ContainerID.mint()
        let other = ContainerID.mint()
        #expect(throws: ContainerFileError.notAContainer) {
            try read(#"<sequence id="x"/>"#)
        }
        #expect(throws: ContainerFileError.unsupportedFormat(2)) {
            try read(#"<container format="2" id="\#(id)" type="series"><title>x</title></container>"#)
        }
        #expect(throws: ContainerFileError.idMismatch(file: other, document: id)) {
            try read(#"<container format="1" id="\#(id)" type="series"><title>x</title></container>"#, expecting: other)
        }
        #expect(throws: ContainerFileError.missingElement(element: "container", child: "title")) {
            try read(#"<container format="1" id="\#(id)" type="series"/>"#)
        }
        #expect(throws: ContainerFileError.invalidValue(element: "container", attribute: "type", value: "box")) {
            try read(#"<container format="1" id="\#(id)" type="box"><title>x</title></container>"#)
        }
        #expect(throws: ContainerFileError.missingAttribute(element: "item", attribute: "container")) {
            try read(#"<container format="1" id="\#(id)" type="series"><title>x</title><sequence><item type="container" id="s1"/></sequence></container>"#)
        }
        #expect(throws: ContainerFileError.refWithIdentity("part1")) {
            try read(#"<container format="1" id="\#(id)" type="series"><title>x</title><sequence><item ref="part1" id="p"/></sequence></container>"#)
        }
        #expect(throws: ContainerFileError.self) {
            try read("<container format=\"1\" id=\"\(id)\" type=\"series\"><title>x</title>")
        }
        #expect(throws: ContainerFileError.invalidText(element: "title", value: "")) {
            try read(#"<container format="1" id="\#(id)" type="series"><title>   </title></container>"#)
        }
        #expect(throws: ContainerFileError.invalidValue(element: "item", attribute: "container", value: "\(other)")) {
            try read(#"<container format="1" id="\#(id)" type="series"><title>x</title><sequence><item type="episode" id="e1" container="\#(other)"/></sequence></container>"#)
        }
        #expect(throws: ContainerFileError.invalidValue(element: "item", attribute: "id", value: "")) {
            try read(#"<container format="1" id="\#(id)" type="series"><title>x</title><sequence><item type="episode" id=""/></sequence></container>"#)
        }
        #expect(throws: ContainerFileError.invalidValue(element: "item", attribute: "id", value: "a#b")) {
            try read(#"<container format="1" id="\#(id)" type="series"><title>x</title><sequence><item type="episode" id="a#b"/></sequence></container>"#)
        }
        #expect(throws: ContainerFileError.invalidValue(element: "item", attribute: "ref", value: "\(other)#")) {
            try read(#"<container format="1" id="\#(id)" type="series"><title>x</title><sequence><item ref="\#(other)#"/></sequence></container>"#)
        }
        #expect(throws: ContainerFileError.invalidValue(element: "item", attribute: "ref", value: "a#b")) {
            try read(#"<container format="1" id="\#(id)" type="series"><title>x</title><sequence><item ref="a#b"/></sequence></container>"#)
        }
    }

    @Test func containerIDsAreCheckedEverywhere() throws {
        #expect(ContainerID("0123456789abcdef")?.rawValue == "0123456789abcdef")
        #expect(ContainerID("0123456789abcdef")?.description == "0123456789abcdef")
        #expect(ContainerID("0123456789ABCDEF") == nil)
        #expect(ContainerID(UUID().uuidString.lowercased()) == nil)
        #expect(ContainerID(rawValue: "not-an-id") == nil)
        let minted = ContainerID.mint()
        #expect(ContainerID(minted.rawValue) == minted)
        #expect(Container(type: .movie, title: title("A")).id != Container(type: .movie, title: title("B")).id)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ContainerID.self, from: Data(#""not-an-id""#.utf8))
        }
        do {
            _ = try JSONDecoder().decode(ContainerID.self, from: Data(#""not-an-id""#.utf8))
        } catch DecodingError.dataCorrupted {
        } catch {
            Issue.record("decoding a malformed id threw \(error), not dataCorrupted")
        }
    }

    @Test func itemIDsNameOneItem() throws {
        #expect(ItemID(rawValue: "part1")?.rawValue == "part1")
        #expect(ItemID(rawValue: "") == nil)
        #expect(ItemID(rawValue: "a#b") == nil)
        #expect(ItemID(rawValue: "a\nb") == nil)
        #expect(ItemID(rawValue: "a\tb") == nil)
        #expect(ItemID(rawValue: "a\rb") == nil)
        #expect(ItemID(rawValue: "a\u{1}b") == nil)
        #expect(try JSONDecoder().decode(ItemID.self, from: Data(#""part1""#.utf8)) == item("part1"))
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ItemID.self, from: Data(#""""#.utf8))
        }
    }

    @Test func titlesAreTrimmedAndNonEmpty() throws {
        #expect(Title(" Doctor Who ")?.rawValue == "Doctor Who")
        #expect(Title("   ") == nil)
        #expect(Title("") == nil)
        #expect(Title("a\u{1}b") == nil)
        #expect(Title(rawValue: " Doctor Who") == nil, "the raw value is the trimmed title, so untrimmed text is not one")
        #expect(try JSONDecoder().decode(Title.self, from: Data(#""Doctor Who""#.utf8)) == title("Doctor Who"))
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Title.self, from: Data(#""  ""#.utf8))
        }
    }

    @Test func entryTypesAreOpenExceptForContainer() throws {
        #expect(EntryType(rawValue: "special")?.rawValue == "special")
        #expect(EntryType(rawValue: "container") == nil)
        #expect(Provider(rawValue: "anidb").title == "anidb")
        #expect(Provider.tmdb.title == "TMDb")
        #expect(String(decoding: try JSONEncoder().encode(EntryType.featurette), as: UTF8.self) == #""featurette""#)
        #expect(try JSONDecoder().decode(EntryType.self, from: Data(#""featurette""#.utf8)) == .featurette)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(EntryType.self, from: Data(#""container""#.utf8))
        }
    }

    @Test func anEntrysKindDeterminesItsFields() {
        let ref = Entry.ref(EntryRef(item: item("part2")))
        #expect(ref.id == nil)
        let other = ContainerID("0123456789abcdef")!
        let child = Entry.child(Entry.Child(id: item("s1"), container: other))
        #expect(child.id == item("s1"))
        var container = Container(type: .series, title: title("Doctor Who"))
        container.sequences = [Sequence(items: [child])]
        container.extras = [.ref(EntryRef(container: other, item: item("s14-talons")))]
        #expect(container.childContainerIDs == [other], "a ref into another container is not a child")
        #expect(container.itemIDs == [item("s1")], "and declares no item id")
    }

    @Test func everyWrittenContainerReadsBack() throws {
        // U+0001 is outside XML 1.0's Char production: no escape can write it, so the writer
        // drops it wherever it appears, and the document stays well-formed.
        let bad = "a\u{1}b"
        var container = Container(type: .serial, typeLabel: bad, title: title("T"), outline: bad, externalRefs: [ExternalRef(provider: .tvdb, value: bad)])
        container.alternatives = [Alternative(id: bad, sequence: bad, title: bad)]
        container.features = [Feature(id: bad, type: .commentary, participants: [Participant(name: bad, role: bad)])]
        container.sequences = [Sequence(id: bad, items: [.leaf(Entry.Leaf(id: item("p1"), type: .episode, title: bad, outline: "\u{1}"))])]
        container.extrasAnchor = bad
        let data = ContainerFile.data(for: container)
        let read = try ContainerFile.container(from: data, expecting: container.id)
        #expect(try ContainerFile.container(from: data) == read)
        #expect(read.outline == "ab")
        #expect(read.typeLabel == "ab")
        #expect(read.externalRefs == [ExternalRef(provider: .tvdb, value: "ab")])
        #expect(read.alternatives == [Alternative(id: "ab", sequence: "ab", title: "ab")])
        #expect(read.features.first?.participants == [Participant(name: "ab", role: "ab")])
        #expect(read.sequences.first?.id == "ab")
        #expect(read.sequences.first?.items == [.leaf(Entry.Leaf(id: item("p1"), type: .episode, title: "ab"))], "an outline of nothing but U+0001 reads as none")
        #expect(read.extrasAnchor == "ab")
    }

    @Test func textIsTrimmedOnRead() throws {
        let container = Container(type: .movie, title: title("T"), outline: " Fog-bound London ")
        let read = try ContainerFile.container(from: ContainerFile.data(for: container))
        #expect(read.outline == "Fog-bound London")
    }

    @Test func repositoryKeepsOneFilePerContainer() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SmdKitTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = LocalRepository(root: folder)
        // An empty folder, or none, is an empty database and not an error.
        #expect(try await repository.containers().isEmpty)
        #expect(try await repository.container(Self.talons.id) == nil)

        let season = Container(type: .season, title: title("Season 14"), externalRefs: [ExternalRef(provider: .tvdb, value: "76107/14")])
        var series = Container(type: .series, title: title("Doctor Who (1963)"), externalRefs: [ExternalRef(provider: .tvdb, value: "76107")])
        series.sequences = [Sequence(items: [.child(Entry.Child(id: item("season-14"), container: season.id))])]
        try await repository.save(series)
        try await repository.save(season)
        try await repository.save(Self.talons)

        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("containers/\(series.id).xml").path))
        #expect(try await repository.containers().count == 3)
        #expect(try await repository.container(Self.talons.id) == Self.talons)
        #expect(try await repository.containers(matching: ExternalRef(provider: .tvdb, value: "76107")) == [series])
        #expect(try await repository.containers(matching: ExternalRef(provider: .tvdb, value: "1")).isEmpty)
        // Roots are what nothing holds: the season is inside the series, Talons is loose.
        #expect(Set(try await repository.roots().map(\.id)) == [series.id, Self.talons.id])

        // Saving again replaces, and a stray file is refused with its name rather than skipped.
        series.title = title("Doctor Who")
        try await repository.save(series)
        #expect(try await repository.container(series.id)?.title == title("Doctor Who"))
        try Data("<container/>".utf8).write(to: folder.appendingPathComponent("containers/notes.xml"))
        await #expect(throws: LocalRepositoryError.self) {
            try await repository.containers()
        }
    }

    @Test func aSaveNeverBreaksTheListing() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SmdKitTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = LocalRepository(root: folder)
        let container = Container(type: .movie, title: title("T"), outline: "a\u{1}b")
        try await repository.save(container)
        #expect(try await repository.containers().map(\.id) == [container.id])
    }

    @Test func slugsAreMadeFromTitles() {
        #expect(Slug.make(from: "The Talons of Weng-Chiang") == "the-talons-of-weng-chiang")
        #expect(Slug.make(from: "  Pyramids of Mars: Part 1 (1975) ") == "pyramids-of-mars-part-1-1975")
        #expect(Slug.make(from: "Café Ünïcode") == "cafe-unicode")
        #expect(Slug.make(from: "???") == "item")
        #expect(Slug.unique(from: "Part 1", avoiding: ["part-1", "part-1-2"]) == "part-1-3")
        #expect(Slug.isValid("season-14"))
        #expect(!Slug.isValid("-season"))
        #expect(!Slug.isValid("Season 14"))
    }
}
