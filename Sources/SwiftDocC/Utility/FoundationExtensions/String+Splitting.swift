/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension String {
    /// A list of the lines in this string, derived by splitting the string on its line breaks.
    ///
    /// If the original string ends with a line break, the last empty line is excluded from the list of lines.
    var splitByNewlines: [String] {
        let lines = components(separatedBy: CharacterSet.newlines)
        return lines.last == "" ? .init(lines.dropLast()) : lines
    }
}
