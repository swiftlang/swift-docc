/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

class RenderNodeCodableTests: XCTestCase {
    
    var bareRenderNode = RenderNode(
        identifier: .init(bundleIdentifier: "com.bundle", path: "/", sourceLanguage: .swift),
        kind: .article
    )
    
    var testVariantOverride = VariantOverride(
        traits: [.interfaceLanguage("objc")],
        patch: [
            .replace(pointer: JSONPointer(pathComponents: ["foo"]), encodableValue: "bar"),
        ]
    )
    
    func testDataCorrupted() {
        XCTAssertThrowsError(try RenderNode.decode(fromJSON: corruptedJSON), "RenderNode decode didn't throw as expected.") { error in
            XCTAssertTrue(error is RenderNode.CodingError)
            let description = error.localizedDescription
            XCTAssertTrue(description.contains("The given data was not valid JSON."))
        }
    }
    
    func testMissingKeyError() {
        do {
            let renderNode = try RenderNode.decode(fromJSON: emptyJSON)
            XCTAssertNotNil(renderNode)
        } catch {
            XCTAssertTrue(error is RenderNode.CodingError, "Error thrown is not a coding error")
            let description = error.localizedDescription
            XCTAssertTrue(description.contains("No value associated with key"), "Incorrect error message")
            // Ensure the information about the missing key is there.
            XCTAssertTrue(description.contains("schemaVersion"), "Missing key name in error description")
        }
    }
    
    func testTypeMismatchError() {
        do {
            let renderNode = try RenderNode.decode(fromJSON: typeMismatch)
            XCTAssertNotNil(renderNode)
        } catch {
            XCTAssertTrue(error is RenderNode.CodingError)
            let description = error.localizedDescription
            XCTAssertTrue(
                // Leave out the end of the message to account for slight differences between platforms.
                description.contains("Expected to decode Int")
            )
            // Ensure the information about the mismatch key is there.
            XCTAssertTrue(description.contains("schemaVersion"))
        }
    }
    
    func testPrettyPrintByDefaultOff() {
        let renderNode = bareRenderNode
        do {
            let encodedData = try renderNode.encodeToJSON()
            let jsonString = String(data: encodedData, encoding: .utf8)!
            XCTAssertFalse(jsonString.contains("\r\n"))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testPrettyPrintedEncoder() {
        let renderNode = bareRenderNode
        do {
            // No pretty print
            let encoder = RenderJSONEncoder.makeEncoder(prettyPrint: false)
            let encodedData = try renderNode.encodeToJSON(with: encoder)
            let jsonString = String(data: encodedData, encoding: .utf8)!
            XCTAssertFalse(jsonString.contains("\n  "))
        } catch {
            XCTFail(error.localizedDescription)
        }
        do {
            // Yes pretty print
            let encoder = RenderJSONEncoder.makeEncoder(prettyPrint: true)
            let encodedData = try renderNode.encodeToJSON(with: encoder)
            let jsonString = String(data: encodedData, encoding: .utf8)!
            XCTAssertTrue(jsonString.contains("\n  "))
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testSortedKeys() throws {
        guard #available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) else {
            throw XCTSkip("Skipped on platforms that don't support JSONEncoder.OutputFormatting.sortedKeys")
        }

        // When prettyPrint is enabled, keys are sorted
        let encoderPretty = RenderJSONEncoder.makeEncoder(prettyPrint: true)
        XCTAssertTrue(encoderPretty.outputFormatting.contains(.sortedKeys))

        // When prettyPrint is disabled, keys are not sorted
        let encoderNotPretty = RenderJSONEncoder.makeEncoder(prettyPrint: false)
        XCTAssertFalse(encoderNotPretty.outputFormatting.contains(.sortedKeys))
    }

    func testEncodesVariantOverridesSetAsProperty() throws {
        var renderNode = bareRenderNode
        renderNode.variantOverrides = VariantOverrides(values: [testVariantOverride])
        
        let decodedNode = try encodeAndDecode(renderNode)
        try assertVariantOverrides(XCTUnwrap(decodedNode.variantOverrides))
    }
    
    func testEncodesVariantOverridesAccumulatedInEncoder() throws {
        let encoder = RenderJSONEncoder.makeEncoder()
        (encoder.userInfo[.variantOverrides] as! VariantOverrides).add(testVariantOverride)
        
        let decodedNode = try encodeAndDecode(bareRenderNode, encoder: encoder)
        try assertVariantOverrides(XCTUnwrap(decodedNode.variantOverrides))
    }
    
    func testDoesNotEncodeVariantOverridesIfEmpty() throws {
        let encoder = RenderJSONEncoder.makeEncoder()
        
        // Don't record any overrides.
        
        let decodedNode = try encodeAndDecode(bareRenderNode, encoder: encoder)
        XCTAssertNil(decodedNode.variantOverrides)
    }
    
    func testDecodingRenderNodeDoesNotCacheReferences() throws {
        let exampleRenderNodeJSON = Bundle.module.url(
            forResource: "Operator",
            withExtension: "json",
            subdirectory: "Test Resources"
        )!
        
        let uniqueBundleIdentifier = #function
        
        let renderNodeWithUniqueBundleID = try String(
            contentsOf: exampleRenderNodeJSON
        )
        .replacingOccurrences(
            of: "org.swift.docc.example",
            with: uniqueBundleIdentifier
        )
        
        _ = try JSONDecoder().decode(RenderNode.self, from: Data(renderNodeWithUniqueBundleID.utf8))
        
        ResolvedTopicReference.sharedPool.sync { sharedPool in
            XCTAssertNil(sharedPool[uniqueBundleIdentifier])
        }
    }
    
    func testDecodeRenderNodeWithoutTopicSectionStyle() throws {
        let exampleRenderNodeJSON = Bundle.module.url(
            forResource: "Operator",
            withExtension: "json",
            subdirectory: "Test Resources"
        )!
        
        let renderNodeData = try Data(contentsOf: exampleRenderNodeJSON)
        
        let renderNode = try JSONDecoder().decode(RenderNode.self, from: renderNodeData)
        XCTAssertEqual(renderNode.topicSectionsStyle, .list)
    }
    
    func testEncodeRenderNodeWithCustomTopicSectionStyle() throws {
        let (bundle, context) = try testBundleAndContext()
        var problems = [Problem]()
        
        let source = """
            # My Great Article
            
            A great article.
            
            @Options {
                @TopicsVisualStyle(compactGrid)
            }
            """
        
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let article = try XCTUnwrap(
            Article(from: document.root, source: nil, for: bundle, in: context, problems: &problems)
        )
        
        let reference = ResolvedTopicReference(
            bundleIdentifier: "org.swift.docc.example",
            path: "/documentation/test/customTopicSectionStyle",
            fragment: nil,
            sourceLanguage: .swift
        )
        context.documentationCache[reference] = try DocumentationNode(reference: reference, article: article)
        let topicGraphNode = TopicGraph.Node(
            reference: reference,
            kind: .article,
            source: .file(url: URL(fileURLWithPath: "/path/to/article.md")),
            title: "My Article"
        )
        context.topicGraph.addNode(topicGraphNode)
        
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: reference,
            source: nil
        )
        let node = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        XCTAssertEqual(node.topicSectionsStyle, .compactGrid)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let encodedNode = try encoder.encode(node)
        let decodedNode = try decoder.decode(RenderNode.self, from: encodedNode)
        XCTAssertEqual(decodedNode.topicSectionsStyle, .compactGrid)
    }
    
    private func assertVariantOverrides(_ variantOverrides: VariantOverrides) throws {
        XCTAssertEqual(variantOverrides.values.count, 1)
        let variantOverride = try XCTUnwrap(variantOverrides.values.first)
        XCTAssertEqual(variantOverride.traits, testVariantOverride.traits)
        
        XCTAssertEqual(variantOverride.patch.count, 1)
        let operation = try XCTUnwrap(variantOverride.patch.first)
        XCTAssertEqual(operation.operation, testVariantOverride.patch[0].operation)
        XCTAssertEqual(operation.pointer.pathComponents, testVariantOverride.patch[0].pointer.pathComponents)
    }
    
    private func encodeAndDecode<Value: Codable>(_ value: Value, encoder: JSONEncoder = .init()) throws -> Value {
        try JSONDecoder().decode(Value.self, from: encoder.encode(value))
    }
}

fileprivate let corruptedJSON = Data("{{}".utf8)
fileprivate let emptyJSON = Data("{}".utf8)
fileprivate let typeMismatch = Data("""
{"schemaVersion":{"major":"type mismatch","minor":0,"patch":0}}
""".utf8)
