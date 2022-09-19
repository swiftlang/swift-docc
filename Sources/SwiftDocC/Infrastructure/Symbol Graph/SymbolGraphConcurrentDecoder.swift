/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

public extension CodingUserInfoKey {
    /// A user info key to store a symbol counter in the decoder.
    static let symbolCounter = CodingUserInfoKey(rawValue: "symbolCounter")!

    /// A user info key to store the current batch index.
    static let batchIndex = CodingUserInfoKey(rawValue: "symbolScaffolding")!
    
    /// A user info key to store the total amount of concurrent batches.
    static let batchCount = CodingUserInfoKey(rawValue: "symbolBatches")!
}

/// A concurrent symbol graph JSON decoder.
enum SymbolGraphConcurrentDecoder {
    
    /// Decodes the given data into a symbol graph concurrently.
    /// - Parameters:
    ///   - data: JSON data to decode.
    ///   - concurrentBatches: The number of batches to decode concurrently.
    /// - Returns: The decoded symbol graph.
    ///
    /// This method spawns multiple concurrent decoder workers that work with the same symbol graph data.
    /// As symbols make up for the most of the data in the symbol graph each of the
    /// concurrent workers decodes just a piece of the complete symbol list.
    ///
    /// ## Implementation
    ///
    /// Each worker with an index `N` out of all the workers decodes every `N`th symbol in the symbol graph.
    /// If you have 4 workers, the 1st worker decodes symbols with indexes `[0, 4, 8, 12, ...]`, the 2nd
    /// worker decodes symbols `[1, 5, 9, 13, ...]`, and so forth.
    ///
    /// ```
    /// Thread [N=1]  S - - - S - - - S - - - S - - - >
    /// Thread [N=2]  - S - - - S - - - S - - - S - - >
    /// Thread [N=3]  - - S - - - S - - - S - - - S - >
    /// Thread [N=4]  - - - S - - - S - - - S - - - S >
    /// ```
    ///
    /// Once a worker has finished walking all symbols and decoding the ones in its batch, it adds the symbols
    /// to the decoded symbol graph's symbols eventually adding up to all the symbols in the graph.
    /// > Note: Since each worker needs to walk over all symbols that are contained in the symbol graph,
    /// it made sense to spread the work equally (in other words to decode each N-th symbol per worker)
    /// so that we can get the best performance out of the concurrent work.
    
    static func decode(_ data: Data, concurrentBatches: Int = 4, using decoder: JSONDecoder = JSONDecoder()) throws -> SymbolGraph {
        
        
        var symbolGraph: SymbolGraph!

        let decodeError = Synchronized<Error?>(nil)
        let symbols = Synchronized<[String: SymbolGraph.Symbol]>([:])

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.swift.SymbolGraphConcurrentDecoder", qos: .unspecified, attributes: .concurrent)
        
        // Concurrently decode metadata and relationships.
        group.async(queue: queue) {
            do {
                // Decode the symbol graph bar the symbol list.
                symbolGraph = try JSONDecoder(like: decoder).decode(SymbolGraphWithoutSymbols.self, from: data).symbolGraph
            } catch {
                decodeError.sync({ $0 = error })
            }
        }
        
        // Concurrently decode each batch of symbols in the graph.
        (0..<concurrentBatches).concurrentPerform { batchIndex in
            let batchDecoder = JSONDecoder(like: decoder)
            
            // Configure the decoder to decode the current batch
            batchDecoder.userInfo[CodingUserInfoKey.symbolCounter] = Counter()
            batchDecoder.userInfo[CodingUserInfoKey.batchIndex] = batchIndex
            batchDecoder.userInfo[CodingUserInfoKey.batchCount] = concurrentBatches
            
            // Decode and add the symbols batch to `batches`.
            do {
                let batch = try batchDecoder.decode(SymbolGraphBatch.self, from: data)
                symbols.sync({
                    for symbol in batch.symbols {
                        if let existing = $0[symbol.identifier.precise] {
                            $0[symbol.identifier.precise] = SymbolGraph._symbolToKeepInCaseOfPreciseIdentifierConflict(existing, symbol)
                        } else {
                            $0[symbol.identifier.precise] = symbol
                        }
                    }
                })
            } catch {
                decodeError.sync({ $0 = error })
            }
        }
        
        // Wait until all concurrent tasks have completed.
        group.wait()
        
        // If an error happend during decoding re-throw.
        if let lastError = decodeError.sync({ $0 }) {
            throw lastError
        }

        symbolGraph.symbols = symbols.sync({ $0 })
        return symbolGraph
    }
    
    /// A wrapper type that decodes everything in the symbol graph but the symbols list.
    struct SymbolGraphWithoutSymbols: Decodable {
        /// The decoded symbol graph.
        let symbolGraph: SymbolGraph
        
        typealias CodingKeys = SymbolGraph.CodingKeys

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let metadata = try container.decode(SymbolGraph.Metadata.self, forKey: .metadata)
            let module = try container.decode(SymbolGraph.Module.self, forKey: .module)
            let relationships = try container.decode([SymbolGraph.Relationship].self, forKey: .relationships)
            self.symbolGraph = SymbolGraph(metadata: metadata, module: module, symbols: [], relationships: relationships)
        }
    }
    
    /// A wrapper type that decodes only a batch of symbols out of a symbol graph.
    struct SymbolGraphBatch: Decodable {
        /// A list of decoded symbols.
        let symbols: [SymbolGraph.Symbol]

        typealias CodingKeys = SymbolGraph.CodingKeys

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            symbols = try container.decode([OptionalBatchSymbol].self, forKey: .symbols)
                // Remove the skipped optional symbols that don't belong to the batch
                .compactMap(\.symbol)
        }
    }
    
    /// A wrapper type that decodes a symbol only if it belongs to the batch configured
    /// in the given decoder.
    struct OptionalBatchSymbol: Decodable {
        /// The decoded symbol. `nil` if the symbol didn't belong the correct batch.
        private(set) var symbol: SymbolGraph.Symbol?

        /// Creates a new instance by decoding from the given decoder.
        ///
        /// > Warning: Crashes when decoding using a decoder that is not correctly
        /// configured for concurrent decoding.
        public init(from decoder: Decoder) throws {
            let check = decoder.userInfo[CodingUserInfoKey.batchIndex] as! Int
            let count = (decoder.userInfo[CodingUserInfoKey.symbolCounter] as! Counter).increment()
            let batches = decoder.userInfo[CodingUserInfoKey.batchCount] as! Int
            
            /// Don't decode if this symbol doesn't belong to the current batch.
            guard count % batches == check else { return }
            
            /// Decode the symbol as usual.
            symbol = try SymbolGraph.Symbol(from: decoder)
        }
    }
    
    /// An auto-increment counter.
    class Counter {
        /// The current value of the counter.
        private var count = 0
        
        /// Get the current value and increment.
        func increment() -> Int {
            defer { count += 1}
            return count
        }
    }
}

private extension JSONDecoder {
    /// Creates a new decoder with the same configuration as the
    /// old one.
    convenience init(like old: JSONDecoder) {
        self.init()
        
        self.userInfo = old.userInfo
        self.dataDecodingStrategy = old.dataDecodingStrategy
        self.dateDecodingStrategy = old.dateDecodingStrategy
        self.keyDecodingStrategy = old.keyDecodingStrategy
        self.nonConformingFloatDecodingStrategy = old.nonConformingFloatDecodingStrategy
    }
}
