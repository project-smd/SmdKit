// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import PackageDescription

// The parts of smddb that are not an app: the container model, the file each container is kept as
// in the data repository, and the database behind them. A package of its own rather than a target
// in the macOS tool's, because the tool links VLCKit and MakeMKVKit, and a CI job that only wants
// to read container files must not have to resolve either; a repository of its own because the
// tool and the silo server depend on it from two repositories, and SwiftPM names a dependency by
// URL, not by a folder inside one. Nothing here imports anything Apple-only.
let package = Package(
    name: "SmdKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SmdKit", targets: ["SmdKit"]),
        .library(name: "SmdSidecar", targets: ["SmdSidecar"]),
    ],
    targets: [
        .target(name: "SmdKit"),
        // The .smd as a library keeps it: the container plus which file holds each presentation.
        // A target of its own so that a reader of the repository — which has no files in it —
        // never sees a presentation type.
        .target(name: "SmdSidecar", dependencies: ["SmdKit"]),
        .testTarget(name: "SmdKitTests", dependencies: ["SmdKit"]),
        .testTarget(name: "SmdSidecarTests", dependencies: ["SmdSidecar", "SmdKit"]),
    ]
)
