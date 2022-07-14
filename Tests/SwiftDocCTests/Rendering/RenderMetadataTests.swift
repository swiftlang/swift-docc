/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class RenderMetadataTests: XCTestCase {
    
    var testTitleVariants = VariantCollection<String?>(
        defaultValue: "Default title",
        objectiveCValue: "Objective-C title"
    )
    
    func testRenderEmptyMetadata() throws {
        let metadata = RenderMetadata()
        guard let data = try? JSONEncoder().encode(metadata) else {
            XCTFail("Failed to encode empty render metadata")
            return
        }
        let string = String(decoding: data, as: UTF8.self)
        // Test all keys are optional during export
        XCTAssertFalse(string.contains(":"))
    }

    func testDecodeEmptyMetadata() throws {
        let string = "{}"
        let data = string.data(using: .utf8)!
        guard let _ = try? JSONDecoder().decode(RenderMetadata.self, from: data) else {
            XCTFail("Failed to decode empty render metadata")
            return
        }
    }
    
    func testDecodeSymbolMetadata() throws {
        let plistSymbolURL = Bundle.module.url(
            forResource: "plist-symbol", withExtension: "json",
            subdirectory: "Rendering Fixtures")!
        
        let data = try Data(contentsOf: plistSymbolURL)
        let symbol = try RenderNode.decode(fromJSON: data)
        
        XCTAssertEqual(symbol.metadata.externalID, "plistkey-123")
        
        XCTAssertEqual(symbol.metadata.title, "Wifi Access")
        XCTAssertEqual(symbol.metadata.roleHeading, "Property List Key")
        XCTAssertEqual(symbol.metadata.modules?.map({ (module) -> String in
            return module.name
        }), ["MyKit"])
        XCTAssertEqual(symbol.metadata.externalID, "plistkey-123")
        XCTAssertEqual(symbol.metadata.platforms?.first?.introduced, "10.15")
        XCTAssertEqual(symbol.metadata.role, "symbol")
        XCTAssertEqual(symbol.metadata.sourceFileURI, "file:///username/developer/project/test.swift")
    }
    
    func testDecodeArbitrarySymbolKind() throws {
        let data = try JSONSerialization.data(withJSONObject: ["symbolKind": "plum"], options: [])
        guard let metadata = try? JSONDecoder().decode(RenderMetadata.self, from: data) else {
            XCTFail("Failed to decode empty render metadata")
            return
        }
        XCTAssertEqual(metadata.symbolKind, "plum")
    }

    func testAllPagesHaveTitleMetadata() throws {
        var typesOfPages = [Tutorial.self, Technology.self, Article.self, TutorialArticle.self, Symbol.self]
        
        for bundleName in ["TestBundle"] {
            let (bundle, context) = try testBundleAndContext(named: bundleName)
            
            let renderContext = RenderContext(documentationContext: context, bundle: bundle)
            let converter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
            for identifier in context.knownPages {
                let source = context.documentURL(for: identifier)
                
                let entity = try context.entity(with: identifier)
                let renderNode = try XCTUnwrap(converter.renderNode(for: entity, at: source))
                
                XCTAssertNotNil(renderNode.metadata.title, "Missing `title` in metadata for \(identifier.absoluteString) of kind \(entity.kind.id) in the \(bundleName) bundle")
                
                typesOfPages.removeAll(where: { type(of: entity.semantic!) == $0 })
            }
        }
        
        XCTAssert(typesOfPages.isEmpty, "Never verified page with semantics: \(typesOfPages.map { "\($0)" }.joined(separator: ", "))")
    }
    
    /// Test that a bystanders symbol graph is loaded, symbols are merged into the main module
    /// and the bystanders are included in the render node metadata.
    func testRendersBystandersFromSymbolGraph() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: [:]) { url in
            let bystanderSymbolGraphURL = Bundle.module.url(
                forResource: "MyKit@Foundation@_MyKit_Foundation.symbols", withExtension: "json", subdirectory: "Test Resources")!
            try FileManager.default.copyItem(at: bystanderSymbolGraphURL, to: url.appendingPathComponent("MyKit@Foundation@_MyKit_Foundation.symbols.json"))
        }

        // Verify the symbol from bystanders graph is present in the documentation context.
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass/myFunction1()", sourceLanguage: .swift)
        let entity = try XCTUnwrap(try? context.entity(with: reference))
        let symbol = try XCTUnwrap(entity.semantic as? Symbol)
        
        // Verify it contains the bystanders data
        XCTAssertEqual(symbol.crossImportOverlayModule?.bystanderModules, ["Foundation"])
        
        // Verify the rendered metadata contains the bystanders
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let renderNode = try converter.convert(entity, at: nil)
        XCTAssertEqual(renderNode.metadata.modules?.first?.name, "MyKit")
        XCTAssertEqual(renderNode.metadata.modules?.first?.relatedModules, ["Foundation"])
    }

    /// Test that when a bystanders symbol graph is loaded that extends a different module, that
    /// those symbols correctly report the modules when rendered.
    func testRendersBystanderExtensionsFromSymbolGraph() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: [:]) { url in
            let baseSymbolGraphURL = Bundle.module.url(
                forResource: "BaseKit.symbols", withExtension: "json", subdirectory: "Test Resources")!
            try FileManager.default.copyItem(at: baseSymbolGraphURL, to: url.appendingPathComponent("BaseKit.symbols.json"))
            let overlaySymbolGraphURL = Bundle.module.url(
                forResource: "_OverlayTest_BaseKit@BaseKit.symbols", withExtension: "json", subdirectory: "Test Resources")!
            try FileManager.default.copyItem(at: overlaySymbolGraphURL, to: url.appendingPathComponent("_OverlayTest_BaseKit@BaseKit.symbols.json"))
        }

        // Verify the symbol from bystanders graph is present in the documentation context.
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/BaseKit/OtherStruct/someFunc()", sourceLanguage: .swift)
        let entity = try XCTUnwrap(try? context.entity(with: reference))
        let symbol = try XCTUnwrap(entity.semantic as? Symbol)

        // Verify it contains the bystanders data
        XCTAssertEqual(symbol.crossImportOverlayModule?.bystanderModules, ["BaseKit"])

        // Verify the rendered metadata contains the bystanders
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let renderNode = try converter.convert(entity, at: nil)
        XCTAssertEqual(renderNode.metadata.modules?.first?.name, "OverlayTest")
        XCTAssertEqual(renderNode.metadata.modules?.first?.relatedModules, ["BaseKit"])
    }
    
    func testEmitsTitleVariantsDuringEncoding() throws {
        var metadata = RenderMetadata()
        metadata.titleVariants = testTitleVariants
        
        let encoder = RenderJSONEncoder.makeEncoder()
        _ = try encoder.encode(metadata)
        
        let variantOverrides = try XCTUnwrap(encoder.userInfo[.variantOverrides] as? VariantOverrides)
        XCTAssertEqual(variantOverrides.values.count, 1)
        
        let variantOverride = try XCTUnwrap(variantOverrides.values.first)
        XCTAssertEqual(variantOverride.traits, [.interfaceLanguage("objc")])
        
        XCTAssertEqual(variantOverride.patch.count, 1)
        let operation = try XCTUnwrap(variantOverride.patch.first)
        XCTAssertEqual(operation.operation, .replace)
        XCTAssertEqual(operation.pointer.pathComponents, ["title"])
        guard case .replace(_, let value) = operation else {
            XCTFail("Unexpected patch operation")
            return
        }
        XCTAssertEqual(value.value as! String, "Objective-C title")
    }
    
    func testSetsTitleDuringDecoding() throws {
        let metadata = try JSONDecoder().decode(
            RenderMetadata.self,
            from: #"{ "title": "myTitle" }"#.data(using: .utf8)!
        )
        XCTAssertEqual(metadata.title, "myTitle")
    }
    
    func testSetsTitleVariantsDefaultValueWhenSettingTitle() {
        var metadata = RenderMetadata()
        metadata.title = "another title"
        
        XCTAssertEqual(metadata.titleVariants.defaultValue, "another title")
    }
    
    func testGetsTitleVariantsDefaultValueWhenGettingTitle() {
        var metadata = RenderMetadata()
        metadata.titleVariants = testTitleVariants
        XCTAssertEqual(metadata.title, "Default title")
    }
}
