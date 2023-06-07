/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser

#if canImport(NIOHTTP1)
private let subcommands: [ParsableCommand.Type] = [Docc.Convert.self, Docc.Index.self, Docc.Preview.self, Docc.ProcessArchive.self]
#else
private let subcommands: [ParsableCommand.Type] = [Docc.Convert.self, Docc.Index.self, Docc.ProcessArchive.self]
#endif

/// The default, command-line interface you use to compile and preview documentation.
public struct Docc: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Documentation Compiler: compile, analyze, and preview documentation.",
        subcommands: subcommands)

    public init() {}
}
