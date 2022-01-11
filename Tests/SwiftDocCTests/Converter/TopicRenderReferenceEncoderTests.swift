/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class TopicRenderReferenceEncoderTests: XCTestCase {

    func testRenderNodeSkipsReferences() throws {
        var node = RenderNode(identifier: .init(bundleIdentifier: "bundle", path: "/documentation/MyClass", sourceLanguage: .swift), kind: .article)
        node.references = [
            "reference1": TopicRenderReference(identifier: .init("reference1"), title: "myFunction", abstract: [], url: "/documentation/MyClass/myFunction", kind: .symbol, estimatedTime: nil),
        ]
        
        // Verify encoding references
        do {
            let encoderWithReferences = JSONEncoder()
            let data = try encoderWithReferences.encode(node)
            guard let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                XCTFail("Failed to decode render node back.")
                return
            }
            
            // Verify that references have been encoded
            let references = dictionary["references"] as? [String: Any]
            XCTAssertNotNil(references)
        }

        // Verify encoding without references
        do {
            let encoderWithoutReferences = JSONEncoder()
            encoderWithoutReferences.userInfo[.skipsEncodingReferences] = true

            let data = try encoderWithoutReferences.encode(node)
            guard let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                XCTFail("Failed to decode render node back.")
                return
            }
            
            // Verify that the references key does not exist
            XCTAssertNil(dictionary["references"])
        }
    }
    
    func testTopicReferenceEncoder() throws {
        // Create a render node
        var node = RenderNode(identifier: .init(bundleIdentifier: "bundle", path: "/documentation/MyClass", sourceLanguage: .swift), kind: .article)
        node.references = [
            "reference1": TopicRenderReference(identifier: .init("reference1"), title: "myFunction", abstract: [], url: "/documentation/MyClass/myFunction", kind: .symbol, estimatedTime: nil),
        ]

        let encoder = RenderJSONEncoder.makeEncoder()
        let cache = RenderReferenceCache([:])
        var data = try node.encodeToJSON(with: encoder, renderReferenceCache: cache)
        
        // Insert the references in the node
        try TopicRenderReferenceEncoder.addRenderReferences(to: &data,
            references: node.references,
            encoder: encoder,
            renderReferenceCache: cache
        )
        
        // Verify the inserted reference
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let references = dictionary["references"] as? [String: [String: Any]],
            let reference = references["reference1"] else {
            XCTFail("Couldn't decode the render node back.")
            return
        }
        
        // Verify that the correct title was encoded
        XCTAssertEqual(reference["title"] as? String, "myFunction")
        
        // Verify the encoded reference was stored in the cache
        XCTAssertNotNil(cache.sync({ $0["reference1"] }))
        
        // Now change the cached reference
        let newReference = TopicRenderReference(identifier: .init("reference1"), title: "NEW TITLE", abstract: [], url: "/documentation/MyClass/myFunction", kind: .symbol, estimatedTime: nil)
        try cache.sync({
            $0["reference1"] = (try encoder.encode(newReference), [])
        })
        
        // Encode again, using the stubbed cache
        var newData = try node.encodeToJSON(with: encoder, renderReferenceCache: cache)
        try TopicRenderReferenceEncoder.addRenderReferences(to: &newData,
            references: node.references,
            encoder: encoder,
            renderReferenceCache: cache
        )
        
        // Verify the inserted reference
        guard let newDictionary = try JSONSerialization.jsonObject(with: newData, options: []) as? [String: Any],
            let newReferences = newDictionary["references"] as? [String: [String: Any]],
            let newRenderReference = newReferences["reference1"] else {
            XCTFail("Couldn't decode the render node back.")
            return
        }
        
        // Verify that the cached title is used and NOT the real title from the given references list.
        XCTAssertEqual(newRenderReference["title"] as? String, "NEW TITLE")
    }
    
    // This test has been disabled because of failures in Swift CI.
    // rdar://85428149 tracks updating this test to remove any flakiness.
    //
    // Encodes concurrently 1000 nodes with 1000 references each.
    func skip_testTopicReferenceEncodingWithHighConcurrency() throws {
        // Create many references
        let references = (0..<1000)
            .map({ i in
                TopicRenderReference(identifier: .init("reference\(i)"), title: "myFunction", abstract: [], url: "/documentation/MyClass/myFunction", kind: .symbol, estimatedTime: nil)
            })
            .reduce(into: [String: RenderReference]()) { result, reference in
                result[reference.identifier.identifier] = reference
            }
        
        // Create many render nodes.
        let nodes = (0..<1000)
            .map({ i -> RenderNode in
                var node = RenderNode(identifier: .init(bundleIdentifier: "bundle", path: "/documentation/MyClass\(i)", sourceLanguage: .swift), kind: .article)
                node.references = references
                return node
            })

        let cache = RenderReferenceCache([:])
        let encodingErrors = Synchronized<[Error]>([])
        
        DispatchQueue.concurrentPerform(iterations: nodes.count) { i in
            do {
                let encoder = RenderJSONEncoder.makeEncoder()
                var data = try nodes[i].encodeToJSON(with: encoder, renderReferenceCache: cache)
                
                // Insert the references in the node
                try TopicRenderReferenceEncoder.addRenderReferences(to: &data,
                    references: nodes[i].references,
                    encoder: encoder,
                    renderReferenceCache: cache
                )
            } catch {
                encodingErrors.sync({ $0.append(error) })
            }
        }
        
        // Pipe through encoding errors.
        encodingErrors.sync({ $0.forEach({ XCTFail(String(describing: $0)) }) })
        
        // Verify all references have been cached
        XCTAssertEqual(cache.sync({ $0.keys.count }), 1000)
    }
    
    /// Verifies that when JSON encoder should sort keys, the custom render reference cache
    /// respects that setting and prints the referencs in alphabetical order.
    func testSortedReferences() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)

        // Create a JSON encoder
        let encoder = RenderJSONEncoder.makeEncoder()
        encoder.outputFormatting = .sortedKeys
        
        let cache = RenderReferenceCache([:])

        // For reach topic encode its render node and verify the references are in alphabetical order.
        for reference in context.knownPages {
            let node = try context.entity(with: reference)
            let renderNode = try converter.convert(node, at: nil)
            
            // Get the encoded JSON as string
            let encodedData = try renderNode.encodeToJSON(with: encoder, renderReferenceCache: cache)
            let encodedString = try XCTUnwrap(String(data: encodedData, encoding: .utf8))

            // Get the references as a string
            let referencesIndex = encodedString.range(of: "\"references\":")!.lowerBound
            var referencesString = String(encodedString[referencesIndex...].dropFirst("\"references\":".count))

            // Walk the string and collect the reference identifiers in the order they are encountered
            var isAtEnd = false
            var identifiers = [String]()

            while !isAtEnd {
                // Match "identifier"
                do {
                    let result = referencesString.splitAt("\"identifier\":")
                    guard result.1 != nil else { isAtEnd = true; continue }
                    referencesString = result.0
                }
                
                // Match "
                do {
                    let result = referencesString.splitAt("\"")
                    guard result.1 != nil else { isAtEnd = true; continue }
                    referencesString = result.0
                }
                
                // Match the identifier up to next "
                do {
                    let result = referencesString.splitAt("\"")
                    guard let match = result.1 else { isAtEnd = true; continue }
                    referencesString = result.0
                    identifiers.append(match)
                }
            }
            
            // Verify we collected ALL references
            XCTAssertEqual(renderNode.references.keys.count, identifiers.count)
            
            // Verify the collected references are in alphabetical order
            XCTAssertEqual(identifiers, identifiers.sorted())
        }
    }
    
    // Verifies that there is no extra comma at the end of the references list.
    func testRemovesLastReferencesListDelimiter() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)

        // Create a JSON encoder
        let encoder = RenderJSONEncoder.makeEncoder()
        encoder.outputFormatting = .sortedKeys

        // For reach topic encode its render node and verify the references are in alphabetical order.
        for reference in context.knownPages {
            let node = try context.entity(with: reference)
            let renderNode = try converter.convert(node, at: nil)
            
            // Get the encoded JSON as string
            let encodedData = try renderNode.encodeToJSON(with: encoder)
            let encodedString = try XCTUnwrap(String(data: encodedData, encoding: .utf8))
                .components(separatedBy: .whitespacesAndNewlines).filter({ !$0.isEmpty }).joined()
            
            // Verify there is no coma at the end of the references list
            XCTAssertNil(encodedString.range(of: "},}"))
        }
    }
}

fileprivate extension String {
    /// Splits the string at the given search string.
    func splitAt(_ string: String) -> (String, String?) {
        guard let matchRange = range(of: string) else { return (self, nil) }
        return (String(self[matchRange.upperBound...]), String(self[startIndex..<self.index(before: matchRange.upperBound)]))
    }
}

