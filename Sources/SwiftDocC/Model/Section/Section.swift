/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// A structured piece of documentation content.
public protocol Section {
    /// The title of the section.
    static var title: String? { get }
    
    /// The section's markup content.
    var content: [Markup] { get }
}

extension Markup {
    /**
     Returns the index of the first child element that is a heading with the given level and text.
     
     - parameter level: The level of the heading.
     - parameter name: The text of the heading.
     - returns: The index of the first child element that is a heading with the given level and text.
                If no child of this element is a matching heading element, returns `nil`.
     */
    func sectionHeadingIndex(level: Int, named name: String? = nil) -> Int? {
        return (0..<childCount).first { index -> Bool in
            guard let child = child(at: index),
                  let heading = child as? Heading,
                heading.level == level else {
                    return false
            }
            if let name = name {
                guard heading.plainText == name else {
                    return false
                }
            }
            return true
        }
    }
    
    /**
     Returns the index of the first child element that is a heading with the given level, starting the search at the given index.
     
     - parameter startIndex: The index from which to start the search.
     - parameter level: The level of the heading.
     - returns: The index of the first child element that is a heading of the given level.
                If no child of this element is a matching heading element, returns `nil`.
     */
    func indexToNextHeading(from startIndex: Int, level: Int) -> Int? {

        return (startIndex..<childCount).first { index -> Bool in
            guard let child = child(at: index),
                  let heading = child as? Heading,
                heading.level == level else {
                    return false
            }
            return true
        }
    }
}
