/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation

@main
struct BenchmarkCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
            abstract: "A utility for performing benchmarks for Swift-DocC.",
            subcommands: [Measure.self, Diff.self, CompareTo.self, MeasureCommits.self, RenderTrend.self],
            defaultSubcommand: Measure.self)
}

let doccProjectRootURL: URL = {
    let url = URL(fileURLWithPath: #file)
        .deletingLastPathComponent() // Commands.swift
        .deletingLastPathComponent() // benchmark
        .deletingLastPathComponent() // Sources
        .deletingLastPathComponent() // benchmark
        .deletingLastPathComponent() // bin
    guard FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) else {
        fatalError("The path to the Swift-DocC source root has changed. This should only happen if the benchmark sources have moved relative to the Swift-DocC repo.")
    }
    return url
}()
