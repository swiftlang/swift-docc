/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension StringProtocol {
    /// A copy of the string prefixed with a slash ("/") if the string doesn't already start with a leading slash.
    var prependingLeadingSlash: String {
        guard !hasPrefix("/") else { return String(self) }
        return "/".appending(self)
    }
    
    /// A copy of the string without a leading slash ("/") or the original string if it doesn't start with a leading slash.
    var removingLeadingSlash: String {
        guard hasPrefix("/") else { return String(self) }
        return String(dropFirst())
    }
    
    var removingTrailingSlash: String {
        guard hasSuffix("/") else { return String(self) }
        return String(dropLast())
    }
}
