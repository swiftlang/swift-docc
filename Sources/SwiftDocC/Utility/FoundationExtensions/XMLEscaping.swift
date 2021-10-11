/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension String {
    /// A copy of the string, with the five special characters in XML (< > & " ' ) replaced with their respective escape sequences.
    var xmlEscaped: String {
        var result = String()
        result.reserveCapacity(self.count)
        for character in self {
            switch character {
            case "<":
                result.append("&lt;")
            case ">":
                result.append("&gt;")
            case "&":
                result.append("&amp;")
            case "'":
                result.append("&apos;")
            case "\"":
                result.append("&quot;")
            default:
                result.append(character)
            }
        }
        return result
    }
}
