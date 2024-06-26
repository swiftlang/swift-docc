/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension DocumentationContext {
    /// A cache for symbol and page content.
    ///
    /// The context uses this cache type with different values for both local content (``DocumentationContext/LocalCache``) and external content (``DocumentationContext/ExternalCache``).
    ///
    /// > Note:
    /// > The cache is not thread-safe. It's safe to read from the cache concurrently but writing needs to happen with exclusive access. It is the callers responsibility to synchronize write access.
    struct ContentCache<Value> {
        /// The main storage of cached values.
        private(set) var valuesByReference = [ResolvedTopicReference: Value]()
        /// A supplementary lookup of references by their symbol ID.
        ///
        /// If a reference is found, ``valuesByReference``  will also have a value for that reference because ``add(_:reference:symbolID:)`` is the only place that writes to this lookup and it always adds the reference-value pair to ``valuesByReference``.
        private(set) var referencesBySymbolID = [String: ResolvedTopicReference]()
        
        /// Accesses the value for a given reference.
        /// - Parameter reference: The reference to find in the cache.
        subscript(reference: ResolvedTopicReference) -> Value? {
            // Avoid copying the values if possible
            _read { yield valuesByReference[reference] }
            _modify { yield &valuesByReference[reference] }
        }
        
        /// Adds a value to the cache for a given reference _and_ symbol ID.
        /// - Parameters:
        ///   - value: The value to add to the cache.
        ///   - reference: The reference associated with that value.
        ///   - symbolID: The symbol ID associated with that value.
        mutating func add(_ value: Value, reference: ResolvedTopicReference, symbolID: String) {
            referencesBySymbolID[symbolID] = reference
            valuesByReference[reference] = value
        }
        
        /// Accesses the reference for a given symbol ID.
        /// - Parameter symbolID: The symbol ID to find in the cache.
        func reference(symbolID: String) -> ResolvedTopicReference? {
            referencesBySymbolID[symbolID]
        }
        
        /// Accesses the value for a given symbol ID.
        /// - Parameter symbolID: The symbol ID to find in the cache.
        subscript(symbolID: String) -> Value? {
            // Avoid copying the values if possible
            _read { yield referencesBySymbolID[symbolID].map { valuesByReference[$0]! } }
        }
        
        /// Reserves enough space to store the specified number of values and symbol IDs.
        ///
        /// If you are adding a known number of values pairs to a cache, use this method to avoid multiple reallocations.
        ///
        /// > Note: The cache reserves the specified capacity for both values and symbol IDs.
        ///
        /// - Parameter minimumCapacity: The requested number of key-value pairs to store.
        mutating func reserveCapacity(_ minimumCapacity: Int) {
            valuesByReference.reserveCapacity(minimumCapacity)
            // The only place that currently calls expects reserve the same capacity for both stored properties.
            // This is because symbols are 
            referencesBySymbolID.reserveCapacity(minimumCapacity)
        }
        
        /// Returns a list of all the references in the cache.
        var allReferences: some Collection<ResolvedTopicReference> {
            return valuesByReference.keys
        }
        
        /// Returns a list of all the references in the cache.
        var symbolReferences: some Collection<ResolvedTopicReference> {
            return referencesBySymbolID.values
        }
    }
}

// Support iterating over the cached values, checking the number of cached values, and other collection operations.
extension DocumentationContext.ContentCache: Collection {
    typealias Wrapped = [ResolvedTopicReference: Value]
    typealias Index = Wrapped.Index
    typealias Element = Wrapped.Element
    
    func makeIterator() -> Wrapped.Iterator {
        valuesByReference.makeIterator()
    }
    
    var startIndex: Wrapped.Index {
        valuesByReference.startIndex
    }
    
    var endIndex: Wrapped.Index {
        valuesByReference.endIndex
    }
    
    func index(after i: Wrapped.Index) -> Wrapped.Index {
        valuesByReference.index(after: i)
    }
    
    subscript(position: Wrapped.Index) -> Wrapped.Element {
        _read { yield valuesByReference[position] }
    }
}
