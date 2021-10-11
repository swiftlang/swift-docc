/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

extension MarkupChildren {
    // The total range of all children in this sequence, provided that their ranges
    // are not `nil`; otherwise, `nil`.
    var range: SourceRange? {
        var totalRange: SourceRange? = nil
        for child in self {
            guard let childRange = child.range else {
                return nil
            }
            if let haveTotalRange = totalRange {
                totalRange = Swift.min(haveTotalRange.lowerBound, childRange.lowerBound)..<Swift.max(haveTotalRange.upperBound, childRange.upperBound)
            } else {
                totalRange = childRange
            }
        }
        return totalRange
    }
}
