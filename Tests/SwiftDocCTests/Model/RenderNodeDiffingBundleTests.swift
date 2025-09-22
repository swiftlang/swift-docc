/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class RenderNodeDiffingBundleTests: XCTestCase {
    let testBundleName = "LegacyBundle_DoNotUseInNewTests"
    let testBundleID: DocumentationContext.Inputs.Identifier = "org.swift.docc.example"
    
    func testDiffSymbolFromBundleWithDiscussionSectionRemoved() async throws {
        let pathToSymbol = "/documentation/MyKit"
        
        let modification = { (url: URL) in
            let symbolURL = url.appendingPathComponent("documentation/mykit.md")
            let text = try String(contentsOf: symbolURL).replacingOccurrences(of: """
            ## Discussion

            MyKit is the best module
            """, with: "")
            try text.write(to: symbolURL, atomically: true, encoding: .utf8)
        }
        
        let differences = try await getDiffsFromModifiedDocument(bundleName: testBundleName,
                                                           bundleID: testBundleID,
                                                           topicReferencePath: pathToSymbol,
                                                           modification: modification)

        XCTAssertFalse(differences.isEmpty, "Both render nodes should be different.")
        
        let expectedSectionDiff = JSONPatchOperation.remove(pointer: JSONPointer(pathComponents: ["primaryContentSections", "0"]))
        assertDifferences(differences,
                          contains: expectedSectionDiff,
                          valueType: RenderInlineContent.self)
    }
    
    func testDiffArticleFromBundleWithTopicSectionAdded() async throws {
        let pathToArticle = "/documentation/Test-Bundle/article"
        
        let modification = { (url: URL) in
            let articleURL = url.appendingPathComponent("article.md")
            let text = try String(contentsOf: articleURL).replacingOccurrences(of: "## Topics", with: """
            ## Topics

            ### Tutorials
             - <doc:/tutorials/Test-Bundle/TestTutorial>
             - <doc:/tutorials/Test-Bundle/TestTutorial2>
            """)
            try text.write(to: articleURL, atomically: true, encoding: .utf8)
        }
        
        let differences = try await getDiffsFromModifiedDocument(bundleName: testBundleName,
                                                           bundleID: testBundleID,
                                                           topicReferencePath: pathToArticle,
                                                           modification: modification)

        XCTAssertFalse(differences.isEmpty, "Both render nodes should be different.")
        
        let expectedDiff = JSONPatchOperation.add(pointer: JSONPointer(pathComponents: ["topicSections", "0"]),
                                                  value: AnyCodable(TaskGroupRenderSection(title: "Tutorials",
                                                                                           abstract: nil,
                                                                                           discussion: nil,
                                                                                           identifiers: ["doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial",
                                                                                                "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial2"],
                                                                                           generated: false,
                                                                                           anchor: "Tutorials")))
        assertDifferences(differences,
                          contains: expectedDiff,
                          valueType: TaskGroupRenderSection.self)
    }
    
    func testDiffArticleFromBundleWithSeeAlsoSectionRemoved() async throws {
        let pathToArticle = "/documentation/Test-Bundle/article"
        
        let modification = { (url: URL) in
            let articleURL = url.appendingPathComponent("article.md")
            let text = try String(contentsOf: articleURL).replacingOccurrences(of: """
            ## See Also
            
            - [Website](https://www.website.com)
            """, with: "")
            try text.write(to: articleURL, atomically: true, encoding: .utf8)
        }
        
        let differences = try await getDiffsFromModifiedDocument(bundleName: testBundleName,
                                                           bundleID: testBundleID,
                                                           topicReferencePath: pathToArticle,
                                                           modification: modification)
        
        XCTAssertFalse(differences.isEmpty, "Both render nodes should be different.")
        
        let expectedSectionDiff = JSONPatchOperation.remove(pointer: JSONPointer(pathComponents: ["seeAlsoSections", "0"]))
        assertDifferences(differences,
                          contains: expectedSectionDiff,
                          valueType: RenderInlineContent.self)
        
        let expectedReferenceDiff = JSONPatchOperation.remove(pointer: JSONPointer(pathComponents: ["references",
                                                                                                    "https://www.website.com"]))
        assertDifferences(differences,
                          contains: expectedReferenceDiff,
                          valueType: RenderInlineContent.self)
    }
    
    func testDiffSymbolFromBundleWithTopicSectionRemoved() async throws {
        let pathToSymbol = "/documentation/MyKit"
        
        let modification = { (url: URL) in
            let symbolURL = url.appendingPathComponent("documentation/mykit.md")
            let text = try String(contentsOf: symbolURL).replacingOccurrences(of: """
            ### Extensions to other frameworks

             - ``SideKit/UncuratedClass/angle``
            """, with: "")
            try text.write(to: symbolURL, atomically: true, encoding: .utf8)
        }
        
        let differences = try await getDiffsFromModifiedDocument(bundleName: testBundleName,
                                                           bundleID: testBundleID,
                                                           topicReferencePath: pathToSymbol,
                                                           modification: modification)
        
        XCTAssertFalse(differences.isEmpty, "Both render nodes should be different.")
        
        let expectedSectionDiff = JSONPatchOperation.remove(pointer: JSONPointer(pathComponents: ["topicSections", "3"]))
        assertDifferences(differences,
                          contains: expectedSectionDiff,
                          valueType: RenderInlineContent.self)
        
        let expectedReferenceDiff = JSONPatchOperation.remove(pointer: JSONPointer(pathComponents: ["references",
                                                                                                    "doc://org.swift.docc.example/documentation/SideKit/UncuratedClass/angle"]))
        assertDifferences(differences,
                          contains: expectedReferenceDiff,
                          valueType: RenderInlineContent.self)
    }
    
    func testDiffSymbolFromBundleWithAbstractUpdated() async throws {
        let pathToSymbol = "/documentation/MyKit/MyClass"
        let newAbstractValue = "MyClass new abstract."
        
        let modification = { (url: URL) in
            let symbolURL = url.appendingPathComponent("documentation/myclass.md")
            let text = try String(contentsOf: symbolURL).replacingOccurrences(of: "MyClass abstract.", with: newAbstractValue)
            try text.write(to: symbolURL, atomically: true, encoding: .utf8)
        }
        
        let differences = try await getDiffsFromModifiedDocument(bundleName: testBundleName,
                                                           bundleID: testBundleID,
                                                           topicReferencePath: pathToSymbol,
                                                           modification: modification)

        XCTAssertFalse(differences.isEmpty, "Both render nodes should be different.")
        
        let expectedAbstractDiff = JSONPatchOperation.add(pointer: JSONPointer(pathComponents: ["abstract", "0"]),
                                                          value: AnyCodable(RenderInlineContent.text(newAbstractValue)))
        assertDifferences(differences,
                          contains: expectedAbstractDiff,
                          valueType: RenderInlineContent.self)
        
        let expectedReferenceDiff = JSONPatchOperation.remove(pointer: JSONPointer(pathComponents: ["references",
                                                                                                    "doc://org.swift.docc.example/documentation/MyKit/MyClass",
                                                                                                    "abstract",
                                                                                                    "0"]))
        assertDifferences(differences,
                          contains: expectedReferenceDiff,
                          valueType: AnyRenderReference.self)
    }
    
    func testDiffSymbolFromBundleWithDeprecationAdded() async throws {
        let pathToSymbol = "/documentation/MyKit/MyProtocol"
        let newDeprecationValue = "This protocol has been deprecated."
        
        let modification = { (url: URL) in
            let symbolURL = url.appendingPathComponent("documentation/myprotocol.md")
            let text = try String(contentsOf: symbolURL).replacingOccurrences(of: "# <doc:MyKit/MyProtocol>", with: """
            # <doc:MyKit/MyProtocol>
            
            @DeprecationSummary {
            \(newDeprecationValue)
            }
            """)
            try text.write(to: symbolURL, atomically: true, encoding: .utf8)
        }
        
        let differences = try await getDiffsFromModifiedDocument(bundleName: testBundleName,
                                                           bundleID: testBundleID,
                                                           topicReferencePath: pathToSymbol,
                                                           modification: modification)
        
        XCTAssertFalse(differences.isEmpty, "Both render nodes should be different.")
        
        let expectedDeprecationDiff = JSONPatchOperation.add(pointer: JSONPointer(pathComponents: ["deprecationSummary"]),
                                                             value: AnyCodable([RenderBlockContent.paragraph(RenderBlockContent.Paragraph(
                                                                inlineContent: [RenderInlineContent.text(newDeprecationValue)]))]))
        assertDifferences(differences,
                          contains: expectedDeprecationDiff,
                          valueType: [RenderBlockContent].self)
        
        let expectedReferenceDiff = JSONPatchOperation.replace(pointer: JSONPointer(pathComponents: ["references",
                                                                                                     "doc://org.swift.docc.example/documentation/MyKit/MyProtocol",
                                                                                                     "deprecated"]),
                                                               value: AnyCodable(true))
        assertDifferences(differences,
                          contains: expectedReferenceDiff,
                          valueType: Bool.self)
    }
    
    func testDiffSymbolFromBundleWithDisplayNameDirectiveAdded() async throws {
        let pathToSymbol = "/documentation/MyKit"
        let newTitleValue = "My Kit"
        
        let modification = { (url: URL) in
            let symbolURL = url.appendingPathComponent("documentation/mykit.md")
            let text = try String(contentsOf: symbolURL).replacingOccurrences(of: "# ``MyKit``", with: """
            # ``MyKit``

            @Metadata {
                @DisplayName("\(newTitleValue)")
            }
            """)
            try text.write(to: symbolURL, atomically: true, encoding: .utf8)
        }
        
        let differences = try await getDiffsFromModifiedDocument(bundleName: testBundleName,
                                                           bundleID: testBundleID,
                                                           topicReferencePath: pathToSymbol,
                                                           modification: modification)
        
        XCTAssertFalse(differences.isEmpty, "Both render nodes should be different.")
        
        let expectedTitleDiff = JSONPatchOperation.replace(pointer: JSONPointer(pathComponents: ["metadata", "title"]),
                                                           value: AnyCodable(newTitleValue))
        assertDifferences(differences,
                          contains: expectedTitleDiff,
                          valueType: String.self)
        
        let expectedModuleDiff = JSONPatchOperation.add(pointer: JSONPointer(pathComponents: ["metadata", "modules", "0"]),
                                                        value: AnyCodable(RenderMetadata.Module(name: newTitleValue, relatedModules: nil)))
        assertDifferences(differences,
                          contains: expectedModuleDiff,
                          valueType: RenderMetadata.Module.self)
    }
    
    func testDiffArticleFromBundleWithDownloadDirectiveAdded() async throws {
        let pathToArticle = "/documentation/Test-Bundle/article"
        
        let modification = { (url: URL) in
            let articleURL = url.appendingPathComponent("article.md")
            let text = try String(contentsOf: articleURL).replacingOccurrences(of: "# My Cool Article", with: """
            # My Cool Article

            @Metadata {
                @CallToAction(file: "Downloads/mykit.svg", purpose: download)
                @PageKind(sampleCode)
            }
            """)
            try text.write(to: articleURL, atomically: true, encoding: .utf8)
        }
        
        let differences = try await getDiffsFromModifiedDocument(bundleName: testBundleName,
                                                           bundleID: testBundleID,
                                                           topicReferencePath: pathToArticle,
                                                           modification: modification)
        
        XCTAssertFalse(differences.isEmpty, "Both render nodes should be different.")
        
        let expectedRoleHeadingDiff = JSONPatchOperation.replace(pointer: JSONPointer(pathComponents: ["metadata", "roleHeading"]),
                                                                 value: AnyCodable("Sample Code"))
        assertDifferences(differences,
                          contains: expectedRoleHeadingDiff,
                          valueType: String.self)
        
        let expectedRoleDiff = JSONPatchOperation.replace(pointer: JSONPointer(pathComponents: ["metadata", "role"]),
                                                          value: AnyCodable("sampleCode"))
        assertDifferences(differences,
                          contains: expectedRoleDiff,
                          valueType: String.self)
    }
    
    func testNoDiffsWhenReconvertingSameBundle() async throws {
        let (_, context) = try await testBundleAndContext(named: testBundleName)
        let renderContext = RenderContext(documentationContext: context)
        let converter = DocumentationContextConverter(context: context, renderContext: renderContext)
        
        for identifier in context.knownPages {
            let entity = try context.entity(with: identifier)
            let renderNodeFirst = try XCTUnwrap(converter.renderNode(for: entity))
            let renderNodeSecond = try XCTUnwrap(converter.renderNode(for: entity))
            
            let differences = renderNodeSecond._difference(from: renderNodeFirst)
            XCTAssertTrue(differences.isEmpty, "Both render nodes should be identical.")
        }
    }
    
    func getDiffsFromModifiedDocument(bundleName: String,
                                      bundleID: DocumentationContext.Inputs.Identifier,
                                      topicReferencePath: String,
                                      modification: @escaping (URL) throws -> ()
    ) async throws -> JSONPatchDifferences {
        let (_, contextOriginal) = try await testBundleAndContext(named: bundleName)
        let nodeOriginal = try contextOriginal.entity(with: ResolvedTopicReference(bundleID: bundleID,
                                                                                   path: topicReferencePath,
                                                                                   sourceLanguage: .swift))
        var renderContext = RenderContext(documentationContext: contextOriginal)
        var converter = DocumentationContextConverter(context: contextOriginal, renderContext: renderContext)
        
        let renderNodeOriginal = try XCTUnwrap(converter.renderNode(for: nodeOriginal))
        
        // Make copy of the bundle on disk, modify the document, and write it
        let (_, _, contextModified) = try await testBundleAndContext(copying: bundleName) { url in
            try modification(url)
        }
        let nodeModified = try contextModified.entity(with: ResolvedTopicReference(bundleID: bundleID,
                                                                                   path: topicReferencePath,
                                                                                   sourceLanguage: .swift))
        renderContext = RenderContext(documentationContext: contextModified)
        converter = DocumentationContextConverter(context: contextModified, renderContext: renderContext)
        
        let renderNodeModified = try XCTUnwrap(converter.renderNode(for: nodeModified))
        
        let differences = renderNodeModified._difference(from: renderNodeOriginal)
        
        return differences
    }
    
    func assertDifferences<Value: Equatable>(
        _ differences: JSONPatchDifferences,
        contains expectedDiff: JSONPatchOperation,
        valueType: Value.Type,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let foundDiff = differences.first(where: { $0.pointer == expectedDiff.pointer &&
                                                         $0.operation == expectedDiff.operation }) else {
            XCTFail("No diff with pointer \(expectedDiff.pointer) and operation \(expectedDiff.operation)", file: file, line: line)
            return
        }
        
        switch (expectedDiff, foundDiff) {
        case let (.replace(_, expected), .replace(_, found)):
            guard let expectedValue = expected.value as? Value else {
                XCTFail("Wrong type of value for expected diff \(expected.value)", file: file, line: line)
                return
            }
            guard let foundValue = found.value as? Value else {
                XCTFail("Wrong type of value for found diff \(found.value)", file: file, line: line)
                return
            }
            XCTAssertEqual(expectedValue, foundValue, file: file, line: line)

        case let (.add(_, expected), .add(_, found)):
            guard let expectedValue = expected.value as? Value else {
                XCTFail("Wrong type of value for expected diff \(expected.value)", file: file, line: line)
                return
            }
            guard let foundValue = found.value as? Value else {
                XCTFail("Wrong type of value for found diff \(found.value)", file: file, line: line)
                return
            }
            XCTAssertEqual(expectedValue, foundValue, file: file, line: line)
            
        case (.remove(_), .remove(_)):
            return // The JSON pointers have already been compared above.
        default:
            XCTFail("Found diff \(foundDiff.operation) doesn't match the expected diff \(expectedDiff.operation).", file: file, line: line)
        }
    }
}
