/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import DocCCommon
import Foundation
import Testing
import SymbolKit

struct FastSymbolGraphJSONDecoderTest {
    
    @Test
    func decodingIntWithLeadingSpace() throws {
        let json = "      123"
        
        let number = try FastSymbolGraphJSONDecoder.decode(Int.self, from: Data(json.utf8))
        #expect(number == 123)
    }
    
    @Test
    func decodingStringArray() throws {
        let json = #"""
        [
          "ABC",
           "DEF",
            "GHI"
        ]
        """#
        
        let array = try FastSymbolGraphJSONDecoder.decode([String].self, from: Data(json.utf8))
        #expect(array == ["ABC","DEF","GHI"])
    }
    
    @Test
    func decodingLineListWithEscapedSlashBeforeStringDelimiter() throws {
        // This example has some extra indentation because it's extracted from a real example
        let json = #"""
              { 
                "lines" : [
                  {
                    "text" : "  If one cookie costs \\(price) dollars, \\"
                  },
                  {
                    "text" : "    let b = (\"a\", 1, 2, 3, 4, 5)"
                  }
                ]
              }
        """#
        let lineList = try FastSymbolGraphJSONDecoder.decode(SymbolGraph.LineList.self, from: Data(json.utf8))
        
        #expect(lineList.lines.count == 2)
    }
    
    @Test
    func decodingLineList2() throws {
        // This example has some extra indentation because it's extracted from a real example
        let json = #"""
              {
                "lines" : [
                  {
                    "text" : "Places the annotation \"as-is\"."
                  }
                ]
              }
        """#
        let lineList = try FastSymbolGraphJSONDecoder.decode(SymbolGraph.LineList.self, from: Data(json.utf8))
        
        #expect(lineList.lines.count == 1)
    }
    
    @Test
    func decodingLineListWithEscapedQuoteBeforeStringDelimiter() throws {
        // This example has some extra indentation because it's extracted from a real example
        let json = #"""
              {
                "lines" : [
                  {
                    "text" : "Provides support for \"if\" statements with `#available()` clauses in"
                  },
                  {
                    "text" : "multi-statement closures, producing conditional content for the \"then\""
                  },
                  {
                    "text" : "branch, i.e. the conditionally-available branch."
                  }
                ]
              }
        """#
        
        let data = Data(json.utf8)
        let lineList = try FastSymbolGraphJSONDecoder.decode(SymbolGraph.LineList.self, from: data)
        
        #expect(lineList.lines.count == 3)
    }
    
    @Test
    func decodingVersion() throws {
        // The key "major" has all the bits of "minor" set (with a couple extra bit).
        // Verify that this doesn't cause any decoding problems (which would cause the version to decode as "2.0.3")
        let json = #"""
        {
          "major" : 1,
          "minor" : 2,
          "patch" : 3
        }
        """#
        let version = try FastSymbolGraphJSONDecoder.decode(SymbolGraph.SemanticVersion.self, from: Data(json.utf8))
        #expect(version.description == "1.2.3")
    }
}
