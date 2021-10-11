/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Enumerator over an array of items that wraps around.
struct WrappingEnumerator<Element> {
    var items: Array<Element> = [] {
        didSet { if index >= items.count { index = 0 } }
    }
    private(set) var index: Int = 0
    
    /// Returns the next item in the array, starts from index `0` if end of array reached.
    mutating func next() -> Element {
        defer {
            index += 1
            if index >= items.count {
                index = 0
            }
        }
        return items[index]
    }
}
