/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A thread-safe cache for encoded render references.
public typealias RenderReferenceCache = Synchronized<[String: (reference: Data, overrides: [VariantOverride])]>

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
        encodeAccumulatedVariantOverrides: Bool = false,
        encoder: JSONEncoder,
        renderReferenceCache referenceCache: RenderReferenceCache
    ) throws {
        guard !references.isEmpty else { return }
        
        // Because we'll be clearing the encoder's variant overrides field before
        // encoding each reference, we need to store any existing values now so that
        // when we finally encode the variant overrides we have all relevant values.
        var variantOverrides = encoder.userInfoVariantOverrides?.values ?? []
        
        let fragments: Fragments = encoder.outputFormatting.contains(.prettyPrinted) ? .prettyPrinted : .compact
        
        // Remove the final "}"
        renderNodeData.removeLast()
        
        // Insert the "references" key
        renderNodeData.append(fragments.referencesKey)
        
        // The keys of the node render references
        var referenceIndexes = Array(references.keys)
        
        // Sort the keys if `.sortedKeys` is set on the encoder.
        if encoder.outputFormatting.contains(.sortedKeys) {
            referenceIndexes.sort()
        }
        
        // Insert the references
        for index in referenceIndexes {
            let reference = references[index]!
            let key = reference.identifier.identifier
            let value: Data
            
            // Declare a helper function that we'll use to encode any non-cached references
            // we encounter
            
            func encodeRenderReference(cacheKey: String? = nil) throws -> Data {
                // Because we're encoding these reference ad-hoc and not as part of a full render
                // node, the `encodingPath` on the encoder will be incorrect. This means that the
                // logic in `VariantEncoder.addVariantsToEncoder(_:pointer:isDefaultValueEncoded:)`
                // will incorrectly set the path and the produced JSON patch we use to switch
                // between language variants will be incorrect.
                //
                // To work around this, we set a `baseJSONPatchPath` property in the encoder's
                // user info dictionary. Then when `addVariantsToEncoder` is called, it prepends
                // this value to the coding path. This way the produced JSON patch will be accurate.
                encoder.baseJSONPatchPath = [
                    "references",
                    reference.identifier.identifier,
                ]
                
                // Because we want to cache each render reference with the specific
                // variant overrides it produces, we first clear the encoder's user info
                // fields before encoding.
                //
                // This ensures that the whatever override the user info field holds
                // _after_ we encode, are the ones for this particular reference.
                encoder.userInfoVariantOverrides?.values.removeAll()
                
                // Encode the reference.
                let encodedReference = try encoder.encode(CodableRenderReference.init(reference))
                
                // Add the collected variant overrides to the collection of overrides
                // we're currently tracking.
                if let encodedVariantOverrides = encoder.userInfoVariantOverrides {
                    variantOverrides.append(contentsOf: encodedVariantOverrides.values)
                }
                
                // If a cache key was provided, update the cache with the reference and it's
                // overrides.
                if let cacheKey = cacheKey {
                    referenceCache.sync { cache in
                        cache[cacheKey] = (
                            encodedReference,
                            encoder.userInfoVariantOverrides?.values ?? []
                        )
                    }
                }
                
                return encodedReference
            }
            
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
                    if let (reference, overrides) = referenceCache.sync({ $0[cacheKeyWithConformance] }) {
                        value = reference
                        variantOverrides.append(contentsOf: overrides)
                    } else {
                        value = try encodeRenderReference(cacheKey: cacheKeyWithConformance)
                    }
                    
                } else if let (reference, overrides) = referenceCache.sync({ $0[key] }) {
                    // Use a cached copy if the reference is already encoded.
                    value = reference
                    variantOverrides.append(contentsOf: overrides)
                } else {
                    value = try encodeRenderReference(cacheKey: key)
                }
            }
            else {
                // Non topic reference, always encode.
                // We encode those every time because those references aren't guaranteed to have unique identifiers.
                // For example: ![image.png](This is an image) and ![image.png](Another image)
                // have the same identifier when encoded in the render node where they are used but the reference
                // abstract is not unique within the project.
                value = try encodeRenderReference()
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
        
        // Append closing "}"
        renderNodeData.append(fragments.closingBrace)
        
        if encodeAccumulatedVariantOverrides, !variantOverrides.isEmpty {
            // Insert the "variantOverrides" key
            renderNodeData.append(fragments.variantOverridesKey)
            let variantOverrideData = try encoder.encode(VariantOverrides(values: variantOverrides))
            renderNodeData.append(variantOverrideData)
        }
        
        // Append closing "}"
        renderNodeData.append(fragments.closingBrace)
    }

    /// Data fragments to use to build a reference list.
    private struct Fragments {
        
        let variantOverridesKey: Data
        let referencesKey: Data
        let closingBrace: Data
        let listDelimiter: Data
        let quote: Data
        let colon: Data
        
        // Compact fragments
        static let compact = Fragments(
            variantOverridesKey: Data(",\"variantOverrides\":".utf8),
            referencesKey: Data(",\"references\":{".utf8),
            closingBrace: Data("}".utf8),
            listDelimiter: Data(",".utf8),
            quote: Data("\"".utf8),
            colon: Data(":".utf8)
        )
        
        // Pretty printed fragments
        static let prettyPrinted = Fragments(
            variantOverridesKey: Data(", \n\"variantOverrides\":".utf8),
            referencesKey: Data(", \n\"references\": {\n".utf8),
            closingBrace: Data("\n}".utf8),
            listDelimiter: Data(",\n".utf8),
            quote: Data("\"".utf8),
            colon: Data(": ".utf8)
        )
    }
}
