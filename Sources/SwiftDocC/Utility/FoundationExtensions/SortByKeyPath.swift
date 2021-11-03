/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Array {
    mutating func sort<T: Comparable>(by propertyKeyPath: KeyPath<Element, T>) {
        sort { (first, second) in
            return first[keyPath: propertyKeyPath] < second[keyPath: propertyKeyPath]
        }
    }
}

extension Sequence {
    func sorted<T: Comparable>(by propertyKeyPath: KeyPath<Element, T>) -> [Element] {
        return sorted { (first, second) in
            return first[keyPath: propertyKeyPath] < second[keyPath: propertyKeyPath]
        }
    }
}
