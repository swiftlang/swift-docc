/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Protocol that provides merging and updating capabilities for list item entities that merge content between markdown files and symbol graphs.
/// 
/// The single property, ``listItemIdentifier`` returns the value that uniquely identifies the entity within the list item markdown.
protocol ListItemUpdatable {
    associatedtype IdentifierType: Comparable, CustomStringConvertible
    var listItemIdentifier: IdentifierType { get }
}

extension Array where Element: ListItemUpdatable {
    /// Merge a list values with the current array of values, updating the content of existing elements if they have the same identifier as new values, returning a new list.
    /// 
    /// If both lists are sorted, any new elements that don't match existing elements will be inserted to preserve a sorted list, otherwise they are appended.
    func insertAndUpdate(_ newElements: [Element], updater: (Element, Element) -> Element) -> [Element] {
        // Build a lookup table of the new elements
        var newElementLookup = [String: Element]()
        newElements.forEach { newElementLookup[$0.listItemIdentifier.description] = $0 }
        
        // Update existing elements with new data being passed in.
        var updatedElements = self.map { existingElement -> Element in
            if let newElement = newElementLookup.removeValue(forKey: existingElement.listItemIdentifier.description) {
                return updater(existingElement, newElement)
            }
            return existingElement
        }
        
        // Are there any extra elements that didn't match existing set?
        if newElementLookup.count > 0 {
            // If documented elements are in alphabetical order, merge new ones in rather than append them.
            let extraElements = newElements.filter { newElementLookup[$0.listItemIdentifier.description] != nil }
            if updatedElements.isSortedByIdentifier && newElements.isSortedByIdentifier {
                updatedElements.insertSortedElements(extraElements)
            } else {
                updatedElements.append(contentsOf: extraElements)
            }
        }

        return updatedElements
    }
    
    /// Checks whether the array of values are sorted alphabetically according to their `listItemIdentifier`.
    private var isSortedByIdentifier: Bool {
        if self.count < 2 { return true }
        if self.count == 2 { return (self[0].listItemIdentifier <= self[1].listItemIdentifier) }
        return (1..<self.count).allSatisfy {
            self[$0 - 1].listItemIdentifier <= self[$0].listItemIdentifier
        }
    }
    
    /// Insert a set of sorted elements at the correct locations of the existing sorted list.
    private mutating func insertSortedElements(_ newElements: [Element]) {
        self.reserveCapacity(self.count + newElements.count)
        
        var insertionPoint = 0
        var newElementPoint = 0
        while newElementPoint < newElements.count {
            if insertionPoint >= self.count {
                // Insertion point is the end of the list, so just append remaining content.
                self.append(contentsOf: newElements[newElementPoint..<newElements.count])
                return
            }
            if self[insertionPoint].listItemIdentifier > newElements[newElementPoint].listItemIdentifier {
                // Out of order. Inject the new element at this location.
                self.insert(newElements[newElementPoint], at: insertionPoint)
                newElementPoint += 1
            }
            insertionPoint += 1
        }
    }
    
}
