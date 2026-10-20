// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

// URL and LocalizedError are FoundationEssentials' where Foundation is split into modules.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What the database answers about containers offered to it.
///
/// Only the cases an implementation answers are declared. A service's states — pending, changes
/// requested, merged, rejected, as `Hosting.md` names them — arrive with the service, as new cases a
/// caller switching on a contribution has to decide on, rather than as a default it never thought
/// about.
public enum Contribution: Hashable, Sendable {
    /// Written into a clone, each file whole, in the order the containers were given. What follows —
    /// a commit, a pull request — is the user's.
    case written([URL])
}

/// Why a contribution was refused. Either is decided before anything is written.
public enum ContributionError: Error, Equatable, LocalizedError {
    /// Ids carried by more than one container in the contribution, in the order first seen.
    case duplicate([ContainerID])
    /// Every container that names, as a child or as the container of a ref, one that neither the
    /// database nor the contribution holds, in the contribution's order.
    case missing([Missing])
    /// Every container the contribution would leave held by more than one container, judged with the
    /// contribution's containers in place of the database's, with its homes.
    case twoHomes([Homes])

    public struct Missing: Hashable, Sendable {
        public var container: ContainerID
        public var names: ContainerID

        public init(container: ContainerID, names: ContainerID) {
            self.container = container
            self.names = names
        }
    }

    public struct Homes: Hashable, Sendable {
        public var child: ContainerID
        public var homes: [ContainerID]

        public init(child: ContainerID, homes: [ContainerID]) {
            self.child = child
            self.homes = homes
        }
    }

    public var errorDescription: String? {
        switch self {
        case .duplicate(let ids):
            "The contribution carries more than one container for \(ids.map(\.value).joined(separator: ", "))"
        case .missing(let missing):
            missing.map { "\($0.container) names \($0.names), which neither the database nor the contribution holds" }
                .joined(separator: "\n")
        case .twoHomes(let twice):
            twice.map {
                "\($0.child) would be held by \($0.homes.map(\.value).joined(separator: " and ")); a container has one home"
            }
            .joined(separator: "\n")
        }
    }
}

extension Container {
    /// The containers this one names: its children, and the containers its refs point into, each once,
    /// in the order its sequences and extras list them. A ref that names no container points within
    /// this one, and is not among them.
    public var namedContainerIDs: [ContainerID] {
        var seen: Set<ContainerID> = []
        return (sequences.flatMap(\.items) + extras).compactMap { entry -> ContainerID? in
            switch entry {
            case .child(let child): child.container
            case .ref(let ref): ref.container
            case .leaf: nil
            }
        }
        .filter { $0 != id && seen.insert($0).inserted }
    }
}

extension ContainerDatabase {
    /// The referential check smddb's hosting proposal runs at submit: no container twice, and every
    /// container named by one in the contribution held by the database or the contribution. Throws
    /// with every failure, not the first.
    public func checkContribution(_ containers: [Container]) async throws {
        var seen: Set<ContainerID> = []
        var duplicates: [ContainerID] = []
        for container in containers where !seen.insert(container.id).inserted && !duplicates.contains(container.id) {
            duplicates.append(container.id)
        }
        guard duplicates.isEmpty else { throw ContributionError.duplicate(duplicates) }

        var missing: [ContributionError.Missing] = []
        for container in containers {
            for named in container.namedContainerIDs where !seen.contains(named) {
                if try await self.container(named) == nil {
                    missing.append(ContributionError.Missing(container: container.id, names: named))
                }
            }
        }
        guard missing.isEmpty else { throw ContributionError.missing(missing) }

        // One home each, `StructuredContainers.md`'s principle 5, with the contribution in place of
        // what the database holds under the same ids.
        var merged: [ContainerID: Container] = [:]
        for container in try await self.containers() + containers { merged[container.id] = container }
        var homes: [ContainerID: [ContainerID]] = [:]
        for container in merged.values.sorted(by: { $0.id.value < $1.id.value }) {
            for child in Set(container.childContainerIDs) { homes[child, default: []].append(container.id) }
        }
        let twice = homes.filter { $0.value.count > 1 }.sorted { $0.key.value < $1.key.value }
            .map { ContributionError.Homes(child: $0.key, homes: $0.value) }
        guard twice.isEmpty else { throw ContributionError.twoHomes(twice) }
    }
}
