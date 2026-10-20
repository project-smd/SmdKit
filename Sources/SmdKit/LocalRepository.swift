// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation

/// The database as a folder: a clone of the data repository, with the containers under `containers/`
/// laid out as the tree of their homes. Each container has a folder holding its document as
/// `container.xml` and the folders of the containers it holds as children; the folder is named for the
/// container's position among its home's children, its title and its id, as `Hosting.md`'s *The
/// layout follows the tree of homes* says. Nothing else is assumed about the folder — it need not be
/// a git checkout, and committing what was written is the user's act, not this type's.
///
/// The id is the identity and the name is for people: a container is found by the id in brackets at
/// the end of its folder's name, never by its path. Every save puts every container where the layout
/// says, so the tree follows the data whatever order the containers are saved in.
///
/// Every read goes to disk. The files are small and few, principle 1 of the database proposal
/// says they stay that way, and a cache would have to be told about edits made outside the tool,
/// which in a git clone is the normal case.
public struct LocalRepository: ContainerDatabase {
    public let root: URL

    public static let containersFolder = "containers"
    public static let containerFileName = "container.xml"

    public init(root: URL) {
        self.root = root
    }

    public var containersURL: URL {
        root.appendingPathComponent(Self.containersFolder, isDirectory: true)
    }

    /// Where a container's document is, wherever its folder sits, or nil for an id no folder — nor a
    /// flat file left by the earlier layout — is named for.
    public func url(of id: ContainerID) throws -> URL? {
        try located()[id]?.file
    }

    public func containers() async throws -> [Container] {
        try located().sorted { $0.key.value < $1.key.value }.map { try read($0.value.file, expecting: $0.key) }
    }

    public func container(_ id: ContainerID) async throws -> Container? {
        guard let location = try located()[id] else { return nil }
        return try read(location.file, expecting: id)
    }

    public func containers(matching ref: ExternalRef) async throws -> [Container] {
        try await containers().filter { $0.externalRefs.contains(ref) }
    }

    /// Writes the container and puts every container where the layout says. Refused, before anything
    /// is written or moved, when it would give a container a second home or make it its own ancestor.
    public func save(_ container: Container) async throws {
        var all = Dictionary(try await containers().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        try Self.checkHomes(of: container, among: all)
        all[container.id] = container
        let folder = try settle(all)[container.id]!
        try ContainerFile.data(for: container).write(
            to: folder.appendingPathComponent(Self.containerFileName),
            options: .atomic
        )
    }

    /// Puts every container where the layout says without saving anything: a clone in the flat layout
    /// is converted by this, and one already in place is left as it is.
    public func settle() async throws {
        _ = try settle(Dictionary(try await containers().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }))
    }

    /// Mints, and mints again while a folder is named for the id. 64 random bits make a second try a
    /// formality; the check is what makes the answer true of the clone rather than merely likely.
    public func provisionalID() async throws -> ContainerID {
        let taken = try located()
        var id: ContainerID
        repeat {
            id = ContainerID.mint()
        } while taken[id] != nil
        return id
    }

    /// Writes each container as `save(_:)` does, in the order given, and commits nothing. The
    /// contribution is judged whole, so one that moves a container from one home to another is
    /// accepted whichever of the two comes first, and the layout is settled once, with every
    /// container of the contribution in place. A file-system error part way leaves the files already
    /// written, each whole: in a clone that is a working-tree change the user can see and discard.
    public func contribute(_ containers: [Container]) async throws -> Contribution {
        try await checkContribution(containers)
        var all = Dictionary(try await self.containers().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for container in containers { all[container.id] = container }
        let folders = try settle(all)
        var written: [URL] = []
        for container in containers {
            let file = folders[container.id]!.appendingPathComponent(Self.containerFileName)
            try ContainerFile.data(for: container).write(to: file, options: .atomic)
            written.append(file)
        }
        return .written(written)
    }

    // MARK: The layout

    /// A container's folder name: its position among its home's distinct children, padded to two
    /// digits or as many as `count` needs, and ` - `, when it is held as a child; its title as a
    /// library writes a folder name; and its id in square brackets. A title of which nothing survives
    /// leaves the title part, and the space after it, out.
    public static func folderName(for container: Container, position: Int? = nil, of count: Int = 0) -> String {
        var name = ""
        if let position {
            let digits = String(position)
            let width = max(2, String(count).count)
            name = String(repeating: "0", count: max(0, width - digits.count)) + digits + " - "
        }
        let title = Self.sanitise(container.displayTitle)
        if !title.isEmpty { name += title + " " }
        return name + "[\(container.id.value)]"
    }

    /// A title as a folder name: the two characters a filesystem refuses replaced, NUL removed,
    /// whitespace collapsed, leading dots removed, and the ends trimmed.
    static func sanitise(_ title: String) -> String {
        var text =
            title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\0", with: "")
        text = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        while text.hasPrefix(".") { text.removeFirst() }
        return text.trimmingCharacters(in: .whitespaces)
    }

    /// The id a folder is named for: sixteen hex characters in square brackets at the end of its name.
    static func id(ofFolder name: String) -> ContainerID? {
        guard name.hasSuffix("]"), let open = name.lastIndex(of: "[") else { return nil }
        return ContainerID(String(name[name.index(after: open)..<name.index(before: name.endIndex)]))
    }

    /// Refuses a value that would give one of its children a second home, or hold one of its own
    /// ancestors.
    static func checkHomes(of container: Container, among all: [ContainerID: Container]) throws {
        for child in Set(container.childContainerIDs) {
            let others = all.values.filter { $0.id != container.id && $0.childContainerIDs.contains(child) }
            if let other = others.min(by: { $0.id.value < $1.id.value }) {
                throw LocalRepositoryError.twoHomes(child: child, homes: [other.id, container.id])
            }
        }
        var homes = Self.homes(in: all)
        for child in Set(container.childContainerIDs) { homes[child] = container.id }
        var cursor = container.id
        var seen: Set<ContainerID> = []
        while let home = homes[cursor] {
            guard home != container.id else { throw LocalRepositoryError.cycle(container.id) }
            guard seen.insert(home).inserted else { return }
            cursor = home
        }
    }

    /// Each container's home among those given: the first, by id, that names it as a child.
    private static func homes(in all: [ContainerID: Container]) -> [ContainerID: ContainerID] {
        var homes: [ContainerID: ContainerID] = [:]
        for container in all.values.sorted(by: { $0.id.value < $1.id.value }) {
            for child in container.childContainerIDs where homes[child] == nil && all[child] != nil {
                homes[child] = container.id
            }
        }
        return homes
    }

    /// Moves every container to the folder the layout gives it, homes before their children, and
    /// answers each container's folder. A container with no folder yet is given one.
    private func settle(_ all: [ContainerID: Container]) throws -> [ContainerID: URL] {
        let homes = Self.homes(in: all)
        var wanted: [ContainerID: URL] = [:]
        var queue = all.keys.filter { homes[$0] == nil }.sorted { $0.value < $1.value }
        while !queue.isEmpty {
            let id = queue.removeFirst()
            let container = all[id]!
            let base: URL
            let name: String
            if let home = homes[id], let parent = all[home], let folder = wanted[home] {
                var children: [ContainerID] = []
                for child in parent.childContainerIDs where !children.contains(child) { children.append(child) }
                base = folder
                name = Self.folderName(for: container, position: children.firstIndex(of: id)! + 1, of: children.count)
            } else {
                base = containersURL
                name = Self.folderName(for: container)
            }
            let destination = base.appendingPathComponent(name, isDirectory: true)
            try place(id, at: destination)
            wanted[id] = destination
            var held: [ContainerID] = []
            for child in container.childContainerIDs where homes[child] == id && !held.contains(child) {
                held.append(child)
            }
            queue += held
        }
        // A container no walk from the top reaches is in a ring of homes someone made by hand; it is
        // put at the top, where the validator will find it.
        for id in all.keys.sorted(by: { $0.value < $1.value }) where wanted[id] == nil {
            let destination = containersURL.appendingPathComponent(Self.folderName(for: all[id]!), isDirectory: true)
            try place(id, at: destination)
            wanted[id] = destination
        }
        return wanted
    }

    /// Puts one container's folder at `destination`: moved there with all it holds, made from a flat
    /// file the earlier layout left, or made empty for a container that has none yet.
    private func place(_ id: ContainerID, at destination: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        switch try located(writing: true)[id] {
        case .folder(let folder)? where folder.standardizedFileURL.path == destination.standardizedFileURL.path:
            return
        case .folder(let folder)?:
            // A rename that only changes case is a move onto itself on a case-insensitive volume, so it
            // goes by way of a name of its own: still named for the id, so that a move cut short is
            // found by the next walk and finished by the next save.
            let aside = folder.deletingLastPathComponent().appendingPathComponent(".moving [\(id.value)]")
            try manager.moveItem(at: folder, to: aside)
            try manager.moveItem(at: aside, to: destination)
        case .flat(let file)?:
            try manager.createDirectory(at: destination, withIntermediateDirectories: true)
            try manager.moveItem(at: file, to: destination.appendingPathComponent(Self.containerFileName))
        case nil:
            try manager.createDirectory(at: destination, withIntermediateDirectories: true)
        }
    }

    // MARK: Reading

    /// Where a container is: a folder of the layout, or a flat `<id>.xml` the earlier layout left at
    /// the top of `containers/`.
    private enum Location {
        case folder(URL)
        case flat(URL)

        var file: URL {
            switch self {
            case .folder(let folder): folder.appendingPathComponent(LocalRepository.containerFileName)
            case .flat(let file): file
            }
        }
    }

    /// Every container's location, found by walking the tree. A folder named for no id, a container's
    /// folder with no document, a flat xml file named for no id, and one id twice are refused rather
    /// than skipped. A settle in progress makes folders before it writes their documents, and walks
    /// with `writing` set, which takes a container's folder without its document as the container's.
    /// Every URL is built from `containersURL`, so that it is spelled as the caller spelled the root.
    private func located(writing: Bool = false) throws -> [ContainerID: Location] {
        var found: [ContainerID: Location] = [:]
        func record(_ id: ContainerID, _ location: Location, at url: URL) throws {
            guard found[id] == nil else { throw LocalRepositoryError.unexpectedFile(url) }
            found[id] = location
        }
        func walk(_ folder: URL, top: Bool) throws {
            let names: [String]
            do {
                names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            } catch CocoaError.fileReadNoSuchFile where top {
                return
            }
            for name in names.sorted() {
                var isDirectory: ObjCBool = false
                let path = folder.appendingPathComponent(name).path
                guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { continue }
                if isDirectory.boolValue {
                    let entry = folder.appendingPathComponent(name, isDirectory: true)
                    guard let id = Self.id(ofFolder: name),
                        writing
                            || FileManager.default.fileExists(
                                atPath: entry.appendingPathComponent(Self.containerFileName).path
                            )
                    else { throw LocalRepositoryError.unexpectedFile(entry) }
                    try record(id, .folder(entry), at: entry)
                    try walk(entry, top: false)
                } else if top, name.hasSuffix(".\(ContainerFile.fileExtension)") {
                    let entry = folder.appendingPathComponent(name)
                    guard let id = ContainerID(entry.deletingPathExtension().lastPathComponent) else {
                        throw LocalRepositoryError.unexpectedFile(entry)
                    }
                    try record(id, .flat(entry), at: entry)
                }
            }
        }
        try walk(containersURL, top: true)
        return found
    }

    /// A document is read expecting the id its folder or file is named for, so one naming another
    /// container is refused rather than read under a name it did not claim.
    private func read(_ url: URL, expecting expected: ContainerID) throws -> Container {
        do {
            return try ContainerFile.container(from: try Data(contentsOf: url), expecting: expected)
        } catch let error as ContainerFileError {
            throw LocalRepositoryError.unreadable(url, error)
        }
    }
}

public enum LocalRepositoryError: Error, Equatable, LocalizedError {
    case unexpectedFile(URL)
    case unreadable(URL, ContainerFileError)
    /// A save that would give `child` a second home: the container that holds it, and the one saved.
    case twoHomes(child: ContainerID, homes: [ContainerID])
    /// A save that would make the container its own ancestor.
    case cycle(ContainerID)

    public var errorDescription: String? {
        switch self {
        case .unexpectedFile(let url):
            "\(url.lastPathComponent) is in the containers folder but is not a container's folder or file, or names one twice"
        case .unreadable(let url, let error): "\(url.lastPathComponent): \(error.localizedDescription)"
        case .twoHomes(let child, let homes):
            "\(child) would be held by \(homes.map(\.value).joined(separator: " and ")); a container has one home"
        case .cycle(let id): "\(id) would hold one of its own ancestors"
        }
    }
}
