/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

enum TopicRenderReferenceEncoder {
    /// Inserts an encoded list of render references to an already encoded as data render node.
    /// - Parameters:
    ///   - renderNodeData: A render node encoded as JSON data.
    ///   - references: A list of render references.
    ///   - encoder: A `JSONEncoder` to use for the encoding.
    ///   - renderReferenceCache: A cache for encoded render reference data. When encoding a large number of render nodes, use the same cache
    ///   instance to avoid encoding the same reference objects repeatedly.
    static func addRenderReferences(
        to renderNodeData: inout Data,
        references: [String: RenderReference],
        encoder: JSONEncoder,
        renderReferenceCache referenceCache: Synchronized<[String: Data]>
    ) {
        
        guard !references.isEmpty else { return }
        
        let fragments: Fragments = encoder.outputFormatting.contains(.prettyPrinted) ? .prettyPrinted : .compact
        
        // Remove the final "}"
        renderNodeData.removeLast()
        
        // Insert the "references" key
        renderNodeData.append(fragments.referencesKey)
        
        // The keys of the node render references
        var referenceIndexes = Array(references.keys)
        
        // Sort the render references so that RenderJSON output is stable and deterministic
        referenceIndexes.sort()
        
        // Insert the references
        for index in referenceIndexes {
            let reference = references[index]!
            let key = reference.identifier.identifier
            let value: Data
            
            if let topicReference = reference as? TopicRenderReference {
                if let conformance = topicReference.conformance {
                    // In case there is a conformance section, adds conformance hash to the cache key.
                    // In case the reference is once used without conformances and another time with,
                    // the two cache keys are:
                    // 1. "doc://bundleID/documentation/MyClass"
                    // 2. "doc://bundleID/documentation/MyClass : aab43583ccd3b5"
                    // so that there are no cache collisions.
                    
                    let conformanceHash = Checksum.md5(of: Data(conformance.constraints.map({ $0.plainText }).joined().utf8))
                    let cacheKeyWithConformance = "\(key) : \(conformanceHash)"
                    if let cached = referenceCache.sync({ $0[cacheKeyWithConformance] }) {
                        value = cached
                    } else {
                        value = try! encoder.encode(CodableRenderReference.init(reference))
                        referenceCache.sync({ $0[cacheKeyWithConformance] = value })
                    }
                    
                } else if let cached = referenceCache.sync({ $0[key] }) {
                    // Use a cached copy if the reference is already encoded.
                    value = cached
                } else {
                    // Encode the reference and add it to the cache.
                    value = try! encoder.encode(CodableRenderReference.init(reference))
                    referenceCache.sync({ $0[key] = value })
                }
            }
            else {
                // Non topic reference, always encode.
                // We encode those every time because those references aren't guaranteed to have unique identifiers.
                // For example: ![image.png](This is an image) and ![image.png](Another image)
                // have the same identifier when encoded in the render node where they are used but the reference
                // abstract is not unique within the project.
                value = try! encoder.encode(CodableRenderReference.init(reference))
            }
            
            renderNodeData.append(fragments.quote)
            renderNodeData.append(Data(key.utf8))
            renderNodeData.append(fragments.quote)
            renderNodeData.append(fragments.colon)
            renderNodeData.append(value)
            renderNodeData.append(fragments.listDelimiter)
        }
        
        // Remove the last comma from the list
        renderNodeData.removeLast(fragments.listDelimiter.count)
        
        // Append closing "}}"
        renderNodeData.append(fragments.closingBrackets)
    }

    /// Data fragments to use to build a reference list.
    private struct Fragments {
        
        let referencesKey: Data
        let closingBrackets: Data
        let listDelimiter: Data
        let quote: Data
        let colon: Data
        
        // Compact fragments
        static let compact = Fragments(
            referencesKey: Data(",\"references\":{".utf8),
            closingBrackets: Data("}}".utf8),
            listDelimiter: Data(",".utf8),
            quote: Data("\"".utf8),
            colon: Data(":".utf8)
        )
        
        // Pretty printed fragments
        static let prettyPrinted = Fragments(
            referencesKey: Data(", \n\"references\": {\n".utf8),
            closingBrackets: Data("\n}\n}".utf8),
            listDelimiter: Data(",\n".utf8),
            quote: Data("\"".utf8),
            colon: Data(": ".utf8)
        )
    }
}
