/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// Returns the symbol graph files found by recursively searching the given directories.
///
/// Files are deduplicated and returned in the order that their directories were provided in.
/// Directories that don't exist are ignored.
///
/// - Parameter directories: The directories to search for symbol graph files.
/// - Returns: The symbol graph files in the given directories.
func symbolGraphFiles(in directories: [URL]) -> [URL] {
    directories
        // avoid traversing the same exact folders multiple times
        .uniqueElements(by: \.standardizedFileURL)
        .flatMap { directory in
            let subpaths = FileManager.default.subpaths(atPath: directory.path) ?? []
            return subpaths.map { directory.appendingPathComponent($0) }
                .filter { DocumentationBundleFileTypes.isSymbolGraphFile($0) }
        }
        // if overlapping paths were provided (e.g. 'foo/' and 'foo/folder') omit duplicates
        .uniqueElements(by: \.standardizedFileURL)
}
