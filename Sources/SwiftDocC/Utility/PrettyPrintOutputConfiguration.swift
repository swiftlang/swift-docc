/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

private import Foundation

/// An environmental variable to control the output formatting of the encoded render JSON.
///
/// If this environment variable is set to "YES", DocC will format render node JSON with spacing and indentation.
public let shouldPrettyPrintOutputJSON = readConfiguration(formatSpecificKey: "DOCC_JSON_PRETTYPRINT")

/// An environmental variable to control the output formatting of HTML.
///
/// If this environment variable is set to "YES", DocC will format its HTML output with spacing and indentation.
public let shouldPrettyPrintOutputHTML = readConfiguration(formatSpecificKey: "DOCC_HTML_PRETTYPRINT")

private func readConfiguration(formatSpecificKey: String) -> Bool {
    let environment = ProcessInfo.processInfo.environment
    guard let configuration = environment[formatSpecificKey] ?? environment["DOCC_PRETTYPRINT"] else {
        return false
    }
    return NSString(string: configuration).boolValue
}
