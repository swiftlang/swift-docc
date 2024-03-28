/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Array {
    mutating func sort(by propertyKeyPath: KeyPath<Element, some Comparable>) {
        sort { (first, second) in
            return first[keyPath: propertyKeyPath] < second[keyPath: propertyKeyPath]
        }
    }
}

extension Sequence {
    func sorted(by propertyKeyPath: KeyPath<Element, some Comparable>) -> [Element] {
        return sorted { (first, second) in
            return first[keyPath: propertyKeyPath] < second[keyPath: propertyKeyPath]
        }
    }
}
