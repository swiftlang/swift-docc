/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A collection of sparse segments that describe the subsequences that are common or different between two collections.
struct CollectionChanges {
    /// The segments of common elements, removed elements, and inserted elements.
    let segments: [Segment]
    
    /// A single segment that describe a number of elements that are either common between both collections, or that are removed or inserted in the second collection.
    struct Segment: Equatable {
        var kind: Kind
        var count: Int
        
        enum Kind: Equatable {
            /// These elements are common between both collections.
            case common
            /// These elements are removed from the first collection to produce the second collection.
            case remove
            /// These elements are inserted in the first collection to produce the second collection.
            case insert
        }
    }
    
    /// Creates a new collection changes value from the differences between to collections.
    ///
    /// - Parameters:
    ///   - from: The collection that the base is compared to.
    ///   - to: The base collection.
    ///   - areEquivalent: A closure that returns a Boolean value indicating whether two elements are equivalent.
    init<C>(from: C, to: C, by areEquivalent: (C.Element, C.Element) -> Bool = (==)) where C: BidirectionalCollection, C.Element: Hashable {
        guard !from.isEmpty else {
            segments = [.init(kind: .insert, count: to.count)]
            return
        }
        guard !to.isEmpty else {
            segments = [.init(kind: .remove, count: from.count)]
            return
        }
        
        var changes = ChangeSegmentBuilder(originalCount: from.count)
        // The `CollectionDifference` enumeration order is documented; first removals in descending order then insertions in ascending order.
        // https://github.com/apple/swift/blob/main/stdlib/public/core/CollectionDifference.swift#L216-L235
        for change in to.difference(from: from, by: areEquivalent) {
            switch change {
            case .remove(let offset, _, _):
                changes.remove(at: offset)
            case .insert(let offset, _, _):
                changes.insert(at: offset)
            }
        }
        segments = changes.segments
    }
}

/// A builder that applies collection differences to construct an array of ``Segment`` values.
///
/// - Important:
/// Removals need to be applied in reverse order. All removals need to be applied before applying any insertions. Insertions need to be applied in order.
private struct ChangeSegmentBuilder {
    typealias Segment = CollectionChanges.Segment
    
    private(set) var segments: [Segment]
    
    private var insertStartIndex = 0
    private var insertStartOffset = 0
    
    init(originalCount: Int) {
        self.segments = [ Segment(kind: .common, count: originalCount) ]
    }
    
    mutating func remove(at removalIndex: Int) {
        // Removals are applied in reverse order. When the first removal is applied, the only segment is the 'common' count.
        //
        // Each removal can be either be at the start of the segment, middle of the segment, or end of the segment.
        // - After removing from the start of the segment there can be no more removals (since those indices would be in ascending order).
        // - After removing from the middle, the 'common' segment is split in two with a 'remove' segment in between.
        //   Since the removal has to be at a lower index, it can only be applied to the split 'original' segment.
        // - After removing from the end, the 'common' segment is made shorter and a new 'remove' segment is added after it.
        //   Since the removal has to be at a lower index, it can only be applied to the shortened 'common' segment.
        //
        // This process repeats, meaning that every removal is always applied to the first segment.
        let segment = segments[0]
        assert(segment.kind == .common && removalIndex < segment.count, """
            The first segment should always be a 'common' segment (was \(segment.kind)) and (0 ..< \(segment.count)) should always contain the removal index (\(removalIndex)).
            If it's not, then that's means that the remove operations wasn't performed in reverse order.
            """)
        
        if removalIndex == 0 {
            // Removing at the start of the segment
            if segment.count == 1 {
                segments.remove(at: 0)
            } else {
                segments[0].count -= 1
            }
            
            if segments.first?.kind == .remove {
                segments[0].count += 1
            } else {
                segments.insert(Segment(kind: .remove, count: 1), at: 0)
            }
        }
        else if removalIndex == segment.count - 1 {
            // Removing at end of segment
            segments[0].count -= 1

            if segments.count > 1, segments[1].kind == .remove {
                segments[1].count += 1
            } else {
                // Insert at `endIndex` is equivalent to `append()`
                segments.insert(Segment(kind: .remove, count: 1), at: 1)
            }
        } else {
            // Removal within segment
            let lowerSegmentCount  = removalIndex
            let higherSegmentCount = segment.count - lowerSegmentCount - 1 // the 1 is for the removed element
            
            // Split the segment in two with a new removal segment in-between.
            segments[0...0] = [
                Segment(kind: .common, count: lowerSegmentCount),
                Segment(kind: .remove, count: 1),
                Segment(kind: .common, count: higherSegmentCount),
            ]
        }
    }
    
    private func findSegment(toInsertAt index: Int) -> (segment: Segment, startOffset: Int, segmentIndex: Int)? {
        // Insertions are applied in order. This means that we can start with the previous offset and index.
        var offset = insertStartOffset
        for segmentIndex in insertStartIndex ..< segments.count {
            let segment = segments[segmentIndex]
            if segment.kind == .remove {
                continue
            }
            
            if index <= offset + segment.count {
                return (segment, offset, segmentIndex)
            }
            offset += segment.count
        }
        return nil
    }
    
    mutating func insert(at insertIndex: Int) {
        guard let (segment, startOffset, segmentIndex) = findSegment(toInsertAt: insertIndex) else {
            assert(segments.count == 1 && segments[0].kind == .remove, """
                The only case when a segment can't be found in the loop is if the only segment is a 'remove' segment.
                This happens when all the 'common' elements are removed (meaning that the 'from' and 'to' values have nothing in common.
                """)
            
            segments.append(Segment(kind: .insert, count: 1))
            return
        }
        assert(segment.kind != .remove)
        
        insertStartOffset = startOffset
        insertStartIndex  = segmentIndex
        
        guard segment.kind != .insert else {
            segments[segmentIndex].count += 1
            return
        }
        assert(segment.kind == .common)
        
        if insertIndex == startOffset {
            // Insert at start of segment
            segments.insert(Segment(kind: .insert, count: 1), at: segmentIndex)
        } else if insertIndex == startOffset + segment.count {
            // Insert at end of segment
            let insertSegmentIndex = segmentIndex + 1
            
            // If this is the last segment, append a new 'insert' segment
            guard insertSegmentIndex < segments.count else {
                segments.append(Segment(kind: .insert, count: 1))
                return
            }
            
            switch segments[insertSegmentIndex].kind {
            case .insert:
                assertionFailure("Inserts are processed from low to high. There shouldn't be another 'insert' segment after 'segmentIndex'.")
                
            case .common:
                // If the next segment is a 'common' segment, insert a new 'insert' segment before it
                segments.insert(Segment(kind: .insert, count: 1), at: insertSegmentIndex)
                
            case .remove:
                // If the next segment is a 'remove' segment, skip over it so that insertions are always after removals.
                segments.insert(Segment(kind: .insert, count: 1), at: insertSegmentIndex + 1)
                
                assert(insertSegmentIndex + 2 == segments.count || segments[insertSegmentIndex + 2].kind == .common,
                       "If there's a segment after the remove segment, that is a segment of 'common' characters.")
            }
        } else {
            // Insert within segment
            let lowerSegmentCount  = insertIndex - startOffset
            let higherSegmentCount = segment.count - lowerSegmentCount // nothing to add
            
            // Split the segment in two with a new insertion segment in-between.
            segments[segmentIndex...segmentIndex] = [
                Segment(kind: .common, count: lowerSegmentCount),
                Segment(kind: .insert, count: 1),
                Segment(kind: .common, count: higherSegmentCount),
            ]
        }
    }
}
