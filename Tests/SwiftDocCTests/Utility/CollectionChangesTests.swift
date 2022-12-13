/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

final class CollectionChangesTests: XCTestCase {
    
    // MARK: Remove
    
    func testRemoveOne() throws {
        // Remove at 0
        checkDiff(from: "ABCDEF", to: "BCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-1 o5")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-A-]BCDEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o | BCDEF
            - |A
            + |
            """)
        }
        
        // Remove at 1
        checkDiff(from: "ABCDEF", to: "ACDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o1 -1 o4")
            XCTAssertEqual(diff.inlineDiffDescription(), "A[-B-]CDEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |A CDEF
            - | B
            + |
            """)
        }
        
        // Remove at 2
        checkDiff(from: "ABCDEF", to: "ABDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o2 -1 o3")
            XCTAssertEqual(diff.inlineDiffDescription(), "AB[-C-]DEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |AB DEF
            - |  C
            + |
            """)
        }
        
        // Remove at 3
        checkDiff(from: "ABCDEF", to: "ABCEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 -1 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC[-D-]EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC EF
            - |   D
            + |
            """)
        }
        
        // Remove at 4
        checkDiff(from: "ABCDEF", to: "ABCDF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o4 -1 o1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABCD[-E-]F")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABCD F
            - |    E
            + |
            """)
        }
        
        // Remove at 5
        checkDiff(from: "ABCDEF", to: "ABCDE") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o5 -1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABCDE[-F-]")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABCDE
            - |     F
            + |
            """)
        }
    }
    
    func testRemoveTwo() throws {
        // Remove at 0 & 1
        checkDiff(from: "ABCDEF", to: "CDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-2 o4")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-AB-]CDEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |  CDEF
            - |AB
            + |
            """)
        }
        
        // Remove at 1 & 2
        checkDiff(from: "ABCDEF", to: "ADEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o1 -2 o3")
            XCTAssertEqual(diff.inlineDiffDescription(), "A[-BC-]DEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |A  DEF
            - | BC
            + |
            """)
        }
        
        // Remove at 2 & 3
        checkDiff(from: "ABCDEF", to: "ABEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o2 -2 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "AB[-CD-]EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |AB  EF
            - |  CD
            + |
            """)
        }
        
        // Remove at 3 & 4
        checkDiff(from: "ABCDEF", to: "ABCF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 -2 o1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC[-DE-]F")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC  F
            - |   DE
            + |
            """)
        }
        
        // Remove at 4 & 5
        checkDiff(from: "ABCDEF", to: "ABCD") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o4 -2")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABCD[-EF-]")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABCD
            - |    EF
            + |
            """)
        }
    }
    
    func testRemoveAllButOne() throws {
        // Remove all but 0
        checkDiff(from: "ABCDEF", to: "A") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o1 -5")
            XCTAssertEqual(diff.inlineDiffDescription(), "A[-BCDEF-]")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |A
            - | BCDEF
            + |
            """)
        }
        
        // Remove all but 1
        checkDiff(from: "ABCDEF", to: "B") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-1 o1 -4")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-A-]B[-CDEF-]")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o | B
            - |A CDEF
            + |
            """)
        }
        
        // Remove all but 2
        checkDiff(from: "ABCDEF", to: "C") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-2 o1 -3")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-AB-]C[-DEF-]")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |  C
            - |AB DEF
            + |
            """)
        }
        
        // Remove all but
        checkDiff(from: "ABCDEF", to: "D") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-3 o1 -2")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-ABC-]D[-EF-]")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |   D
            - |ABC EF
            + |
            """)
        }
        
        // Remove at 4
        checkDiff(from: "ABCDEF", to: "E") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-4 o1 -1")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-ABCD-]E[-F-]")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |    E
            - |ABCD F
            + |
            """)
        }
        
        // Remove at 5
        checkDiff(from: "ABCDEF", to: "F") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-5 o1")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-ABCDE-]F")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |     F
            - |ABCDE
            + |
            """)
        }
    }
    
    func testRemoveAll() throws {
        // Remove all
        checkDiff(from: "ABCDEF", to: "") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-6")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-ABCDEF-]")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |
            - |ABCDEF
            + |
            """)
        }
    }
    
    // MARK: Insert
    
    func testInsertOne() throws {
        // Insert at 0
        checkDiff(from: "ABCDEF", to: "xABCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "+1 o6")
            XCTAssertEqual(diff.inlineDiffDescription(), "{+x+}ABCDEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o | ABCDEF
            - |
            + |x
            """)
        }
        
        // Insert at 1
        checkDiff(from: "ABCDEF", to: "AxBCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o1 +1 o5")
            XCTAssertEqual(diff.inlineDiffDescription(), "A{+x+}BCDEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |A BCDEF
            - |
            + | x
            """)
        }

        // Insert at 2
        checkDiff(from: "ABCDEF", to: "ABxCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o2 +1 o4")
            XCTAssertEqual(diff.inlineDiffDescription(), "AB{+x+}CDEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |AB CDEF
            - |
            + |  x
            """)
        }

        // Insert at 3
        checkDiff(from: "ABCDEF", to: "ABCxDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 +1 o3")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC{+x+}DEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC DEF
            - |
            + |   x
            """)
        }

        // Insert at 4
        checkDiff(from: "ABCDEF", to: "ABCDxEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o4 +1 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABCD{+x+}EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABCD EF
            - |
            + |    x
            """)
        }

        // Insert at 5
        checkDiff(from: "ABCDEF", to: "ABCDExF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o5 +1 o1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABCDE{+x+}F")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABCDE F
            - |
            + |     x
            """)
        }

        // Insert at 6
        checkDiff(from: "ABCDEF", to: "ABCDEFx") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o6 +1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABCDEF{+x+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABCDEF
            - |
            + |      x
            """)
        }
    }
    
    func testInsertTwo() throws {
        // Insert at 0 & 1
        checkDiff(from: "ABCDEF", to: "xyABCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "+2 o6")
            XCTAssertEqual(diff.inlineDiffDescription(), "{+xy+}ABCDEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |  ABCDEF
            - |
            + |xy
            """)
        }

        // Insert at 1 & 2
        checkDiff(from: "ABCDEF", to: "AxyBCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o1 +2 o5")
            XCTAssertEqual(diff.inlineDiffDescription(), "A{+xy+}BCDEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |A  BCDEF
            - |
            + | xy
            """)
        }

        // Insert at 2 & 3
        checkDiff(from: "ABCDEF", to: "ABxyCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o2 +2 o4")
            XCTAssertEqual(diff.inlineDiffDescription(), "AB{+xy+}CDEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |AB  CDEF
            - |
            + |  xy
            """)
        }

        // Insert at 3 & 4
        checkDiff(from: "ABCDEF", to: "ABCxyDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 +2 o3")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC{+xy+}DEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC  DEF
            - |
            + |   xy
            """)
        }

        // Insert at 4 & 5
        checkDiff(from: "ABCDEF", to: "ABCDxyEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o4 +2 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABCD{+xy+}EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABCD  EF
            - |
            + |    xy
            """)
        }

        // Insert at 5 & 6
        checkDiff(from: "ABCDEF", to: "ABCDExyF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o5 +2 o1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABCDE{+xy+}F")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABCDE  F
            - |
            + |     xy
            """)
        }

        // Insert at 6 & 7
        checkDiff(from: "ABCDEF", to: "ABCDEFxy") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o6 +2")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABCDEF{+xy+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABCDEF
            - |
            + |      xy
            """)
        }
    }
    
    func testInsertAllButOne() throws {
        // Insert all but 0
        checkDiff(from: "A", to: "ABCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o1 +5")
            XCTAssertEqual(diff.inlineDiffDescription(), "A{+BCDEF+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |A
            - |
            + | BCDEF
            """)
        }
        
        // Insert all but 1
        checkDiff(from: "B", to: "ABCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "+1 o1 +4")
            XCTAssertEqual(diff.inlineDiffDescription(), "{+A+}B{+CDEF+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o | B
            - |
            + |A CDEF
            """)
        }
        
        // Insert all but 2
        checkDiff(from: "C", to: "ABCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "+2 o1 +3")
            XCTAssertEqual(diff.inlineDiffDescription(), "{+AB+}C{+DEF+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |  C
            - |
            + |AB DEF
            """)
        }
        
        // Insert all but 3
        checkDiff(from: "D", to: "ABCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "+3 o1 +2")
            XCTAssertEqual(diff.inlineDiffDescription(), "{+ABC+}D{+EF+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |   D
            - |
            + |ABC EF
            """)
        }
        
        // Insert all but 4
        checkDiff(from: "E", to: "ABCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "+4 o1 +1")
            XCTAssertEqual(diff.inlineDiffDescription(), "{+ABCD+}E{+F+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |    E
            - |
            + |ABCD F
            """)
        }
        
        // Insert all but 5
        checkDiff(from: "F", to: "ABCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "+5 o1")
            XCTAssertEqual(diff.inlineDiffDescription(), "{+ABCDE+}F")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |     F
            - |
            + |ABCDE
            """)
        }
    }
    
    func testInsertAll() throws {
        // Remove all
        checkDiff(from: "", to: "ABCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "+6")
            XCTAssertEqual(diff.inlineDiffDescription(), "{+ABCDEF+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |
            - |
            + |ABCDEF
            """)
        }
    }
    
    // MARK: Remove and insert
        
    func testReplaceOne() throws {
        // Replace at 0
        checkDiff(from: "ABCDEF", to: "aBCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-1 +1 o5")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-A-]{+a+}BCDEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o | BCDEF
            - |A
            + |a
            """)
        }

        // Replace at 1
        checkDiff(from: "ABCDEF", to: "AbCDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o1 -1 +1 o4")
            XCTAssertEqual(diff.inlineDiffDescription(), "A[-B-]{+b+}CDEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |A CDEF
            - | B
            + | b
            """)
        }

        // Replace at 2
        checkDiff(from: "ABCDEF", to: "ABcDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o2 -1 +1 o3")
            XCTAssertEqual(diff.inlineDiffDescription(), "AB[-C-]{+c+}DEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |AB DEF
            - |  C
            + |  c
            """)
        }

        // Replace at 3
        checkDiff(from: "ABCDEF", to: "ABCdEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 -1 +1 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC[-D-]{+d+}EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC EF
            - |   D
            + |   d
            """)
        }

        // Replace at 4
        checkDiff(from: "ABCDEF", to: "ABCDeF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o4 -1 +1 o1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABCD[-E-]{+e+}F")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABCD F
            - |    E
            + |    e
            """)
        }

        // Replace at 5
        checkDiff(from: "ABCDEF", to: "ABCDEf") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o5 -1 +1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABCDE[-F-]{+f+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABCDE
            - |     F
            + |     f
            """)
        }
    }
    
    func testReplaceAll() throws {
        // Replace all
        checkDiff(from: "ABCDEF", to: "abcdef") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-6 +6")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-ABCDEF-]{+abcdef+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |
            - |ABCDEF
            + |abcdef
            """)
        }
    }
    
    func testSwapOne() throws {
        // Swap 0 and 1
        checkDiff(from: "ABCDEF", to: "BACDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-1 o1 +1 o4")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-A-]B{+A+}CDEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o | B CDEF
            - |A
            + |  A
            """)
        }
        
        // Swap 1 and 2
        checkDiff(from: "ABCDEF", to: "ACBDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o1 -1 o1 +1 o3")
            XCTAssertEqual(diff.inlineDiffDescription(), "A[-B-]C{+B+}DEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |A C DEF
            - | B
            + |   B
            """)
        }
        
        // Swap 2 and 3
        checkDiff(from: "ABCDEF", to: "ABDCEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o2 -1 o1 +1 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "AB[-C-]D{+C+}EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |AB D EF
            - |  C
            + |    C
            """)
        }
        
        // Swap 3 and 4
        checkDiff(from: "ABCDEF", to: "ABCEDF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 -1 o1 +1 o1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC[-D-]E{+D+}F")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC E F
            - |   D
            + |     D
            """)
        }
        
        // Swap 4 and 5
        checkDiff(from: "ABCDEF", to: "ABCDFE") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o4 -1 o1 +1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABCD[-E-]F{+E+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABCD F
            - |    E
            + |      E
            """)
        }
    }
    
    func testRemoveWhenMiddleIsAlsoRemoved() throws {
        // Remove 3 and 0
        checkDiff(from: "ABCDEFG", to: "BCEFG") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-1 o2 -1 o3")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-A-]BC[-D-]EFG")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o | BC EFG
            - |A  D
            + |
            """)
        }
        
        // Remove 3 and 1
        checkDiff(from: "ABCDEFG", to: "ACEFG") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o1 -1 o1 -1 o3")
            XCTAssertEqual(diff.inlineDiffDescription(), "A[-B-]C[-D-]EFG")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |A C EFG
            - | B D
            + |
            """)
        }
        
        // Remove 3 and 2
        checkDiff(from: "ABCDEFG", to: "ABEFG") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o2 -2 o3")
            XCTAssertEqual(diff.inlineDiffDescription(), "AB[-CD-]EFG")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |AB  EFG
            - |  CD
            + |
            """)
        }
        
        // Remove 4 and 3
        checkDiff(from: "ABCDEFG", to: "ABCFG") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 -2 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC[-DE-]FG")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC  FG
            - |   DE
            + |
            """)
        }
        
        // Remove 5 and 3
        checkDiff(from: "ABCDEFG", to: "ABCEG") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 -1 o1 -1 o1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC[-D-]E[-F-]G")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC E G
            - |   D F
            + |
            """)
        }
        
        // Remove 6 and 3
        checkDiff(from: "ABCDEFG", to: "ABCEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 -1 o2 -1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC[-D-]EF[-G-]")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC EF
            - |   D  G
            + |
            """)
        }
    }
    
    func testInsertWhenMiddleIsAlsoRemoved() throws {
        // Remove at 3 and insert at 0
        checkDiff(from: "ABCDEF", to: "xABCEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "+1 o3 -1 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "{+x+}ABC[-D-]EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o | ABC EF
            - |    D
            + |x
            """)
        }
        
        // Remove at 3 and insert at 1
        checkDiff(from: "ABCDEF", to: "AxBCEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o1 +1 o2 -1 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "A{+x+}BC[-D-]EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |A BC EF
            - |    D
            + | x
            """)
        }
        
        // Remove at 3 and insert at 2
        checkDiff(from: "ABCDEF", to: "ABxCEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o2 +1 o1 -1 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "AB{+x+}C[-D-]EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |AB C EF
            - |    D
            + |  x
            """)
        }
        
        // Remove at 3 and insert at 3
        checkDiff(from: "ABCDEF", to: "ABCxEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 -1 +1 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC[-D-]{+x+}EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC EF
            - |   D
            + |   x
            """)
        }
        
        // Remove at 3 and insert at 4
        checkDiff(from: "ABCDEF", to: "ABCExF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 -1 o1 +1 o1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC[-D-]E{+x+}F")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC E F
            - |   D
            + |     x
            """)
        }
        
        // Remove at 3 and insert at 5
        checkDiff(from: "ABCDEF", to: "ABCEFx") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 -1 o2 +1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC[-D-]EF{+x+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC EF
            - |   D
            + |      x
            """)
        }
    }
    
    func testMixedDifferences() throws {
        // Remove at start and insert at end
        checkDiff(from: "ABCDEF", to: "CDEFxyz") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-2 o4 +3")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-AB-]CDEF{+xyz+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |  CDEF
            - |AB
            + |      xyz
            """)
        }
        
        
        // Remove at start and replace 1 with 3
        checkDiff(from: "ABCDEF", to: "DxyzF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-3 o1 -1 +3 o1")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-ABC-]D[-E-]{+xyz+}F")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |   D   F
            - |ABC E
            + |    xyz
            """)
        }
        
        // Replace 3 with 1 and replace last
        checkDiff(from: "ABCDEF", to: "AxEf") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o1 -3 +1 o1 -1 +1")
            XCTAssertEqual(diff.inlineDiffDescription(), "A[-BCD-]{+x+}E[-F-]{+f+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |A   E
            - | BCD F
            + | x   f
            """)
        }
        
        // Replace 1 with 3 and replace last
        checkDiff(from: "ABCDEF", to: "ABxyzDEf") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o2 -1 +3 o2 -1 +1")
            XCTAssertEqual(diff.inlineDiffDescription(), "AB[-C-]{+xyz+}DE[-F-]{+f+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |AB   DE
            - |  C    F
            + |  xyz  f
            """)
        }
        
        // Replace only character
        checkDiff(from: "A", to: "B") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-1 +1")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-A-]{+B+}")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |
            - |A
            + |B
            """)
        }
    }
    
    func testRemoveWhenMiddleIsAlsoInserted() throws {
        // Remove at 0 and insert at 3
        checkDiff(from: "ABCDEF", to: "BCDxEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "-1 o3 +1 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "[-A-]BCD{+x+}EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o | BCD EF
            - |A
            + |    x
            """)
        }
        
        // Remove at 1 and insert at 3
        checkDiff(from: "ABCDEF", to: "ACDxEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o1 -1 o2 +1 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "A[-B-]CD{+x+}EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |A CD EF
            - | B
            + |    x
            """)
        }
        
        // Remove at 2 and insert at 3
        checkDiff(from: "ABCDEF", to: "ABDxEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o2 -1 o1 +1 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "AB[-C-]D{+x+}EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |AB D EF
            - |  C
            + |    x
            """)
        }
        
        // Remove at 3 and insert at 3
        checkDiff(from: "ABCDEF", to: "ABCxEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 -1 +1 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC[-D-]{+x+}EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC EF
            - |   D
            + |   x
            """)
        }
        
        // Remove at 4 and insert at 3
        checkDiff(from: "ABCDEF", to: "ABCxDF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 +1 o1 -1 o1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC{+x+}D[-E-]F")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC D F
            - |     E
            + |   x
            """)
        }
        
        // Remove at 5 and insert at 3
        checkDiff(from: "ABCDEF", to: "ABCxDE") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 +1 o2 -1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC{+x+}DE[-F-]")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC DE
            - |      F
            + |   x
            """)
        }
    }
    
    func testInsertWhenMiddleIsAlsoInserted() throws {
        // Insert at 0 and 4
        checkDiff(from: "ABCDEF", to: "xABCyDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "+1 o3 +1 o3")
            XCTAssertEqual(diff.inlineDiffDescription(), "{+x+}ABC{+y+}DEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o | ABC DEF
            - |
            + |x   y
            """)
        }

        // Insert at 1 and 4
        checkDiff(from: "ABCDEF", to: "AxBCyDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o1 +1 o2 +1 o3")
            XCTAssertEqual(diff.inlineDiffDescription(), "A{+x+}BC{+y+}DEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |A BC DEF
            - |
            + | x  y
            """)
        }

        // Insert at 2 and 4
        checkDiff(from: "ABCDEF", to: "ABxCyDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o2 +1 o1 +1 o3")
            XCTAssertEqual(diff.inlineDiffDescription(), "AB{+x+}C{+y+}DEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |AB C DEF
            - |
            + |  x y
            """)
        }

        // Insert at 3 and 4
        checkDiff(from: "ABCDEF", to: "ABCxyDEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o3 +2 o3")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABC{+xy+}DEF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABC  DEF
            - |
            + |   xy
            """)
        }

        // Insert at 4 and 5
        checkDiff(from: "ABCDEF", to: "ABCDxyEF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o4 +2 o2")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABCD{+xy+}EF")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABCD  EF
            - |
            + |    xy
            """)
        }

        // Insert at 4 and 6
        checkDiff(from: "ABCDEF", to: "ABCDxEyF") { diff in
            XCTAssertEqual(diff.segmentDescription(), "o4 +1 o1 +1 o1")
            XCTAssertEqual(diff.inlineDiffDescription(), "ABCD{+x+}E{+y+}F")
            XCTAssertEqual(diff.multilineDiffDescription(), """
            o |ABCD E F
            - |
            + |    x y
            """)
        }
    }
    
    // MARK: Miscellaneous attributes
    
    func testMiscellaneousChangeSegmentAttributes() throws {
        // This test checks a few attributes that should be true for all diff segments.
        // It approximates "all diff segments" by diffing all combination of 30 random letters sequences (of A through F)
        
        let randomLetterSequences: [String] = [
            "CAEBEBACCDB",
            "CCFCED",
            "DCC",
            "EAAFFDEBECCBADFED",
            "CEDBABCCEF",
            "FBDDA",
            "BBDECACCEFDDCEDF",
            "ADAAD",
            "A",
            "ACAFADAFBDE",
            "BAFDEDDAAFD",
            "ECFABDEFCBEFDC",
            "ABAE",
            "BCFFBDCFFEACCADFE",
            "",
            "ECE",
            "FBDCEBDFB",
            "AEDDCAFFAADEB",
            "EEADBDE",
            "DCDFDAFEBCDBCADAD",
            "DBACDEBAFAE",
            "ECFBFC",
            "CCAFCCFBB",
            "FCFEACCFBED",
            "DFEDFBECBFE",
            "DAFBCCCBFCCBEFDE",
            "DBBCBFA",
            "C",
            "AACFCAFBECDBFCCE",
            "FEBEBEDCFCBBEFAC",
        ]
        
        for from in randomLetterSequences {
            for to in randomLetterSequences where from != to {
                checkDiff(from: from, to: to) { diff in
                    // Counts
                    XCTAssertEqual(
                        diff.segments.filter { $0.kind != .insert }.map(\.count).reduce(0, +),
                        from.count,
                        "Total count of 'common' and 'removed' segments is the 'from' count"
                    )
                    
                    XCTAssertEqual(
                        diff.segments.filter { $0.kind != .remove }.map(\.count).reduce(0, +),
                        to.count,
                        "Total count of 'common' and 'insert' segments is the 'to' count"
                    )
                    
                    let adjacentPairs = zip(diff.segments, diff.segments.dropFirst())
                    
                    // Structure
                    XCTAssert(
                        adjacentPairs.allSatisfy { $0.kind != $1.kind},
                        "Segments of same kind are not repeated."
                    )
                    
                    XCTAssert(
                        adjacentPairs.allSatisfy { ($0.kind, $1.kind) != (.insert, .remove) },
                        "Removals appear before insertions."
                    )
                    
                    XCTAssert(
                        diff.segments.allSatisfy { $0.count > 0 },
                        "Segments are not empty."
                    )
                }
            }
        }
    }
}

// MARK: - Test helpers

/// A type that wraps CollectionChanges and holds the ``to`` and ``from`` values.
///
/// This allows tests to assert on the diffs without needing to hold the Strings (or other collections) in real use.
struct TextDiffSegmentsTestWrapper {
    private let wrapped: CollectionChanges
    
    var segments: [CollectionChanges.Segment] { wrapped.segments }
    
    let from: String
    let to: String
    init(from: String, to: String) {
        self.from = from
        self.to = to
        self.wrapped = CollectionChanges(from: from, to: to)
    }
    
    func segmentDescription() -> String {
        return wrapped.segments.map {
            switch $0.kind {
            case .common:  return "o\($0.count)"
            case .remove:  return "-\($0.count)"
            case .insert: return "+\($0.count)"
            }
        }.joined(separator: " ")
    }
    
    func inlineDiffDescription() -> String {
        var result = ""
        var fromIndex = 0
        var toIndex = 0
        
        for segment in wrapped.segments {
            switch segment.kind {
            case .common:
                let start = from.index(from.startIndex, offsetBy: fromIndex)
                let end = from.index(start, offsetBy: segment.count)
                result += from[start ..< end]
                
                fromIndex += segment.count
                toIndex += segment.count
            case .remove:
                let start = from.index(from.startIndex, offsetBy: fromIndex)
                let end = from.index(start, offsetBy: segment.count)
                result += "[-\(from[start ..< end])-]"
                
                fromIndex += segment.count
            case .insert:
                let start = to.index(to.startIndex, offsetBy: toIndex)
                let end = to.index(start, offsetBy: segment.count)
                result += "{+\(to[start ..< end])+}"
                
                toIndex += segment.count
            }
        }
        
        return result
    }
    
    func multilineDiffDescription() -> String {
        let storage = wrapped.segments
        var commonRow = "o |"
        var removeRow = "- |"
        var insertRow = "+ |"
        var fromIndex = 0
        var toIndex = 0
        
        var previousSegment: CollectionChanges.Segment? = nil
        
        for segment in storage {
            defer { previousSegment = segment }
            switch segment.kind {
            case .common:
                let start = from.index(from.startIndex, offsetBy: fromIndex)
                let end = from.index(start, offsetBy: segment.count)
                commonRow += from[start ..< end]
                removeRow += String(repeating: " ", count: segment.count)
                insertRow += String(repeating: " ", count: segment.count)
                
                fromIndex += segment.count
                toIndex += segment.count
            case .remove:
                let start = from.index(from.startIndex, offsetBy: fromIndex)
                let end = from.index(start, offsetBy: segment.count)
                commonRow += String(repeating: " ", count: segment.count)
                removeRow += from[start ..< end]
                insertRow += String(repeating: " ", count: segment.count)
                
                fromIndex += segment.count
            case .insert:
                let spaceToAdd: Int
                if let previousSegment = previousSegment, previousSegment.kind == .remove {
                    spaceToAdd = segment.count - previousSegment.count
                    // Left align with the previous removed segment
                    insertRow.removeLast(previousSegment.count)
                } else {
                    spaceToAdd = segment.count
                }
                
                let start = to.index(from.startIndex, offsetBy: toIndex)
                let end = to.index(start, offsetBy: segment.count)
                insertRow += to[start ..< end]
                if 0 < spaceToAdd {
                    commonRow += String(repeating: " ", count: spaceToAdd)
                    removeRow += String(repeating: " ", count: spaceToAdd)
                } else {
                    // Pad at the end so that all segments align
                    insertRow  += String(repeating: " ", count: -spaceToAdd)
                }
                
                toIndex += segment.count
            }
            
            assert(commonRow.count == removeRow.count)
            assert(commonRow.count == insertRow.count)
        }
        
        return """
        \(commonRow.trimmingCharacters(in: .whitespaces))
        \(removeRow.trimmingCharacters(in: .whitespaces))
        \(insertRow.trimmingCharacters(in: .whitespaces))
        """
    }
}

extension CollectionChangesTests {
    func checkDiff(from: String, to: String, verification: (TextDiffSegmentsTestWrapper) -> Void) {
        verification(TextDiffSegmentsTestWrapper(from: from, to: to))
    }
}
