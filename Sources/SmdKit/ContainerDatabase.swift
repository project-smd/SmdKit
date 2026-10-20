// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

/// What a client of the database asks of it, shaped by the questions in `ContainerDatabase.md`
/// rather than by any store's own layout. Phase 1 has one implementation, a folder that is a
/// clone of the data repository; a service in front of the same data is a second one, and the
/// tool should not be able to tell.
///
/// Discs, releases and bindings are not here yet: they arrive with the identify and bind steps of
/// the ingestion flow, which is when their shape will be known from use rather than from the
/// proposal.
public protocol ContainerDatabase: Sendable {
    /// Every container. Small enough to list whole while principle 1 of the database proposal
    /// holds, which is the constraint that keeps the repository clonable at all.
    func containers() async throws -> [Container]

    func container(_ id: ContainerID) async throws -> Container?

    /// The identify step: a provider's id, resolved to what it names here.
    func containers(matching ref: ExternalRef) async throws -> [Container]

    /// Creates the container, or replaces the one with its id.
    func save(_ container: Container) async throws

    /// An id for a container nobody has yet, provisional until smddb accepts a container carrying
    /// it. Nothing about the id records that: it is a `ContainerID` like any other, and a caller
    /// keeps no list of which are provisional.
    func provisionalID() async throws -> ContainerID

    /// Offers containers to smddb, refused whole before anything is written when
    /// `checkContribution(_:)` refuses them. Unlike `save(_:)`, which is a clone's own writer,
    /// this is the call a service answers too.
    func contribute(_ containers: [Container]) async throws -> Contribution
}

extension ContainerDatabase {
    /// The containers nothing holds: series, films, collections. Where the browsing starts.
    public func roots() async throws -> [Container] {
        let all = try await containers()
        let held = Set(all.flatMap(\.childContainerIDs))
        return all.filter { !held.contains($0.id) }
    }
}
