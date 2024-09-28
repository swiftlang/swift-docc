/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser

private var subcommands: [ParsableCommand.Type] {
    var subcommands: [ParsableCommand.Type] = [
        Docc.Convert.self,
        Docc.ProcessArchive.self,
        Docc.ProcessCatalog.self,
        Docc._Index.self,
        Docc.Init.self,
        Docc.Merge.self,
        Docc.GenerateChangelog.self,
    ]
#if canImport(NIOHTTP1)
    subcommands.insert(Docc.Preview.self, at: 1)
#endif
    return subcommands
}

private var usage: String {
    var usage = "docc convert [<catalog-path>] [--additional-symbol-graph-dir <symbol-graph-dir>] [<other-options>]"
#if canImport(NIOHTTP1)
    usage.append("\ndocc preview [<catalog-path>] [--port <port-number>] [--additional-symbol-graph-dir <symbol-graph-dir>] [--output-dir <output-dir>] [<other-options>]")
#endif
    return usage
}

/// The default, command-line interface you use to compile and preview documentation.
public struct Docc: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Documentation Compiler: compile, analyze, and preview documentation.",
        usage: usage,
        subcommands: subcommands)

    public init() {}
}
