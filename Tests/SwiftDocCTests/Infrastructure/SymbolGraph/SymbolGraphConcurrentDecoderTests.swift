/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SymbolKit
@testable import SwiftDocC

class SymbolGraphConcurrentDecoderTests: XCTestCase {
    
    //
    // MARK: - Utility functions to create larger symbol graphs for testing
    //
    
    private let lines = SymbolGraph.LineList(Array(repeating: SymbolGraph.LineList.Line(text: "Apple Banana Orange Pear Mango Kiwi Grapefruit Melon Watermelon", range: nil), count: 20))
    private func makeSymbol(index: Int) -> SymbolGraph.Symbol {
        return SymbolGraph.Symbol(identifier: .init(precise: UUID().uuidString, interfaceLanguage: "swift"), names: .init(title: "Symbol \(index)", navigator: nil, subHeading: [SymbolGraph.Symbol.DeclarationFragments.Fragment(kind: .identifier, spelling: "Symbol \(index)", preciseIdentifier: UUID().uuidString)], prose: "Symbol \(index)"), pathComponents: ["Module", "Symbol\(index)"], docComment: lines, accessLevel: .init(rawValue: "public"), kind: .init(parsedIdentifier: .struct, displayName: "Struct"), mixins: [:])
    }
    private func addSymbols(count: Int, graph: inout SymbolGraph) {
        for index in 0...count {
            let symbol = makeSymbol(index: index)
            graph.symbols[symbol.identifier.precise] = symbol
        }
    }
    private func symbolGraphRoundtrip(from data: Data) throws -> SymbolGraph {
        return try SymbolGraphConcurrentDecoder.decode(data)
    }
    
    // MARK: - Tests
    
    /// Tests decoding symbol graphs of various sizes with both vanilla JSONDecoder and
    /// the custom concurrent decoder and verifies the end results are always the same.
    func testEncodingDecodingConcurrently() throws {
        
        // Load and decode a small symbol graph
        let topLevelCurationSGFURL = Bundle.module.url(
            forResource: "TopLevelCuration.symbols", withExtension: "json", subdirectory: "Test Resources")!

        let data = try Data(contentsOf: topLevelCurationSGFURL)
        var graph = try JSONDecoder().decode(SymbolGraph.self, from: data)
        
        
        do {
            // Decode small symbol graph concurrently and compare the result
            let concurrent = try symbolGraphRoundtrip(from: data)
            XCTAssertEqual(graph.symbols.count, concurrent.symbols.count)
            XCTAssertEqual(graph.relationships.count, concurrent.relationships.count)
        }
        
        for _ in 0 ... 10 {
            // Keep adding more symbols to test various small sizes up to 100 symbols
            addSymbols(count: 11, graph: &graph)
            do {
                let data = try JSONEncoder().encode(graph)
                
                // Verify the results when decoding concurrently
                let concurrent = try symbolGraphRoundtrip(from: data)
                XCTAssertEqual(graph.symbols.count, concurrent.symbols.count)
                XCTAssertEqual(graph.relationships.count, concurrent.relationships.count)
                
                // Verify the results against the serail decoding
                let vanilla = try JSONDecoder().decode(SymbolGraph.self, from: data)
                XCTAssertEqual(concurrent.symbols.count, vanilla.symbols.count)
                XCTAssertEqual(concurrent.relationships.count, vanilla.relationships.count)
            }
        }

        for _ in 0 ... 6 {
            // Keep adding more symbols to test various sizes up to 2K symbols
            addSymbols(count: 256, graph: &graph)
            
            do {
                let data = try JSONEncoder().encode(graph)
                
                // Verify the results when decoding concurrently
                let concurrent = try symbolGraphRoundtrip(from: data)
                XCTAssertEqual(graph.symbols.count, concurrent.symbols.count)
                XCTAssertEqual(graph.relationships.count, concurrent.relationships.count)
                
                // Verify the results against the serail decoding
                let vanilla = try JSONDecoder().decode(SymbolGraph.self, from: data)
                XCTAssertEqual(concurrent.symbols.count, vanilla.symbols.count)
                XCTAssertEqual(concurrent.relationships.count, vanilla.relationships.count)
            }
        }
        
        // Remove all symbols and relationships
        graph.symbols.removeAll()
        graph.relationships.removeAll()
        
        do {
            // Test symbol graphs with no symbols
            let data = try JSONEncoder().encode(graph)
            
            let concurrent = try symbolGraphRoundtrip(from: data)
            XCTAssertEqual(graph.symbols.count, concurrent.symbols.count)
            XCTAssertEqual(graph.relationships.count, concurrent.relationships.count)
            
            let vanilla = try JSONDecoder().decode(SymbolGraph.self, from: data)
            XCTAssertEqual(concurrent.symbols.count, vanilla.symbols.count)
            XCTAssertEqual(concurrent.relationships.count, vanilla.relationships.count)
        }
    }
    
    func testDecodingSymbolGraphWithNoSymbols() throws {
        // Load and decode a symbol graph with some symbols
        let topLevelCurationSGFURL = Bundle.module.url(
            forResource: "TopLevelCuration.symbols", withExtension: "json", subdirectory: "Test Resources")!
        
        // Verify the test symbol graph has symbols
        let graph = try JSONDecoder().decode(SymbolGraph.self, from: try Data(contentsOf: topLevelCurationSGFURL))
        XCTAssertFalse(graph.symbols.isEmpty)
        
        // Verify we don't load symbols when decoding `SymbolGraphWithoutSymbols`
        let graphNoSymbols = try JSONDecoder().decode(SymbolGraphConcurrentDecoder.SymbolGraphWithoutSymbols.self, from: try Data(contentsOf: topLevelCurationSGFURL))
        XCTAssertTrue(graphNoSymbols.symbolGraph.symbols.isEmpty)
    }
    
    /// Verifies that symbol batches decode only a part of all the graph symbols.
    func testDecodingBatches() throws {
        
        // Load and decode a symbol graph with some symbols
        let topLevelCurationSGFURL = Bundle.module.url(
            forResource: "TopLevelCuration.symbols", withExtension: "json", subdirectory: "Test Resources")!
        var graph = try JSONDecoder().decode(SymbolGraph.self, from: try Data(contentsOf: topLevelCurationSGFURL))
        
        for index in 0 ... 100 {
            let symbol = makeSymbol(index: index)
            graph.symbols[symbol.identifier.precise] = symbol
        }
        let data = try JSONEncoder().encode(graph)
        
        // Verify decoding for various batch counts
        for batchCount in 1 ... 8 {
            
            // Verify decoding for each batch
            for batchIndex in 0 ..< batchCount {
                let batchDecoder = JSONDecoder()
                
                // Configure the decoder to decode the current batch
                batchDecoder.userInfo[CodingUserInfoKey.symbolCounter] = SymbolGraphConcurrentDecoder.Counter()
                batchDecoder.userInfo[CodingUserInfoKey.batchIndex] = batchIndex
                batchDecoder.userInfo[CodingUserInfoKey.batchCount] = batchCount
                
                let batchSymbolCount = try batchDecoder.decode(SymbolGraphConcurrentDecoder.SymbolGraphBatch.self, from: data).symbols.count
                
                let expectedCount = Int((Double(graph.symbols.count) / Double(batchCount)).rounded())
                
                // Verify that the count of symbols in each batch is at most 1 more or less than the average.
                // I.e. some batches would usually have one more symbol, for example for a graph with
                // 101 symbols we will get the following 4 batches: 26, 25, 25, and 25.
                XCTAssertLessThanOrEqual(abs(expectedCount - batchSymbolCount), 1)
            }
        }
    }
    
    /// Unit tests 101
    func testCounter() {
        let counter = SymbolGraphConcurrentDecoder.Counter()
        for index in 0 ... 100 {
            XCTAssertEqual(counter.increment(), index)
        }
    }
    
    /// Test that the decoding counter is a class type
    /// so we can inject it into a JSONDecoder and mutate it
    func testCounterIsReferenceType() {
        let counter1 = SymbolGraphConcurrentDecoder.Counter()
        let counter2 = counter1
        
        XCTAssertEqual(counter1.increment(), 0)
        XCTAssertEqual(counter2.increment(), 1)
    }
}
