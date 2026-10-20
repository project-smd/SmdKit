// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation

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

    public struct Missing: Hashable, Sendable {
        public var container: ContainerID
        public var names: ContainerID

        public init(container: ContainerID, names: ContainerID) {
            self.container = container
            self.names = names
        }
    }

    public var errorDescription: String? {
        switch self {
        case .duplicate(let ids):
            "The contribution carries more than one container for \(ids.map(\.value).joined(separator: ", "))"
        case .missing(let missing):
            missing.map { "\($0.container) names \($0.names), which neither the database nor the contribution holds" }
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
    }
}
