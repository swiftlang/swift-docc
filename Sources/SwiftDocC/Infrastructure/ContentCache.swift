/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension DocumentationContext {
    /// A cache for symbol and page content.
    struct ContentCache<Value> {
        private var storage = [ResolvedTopicReference: Value]()
        private var symbolIndex = [String: ResolvedTopicReference]()
        
        /// Accesses the value for a given reference.
        /// - Parameter reference: The reference to find in the cache.
        subscript(reference: ResolvedTopicReference) -> Value? {
            get { storage[reference] }
            set { storage[reference] = newValue }
        }
        
        /// Adds a value to the cache for a given reference _and_ symbol ID.
        /// - Parameters:
        ///   - value: The value to add to the cache.
        ///   - reference: The reference associated with that value.
        ///   - symbolID: The symbol ID associated with that value.
        mutating func add(value: Value, reference: ResolvedTopicReference, symbolID: String) {
            symbolIndex[symbolID] = reference
            storage[reference] = value
        }
        
        /// Accesses the reference for a given symbol ID.
        /// - Parameter symbolID: The symbol ID to find in the cache.
        func reference(symbolID: String) -> ResolvedTopicReference? {
            symbolIndex[symbolID]
        }
        
        /// Accesses the value for a given symbol ID.
        /// - Parameter symbolID: The symbol ID to find in the cache.
        subscript(symbolID: String) -> Value? {
            symbolIndex[symbolID].map { storage[$0]! }
        }
        
        /// Reserves enough space to store the specified number of values.
        mutating func reserveCapacity(_ minimumCapacity: Int, reserveSymbolIDCapacity: Bool) {
            storage.reserveCapacity(minimumCapacity)
            if reserveSymbolIDCapacity {
                symbolIndex.reserveCapacity(minimumCapacity)
            }
        }
        
        /// Returns a list of all the references in the cache.
        var references: [ResolvedTopicReference] {
            return Array(storage.keys)
        }
        
        /// Returns a list of all the references in the cache.
        var symbolReferences: [ResolvedTopicReference] {
            return Array(symbolIndex.values)
        }
    }
}

// Support iterating over the cached values.
extension DocumentationContext.ContentCache: Collection {
    typealias Wrapped = [ResolvedTopicReference: Value]
    typealias Index = Wrapped.Index
    typealias Element = Wrapped.Element
    
    func makeIterator() -> Wrapped.Iterator {
        storage.makeIterator()
    }
    
    var startIndex: Wrapped.Index {
        storage.startIndex
    }
    
    var endIndex: Wrapped.Index {
        storage.endIndex
    }
    
    func index(after i: Wrapped.Index) -> Wrapped.Index {
        storage.index(after: i)
    }
    
    subscript(position: Wrapped.Index) -> Wrapped.Element {
        _read { yield storage[position] }
    }
}
