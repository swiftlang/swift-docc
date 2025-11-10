/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation

extension Docc {
    /// Processes an action on an archive
    struct ProcessArchive: AsyncParsableCommand {

        static var configuration = CommandConfiguration(
            commandName: "process-archive",
            abstract: "Perform operations on documentation archives ('.doccarchive' directories).",
            subcommands: [TransformForStaticHosting.self, Index.self])

    }
}
