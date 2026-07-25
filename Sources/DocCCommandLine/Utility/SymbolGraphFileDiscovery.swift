/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

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
