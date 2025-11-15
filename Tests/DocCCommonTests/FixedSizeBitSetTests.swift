/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import DocCCommon
import Testing

struct FixedSizeBitSetTests {
    @Test
    func testBehavesSameAsSet() {
        var tiny = _FixedSizeBitSet<UInt64>()
        var real = Set<Int>()
        
        #expect(tiny.contains(4) == real.contains(4))
        #expect(tiny.insert(4) == real.insert(4))
        #expect(tiny.contains(4) == real.contains(4))
        #expect(tiny.count == real.count)
        
        #expect(tiny.insert(4) == real.insert(4))
        #expect(tiny.contains(4) == real.contains(4))
        #expect(tiny.count == real.count)
        
        #expect(tiny.insert(7) == real.insert(7))
        #expect(tiny.contains(7) == real.contains(7))
        #expect(tiny.count == real.count)
        
        #expect(tiny.update(with: 2) == real.update(with: 2))
        #expect(tiny.contains(2) == real.contains(2))
        #expect(tiny.count == real.count)
        
        #expect(tiny.remove(9) == real.remove(9))
        #expect(tiny.contains(9) == real.contains(9))
        #expect(tiny.count == real.count)
        
        #expect(tiny.remove(4) == real.remove(4))
        #expect(tiny.contains(4) == real.contains(4))
        #expect(tiny.count == real.count)
        
        tiny.formUnion([19])
        real.formUnion([19])
        #expect(tiny.contains(19) == real.contains(19))
        #expect(tiny.count == real.count)
        
        tiny.formSymmetricDifference([9])
        real.formSymmetricDifference([9])
        #expect(tiny.contains(7) == real.contains(7))
        #expect(tiny.contains(9) == real.contains(9))
        #expect(tiny.count == real.count)
        
        tiny.formIntersection([5,6,7])
        real.formIntersection([5,6,7])
        #expect(tiny.contains(4) == real.contains(4))
        #expect(tiny.contains(5) == real.contains(5))
        #expect(tiny.contains(6) == real.contains(6))
        #expect(tiny.contains(7) == real.contains(7))
        #expect(tiny.contains(8) == real.contains(8))
        #expect(tiny.contains(9) == real.contains(9))
        #expect(tiny.count == real.count)
        
        tiny.formUnion([11,29])
        real.formUnion([11,29])
        #expect(tiny.contains(11) == real.contains(11))
        #expect(tiny.contains(29) == real.contains(29))
        #expect(tiny.count == real.count)
        
        #expect(tiny.isSuperset(of: tiny) == real.isSuperset(of: real))
        #expect(tiny.isSuperset(of: []) ==   real.isSuperset(of: []))
        #expect(tiny.isSuperset(of: .init(tiny.dropFirst())) == real.isSuperset(of: .init(real.dropFirst())))
        #expect(tiny.isSuperset(of: .init(tiny.dropLast())) ==  real.isSuperset(of: .init(real.dropLast())))
    }
    
    @Test()
    func testCombinations() {
        do {
            let tiny: _FixedSizeBitSet<UInt8> = [0,1,2]
            #expect(tiny.allCombinationsOfValues().map { $0.sorted() } == [
                [0], [1], [2],
                [0,1], [0,2], [1,2],
                [0,1,2]
            ])
        }
        
        do {
            let tiny: _FixedSizeBitSet<UInt16> = [2,5,9]
            #expect(tiny.allCombinationsOfValues().map { $0.sorted() } == [
                [2], [5], [9],
                [2,5], [2,9], [5,9],
                [2,5,9]
            ])
        }
        
        do {
            let tiny: _FixedSizeBitSet<UInt32> = [3,4,7,11,15,16]
            
            let expected: [[Int]] = [
                // 1 elements
                [3], [4], [7], [11], [15], [16],
                // 2 elements
                [3,4], [3,7], [3,11], [3,15], [3,16],
                [4,7], [4,11], [4,15], [4,16],
                [7,11], [7,15], [7,16],
                [11,15], [11,16],
                [15,16],
                // 3 elements
                [3,4,7], [3,4,11], [3,4,15], [3,4,16], [3,7,11], [3,7,15], [3,7,16], [3,11,15], [3,11,16], [3,15,16],
                [4,7,11], [4,7,15], [4,7,16], [4,11,15], [4,11,16], [4,15,16],
                [7,11,15], [7,11,16], [7,15,16],
                [11,15,16],
                // 4 elements
                [3,4,7,11], [3,4,7,15], [3,4,7,16], [3,4,11,15], [3,4,11,16], [3,4,15,16], [3,7,11,15], [3,7,11,16], [3,7,15,16], [3,11,15,16],
                [4,7,11,15], [4,7,11,16], [4,7,15,16], [4,11,15,16],
                [7,11,15,16],
                // 5 elements
                [3,4,7,11,15], [3,4,7,11,16], [3,4,7,15,16], [3,4,11,15,16], [3,7,11,15,16],
                [4,7,11,15,16],
                // 6 elements
                [3,4,7,11,15,16],
            ]
            let actual = tiny.allCombinationsOfValues().map { Array($0) }
            
            #expect(expected.count == actual.count)
            
            // The order of combinations within a given size doesn't matter.
            // It's only important that all combinations of a given size exist and that the sizes are in order.
            let expectedBySize = [Int: [[Int]]](grouping: expected, by: \.count).sorted(by: { $0.key < $1.key }).map(\.value)
            let actualBySize   = [Int: [[Int]]](grouping: actual,   by: \.count).sorted(by: { $0.key < $1.key }).map(\.value)
            
            for (expectedForSize, actualForSize) in zip(expectedBySize, actualBySize) {
                #expect(expectedForSize.count == actualForSize.count)
                
                // Comparing [Int] descriptions to allow each same-size combination list to have different orders.
                // For example, these two lists of combinations (with the last 2 elements swapped) are considered equivalent:
                // [1, 2, 3], [1, 2, 4], [1, 3, 4], [2, 3, 4]
                // [1, 2, 3], [1, 2, 4], [2, 3, 4], [1, 3, 4]
                #expect(expectedForSize.map(\.description).sorted()
                       == actualForSize.map(\.description).sorted())
            }
        }
    }
    
    @Test
    func testIsSameSizeAsWrappedStorageType() async {
        // Size
        #expect(MemoryLayout<_FixedSizeBitSet<   Int8 >>.size == MemoryLayout<   Int8 >.size)
        #expect(MemoryLayout<_FixedSizeBitSet<  UInt8 >>.size == MemoryLayout<  UInt8 >.size)
        #expect(MemoryLayout<_FixedSizeBitSet<  Int16 >>.size == MemoryLayout<  Int16 >.size)
        #expect(MemoryLayout<_FixedSizeBitSet< UInt16 >>.size == MemoryLayout< UInt16 >.size)
        #expect(MemoryLayout<_FixedSizeBitSet<  Int32 >>.size == MemoryLayout<  Int32 >.size)
        #expect(MemoryLayout<_FixedSizeBitSet< UInt32 >>.size == MemoryLayout< UInt32 >.size)
        #expect(MemoryLayout<_FixedSizeBitSet<  Int64 >>.size == MemoryLayout<  Int64 >.size)
        #expect(MemoryLayout<_FixedSizeBitSet< UInt64 >>.size == MemoryLayout< UInt64 >.size)
        
        // Stride
        #expect(MemoryLayout<_FixedSizeBitSet<   Int8 >>.stride == MemoryLayout<   Int8 >.stride)
        #expect(MemoryLayout<_FixedSizeBitSet<  UInt8 >>.stride == MemoryLayout<  UInt8 >.stride)
        #expect(MemoryLayout<_FixedSizeBitSet<  Int16 >>.stride == MemoryLayout<  Int16 >.stride)
        #expect(MemoryLayout<_FixedSizeBitSet< UInt16 >>.stride == MemoryLayout< UInt16 >.stride)
        #expect(MemoryLayout<_FixedSizeBitSet<  Int32 >>.stride == MemoryLayout<  Int32 >.stride)
        #expect(MemoryLayout<_FixedSizeBitSet< UInt32 >>.stride == MemoryLayout< UInt32 >.stride)
        #expect(MemoryLayout<_FixedSizeBitSet<  Int64 >>.stride == MemoryLayout<  Int64 >.stride)
        #expect(MemoryLayout<_FixedSizeBitSet< UInt64 >>.stride == MemoryLayout< UInt64 >.stride)
        
        // Alignment
        #expect(MemoryLayout<_FixedSizeBitSet<   Int8 >>.alignment == MemoryLayout<   Int8 >.alignment)
        #expect(MemoryLayout<_FixedSizeBitSet<  UInt8 >>.alignment == MemoryLayout<  UInt8 >.alignment)
        #expect(MemoryLayout<_FixedSizeBitSet<  Int16 >>.alignment == MemoryLayout<  Int16 >.alignment)
        #expect(MemoryLayout<_FixedSizeBitSet< UInt16 >>.alignment == MemoryLayout< UInt16 >.alignment)
        #expect(MemoryLayout<_FixedSizeBitSet<  Int32 >>.alignment == MemoryLayout<  Int32 >.alignment)
        #expect(MemoryLayout<_FixedSizeBitSet< UInt32 >>.alignment == MemoryLayout< UInt32 >.alignment)
        #expect(MemoryLayout<_FixedSizeBitSet<  Int64 >>.alignment == MemoryLayout<  Int64 >.alignment)
        #expect(MemoryLayout<_FixedSizeBitSet< UInt64 >>.alignment == MemoryLayout< UInt64 >.alignment)
    }
}
