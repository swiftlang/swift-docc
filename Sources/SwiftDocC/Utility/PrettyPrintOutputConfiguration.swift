/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An environmental variable to control the output formatting of the encoded render JSON.
///
/// If this environment variable is set to "YES", DocC will format render node JSON with spacing and indentation,
/// and sort the keys (on supported platforms), to make it deterministic and easy to read.
let jsonFormattingKey = "DOCC_JSON_PRETTYPRINT"
public internal(set) var shouldPrettyPrintOutputJSON = NSString(string: ProcessInfo.processInfo.environment[jsonFormattingKey] ?? "NO").boolValue
