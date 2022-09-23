/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/


import Foundation
import XCTest
import SymbolKit

extension XCTestCase {
    public func makeSymbolGraph(moduleName: String, symbols: [SymbolGraph.Symbol] = [], relationships: [SymbolGraph.Relationship] = []) -> SymbolGraph {
        return SymbolGraph(
            metadata: SymbolGraph.Metadata(
                formatVersion: SymbolGraph.SemanticVersion(major: 0, minor: 6, patch: 0),
                generator: "unit-test"
            ),
            module: SymbolGraph.Module(
                name: moduleName,
                platform: SymbolGraph.Platform(architecture: nil, vendor: nil, operatingSystem: nil)
            ),
            symbols: symbols,
            relationships: relationships
        )
    }
    
    public func makeSymbolGraphString(moduleName: String, symbols: String = "", relationships: String = "") -> String {
        return """
        {
          "metadata": {
              "formatVersion": {
                  "major": 0,
                  "minor": 6,
                  "patch": 0
              },
              "generator": "unit-test"
          },
          "module": {
              "name": "\(moduleName)",
              "platform": { }
          },
          "relationships" : [
            \(relationships)
          ],
          "symbols" : [
            \(symbols)
          ]
        }
        """
    }
}
