/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown
import DocCCommon

class RenderNodeCodableTests: XCTestCase {
    
    var bareRenderNode = RenderNode(
        identifier: .init(bundleID: "com.bundle", path: "/", sourceLanguage: .swift),
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
    func testMissingReferenceKey() throws {
        let renderNode = try! RenderNode.decode(fromJSON: missingReferenceKeyJSON)
        XCTAssertNotNil(renderNode)
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
        // When prettyPrint is enabled, keys are sorted
        let encoderPretty = RenderJSONEncoder.makeEncoder(prettyPrint: true)
        XCTAssertTrue(encoderPretty.outputFormatting.contains(.sortedKeys))

        // When prettyPrint is disabled, keys are still sorted
        let encoderNotPretty = RenderJSONEncoder.makeEncoder(prettyPrint: false)
        XCTAssertTrue(encoderNotPretty.outputFormatting.contains(.sortedKeys))
    }

    func testDecodingVariantOverrides() throws {
        let (_, bundle, context) = try testBundleAndContext(named: "GeometricalShapes")
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/GeometricalShapes/Circle/isEmpty", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let renderNode = try converter.convert(node, at: nil)
        
        let encoder = RenderJSONEncoder.makeEncoder(prettyPrint: true)
        let encoded = try encoder.encode(renderNode)
        
        if let overrides = encoder.userInfoVariantOverrides {
            print(try String(data: encoder.encode(overrides), encoding: .utf8) ?? "<non UTF8 data>")
        }
        let decoded = try RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: encoded)
        
        // Because of the odd way that `RenderNodeTranslator` creates variant collections with empty sections and
        // how `KeyedEncodingContainer.encodeVariantCollectionIfNotEmpty(_:forKey:encoder:)` replaces empty 'replace' with an empty 'add',
        // The 'topicSectionsVariants', 'relationshipSectionsVariants', and 'seeAlsoSectionsVariants' don't decode the same as the original value.
        // FIXME: (rdar://128393653)
        func assertSimilarVariants<Value: Equatable>(original: VariantCollection<[Value]>, decoded: VariantCollection<[Value]>, file: StaticString = #file, line: UInt = #line) {
            XCTAssertEqual(original.defaultValue, decoded.defaultValue, "Same default value", file: file, line: line)
            XCTAssertEqual(original.variants.count, decoded.variants.count, "Same number of variants", file: file, line: line)
            for (lhs, rhs) in zip(original.variants, decoded.variants) {
                XCTAssertEqual(lhs.traits, rhs.traits, file: file, line: line)
                XCTAssertEqual(lhs.patch.count, rhs.patch.count, file: file, line: line)
                for (lhs, rhs) in zip(lhs.patch, rhs.patch) {
                    switch (lhs, rhs) {
                    case (.replace(value: []), .add(value: [])):
                        
                        break // This looks
                        
                    case (.replace(value: let lhs), .replace(value: let rhs)):
                        XCTAssertEqual(rhs, lhs, file: file, line: line)
                    case (.add(value: let lhs), .add(value: let rhs)):
                        XCTAssertEqual(rhs, lhs, file: file, line: line)
                    case (.remove, .remove):
                        break // Equal
                    case (let lhs, let rhs):
                        XCTFail("\(lhs) is not the same as \(rhs)", file: file, line: line)
                    }
                }
            }
        }
        
        assertSimilarVariants(original: renderNode.topicSectionsVariants, decoded: decoded.topicSectionsVariants)
        assertSimilarVariants(original: renderNode.relationshipSectionsVariants, decoded: decoded.relationshipSectionsVariants)
        assertSimilarVariants(original: renderNode.seeAlsoSectionsVariants, decoded: decoded.seeAlsoSectionsVariants)
        
        // All other variants decode to the original value
        XCTAssertEqual(renderNode.defaultImplementationsSectionsVariants, decoded.defaultImplementationsSectionsVariants)
        XCTAssertEqual(renderNode.deprecationSummaryVariants, decoded.deprecationSummaryVariants)
        XCTAssertEqual(renderNode.abstractVariants, decoded.abstractVariants)
        XCTAssertEqual(renderNode.primaryContentSectionsVariants, decoded.primaryContentSectionsVariants)
        
        XCTAssertEqual(renderNode.metadata.modulesVariants, decoded.metadata.modulesVariants)
        XCTAssertEqual(renderNode.metadata.extendedModuleVariants, decoded.metadata.extendedModuleVariants)
        XCTAssertEqual(renderNode.metadata.requiredVariants, decoded.metadata.requiredVariants)
        XCTAssertEqual(renderNode.metadata.roleHeadingVariants, decoded.metadata.roleHeadingVariants)
        XCTAssertEqual(renderNode.metadata.titleVariants, decoded.metadata.titleVariants)
        XCTAssertEqual(renderNode.metadata.externalIDVariants, decoded.metadata.externalIDVariants)
        XCTAssertEqual(renderNode.metadata.symbolKindVariants, decoded.metadata.symbolKindVariants)
        XCTAssertEqual(renderNode.metadata.symbolAccessLevelVariants, decoded.metadata.symbolAccessLevelVariants)
        XCTAssertEqual(renderNode.metadata.sourceFileURIVariants, decoded.metadata.sourceFileURIVariants)
        XCTAssertEqual(renderNode.metadata.remoteSourceVariants, decoded.metadata.remoteSourceVariants)
        
        for case let originalTopic as TopicRenderReference in renderNode.references.values {
            let decodedTopic = try XCTUnwrap(decoded.references[originalTopic.identifier.identifier] as? TopicRenderReference)
            
            XCTAssertEqual(originalTopic.titleVariants, decodedTopic.titleVariants)
            XCTAssertEqual(originalTopic.abstractVariants, decodedTopic.abstractVariants)
            XCTAssertEqual(originalTopic.fragmentsVariants, decodedTopic.fragmentsVariants)
            XCTAssertEqual(originalTopic.navigatorTitleVariants, decodedTopic.navigatorTitleVariants)
        }
    }
    
    func testDecodingRenderNodeDoesNotCacheReferences() throws {
        let exampleRenderNodeJSON = Bundle.module.url(
            forResource: "Operator",
            withExtension: "json",
            subdirectory: "Test Resources"
        )!
        
        let bundleID: DocumentationContext.Inputs.Identifier = #function
        
        let renderNodeWithUniqueBundleID = try String(contentsOf: exampleRenderNodeJSON)
            .replacingOccurrences(of: "org.swift.docc.example", with: bundleID.rawValue)
        
        _ = try JSONDecoder().decode(RenderNode.self, from: Data(renderNodeWithUniqueBundleID.utf8))
        
        XCTAssertNil(ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID))
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
    
    func testEncodeRenderNodeWithCustomTopicSectionStyle() async throws {
        let (_, context) = try await testBundleAndContext()
        var diagnostics = [Diagnostic]()
        
        let source = """
            # My Great Article
            
            A great article.
            
            @Options {
                @TopicsVisualStyle(compactGrid)
            }
            """
        
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let article = try XCTUnwrap(
            Article(from: document.root, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        )
        
        let reference = ResolvedTopicReference(
            bundleID: "org.swift.docc.example",
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
        
        var translator = RenderNodeTranslator(context: context, identifier: reference)
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
fileprivate let missingReferenceKeyJSON = Data("""
{"kind":"article","identifier":{"interfaceLanguage":"","url":"doc://org.swift.docc.example/documentation/Test-Bundle/article"},"abstract":[],"metadata":{},"schemaVersion":{"minor":3,"patch":0,"major":0},"sections":[],"hierarchy":{"paths":[[]]}}
""".utf8)
