/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation

extension Docc {
    /// Processes an action on a catalog
    struct ProcessCatalog: AsyncParsableCommand {

        static var configuration = CommandConfiguration(
            commandName: "process-catalog",
            abstract: "Perform operations on documentation catalogs ('.docc' directories).",
            subcommands: [EmitGeneratedCuration.self])
    }
}
