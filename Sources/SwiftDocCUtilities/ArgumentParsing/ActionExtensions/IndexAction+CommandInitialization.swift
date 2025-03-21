/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension IndexAction {
    /// Initializes ``IndexAction`` from the options in the ``Index`` command.
    init(fromIndexCommand index: Docc.Index) {
        // Initialize the `IndexAction` from the options provided by the `Index` command
        self.init(
            archiveURL: index.documentationArchive.urlOrFallback,
            outputURL: index.outputURL,
            bundleIdentifier: index.bundleIdentifier)
    }
}
