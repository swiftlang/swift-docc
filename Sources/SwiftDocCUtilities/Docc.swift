/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser


#if canImport(NIOHTTP1)
private let subcommands: [ParsableCommand.Type] = [Docc.Convert.self, Docc.Preview.self, Docc.ProcessArchive.self, Docc._Index.self, Docc.Init.self]
private let usage: String = """
docc convert [<catalog-path>] [--additional-symbol-graph-dir <symbol-graph-dir>] [<other-options>]
docc preview [<catalog-path>] [--port <port-number>] [--additional-symbol-graph-dir <symbol-graph-dir>] [--output-dir <output-dir>] [<other-options>]
"""
#else
private let subcommands: [ParsableCommand.Type] = [Docc.Convert.self, Docc.ProcessArchive.self, Docc._Index.self, Docc.Init.self]
private let usage: String = """
docc convert [<catalog-path>] [--additional-symbol-graph-dir <symbol-graph-dir>] [<other-options>]
"""
#endif

/// The default, command-line interface you use to compile and preview documentation.
public struct Docc: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Documentation Compiler: compile, analyze, and preview documentation.",
        usage: usage,
        subcommands: subcommands)

    public init() {}
}
