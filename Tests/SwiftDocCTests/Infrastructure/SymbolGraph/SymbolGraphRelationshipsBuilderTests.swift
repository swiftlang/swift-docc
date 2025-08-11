/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SymbolKit
@testable import SwiftDocC

class SymbolGraphRelationshipsBuilderTests: XCTestCase {
    
    private func createSymbols(
        documentationCache: inout DocumentationContext.ContentCache<DocumentationNode>,
        bundle: DocumentationBundle,
        sourceType: SymbolGraph.Symbol.Kind,
        targetType: SymbolGraph.Symbol.Kind
    ) -> SymbolGraph.Relationship {
        let sourceIdentifier = SymbolGraph.Symbol.Identifier(precise: "A", interfaceLanguage: SourceLanguage.swift.id)
        let targetIdentifier = SymbolGraph.Symbol.Identifier(precise: "B", interfaceLanguage: SourceLanguage.swift.id)
        
        let sourceRef = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/SomeModuleName/A", sourceLanguage: .swift)
        let targetRef = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/SomeModuleName/B", sourceLanguage: .swift)
        
        let moduleRef = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/SomeModuleName", sourceLanguage: .swift)
        
        let sourceSymbol = SymbolGraph.Symbol(identifier: sourceIdentifier, names: SymbolGraph.Symbol.Names(title: "A", navigator: nil, subHeading: nil, prose: nil), pathComponents: ["SomeModuleName", "A"], docComment: nil, accessLevel: .init(rawValue: "public"), kind: sourceType, mixins: [:])
        let targetSymbol = SymbolGraph.Symbol(identifier: targetIdentifier, names: SymbolGraph.Symbol.Names(title: "B", navigator: nil, subHeading: nil, prose: nil), pathComponents: ["SomeModuleName", "B"], docComment: nil, accessLevel: .init(rawValue: "public"), kind: targetType, mixins: [:])
        
        let engine = DiagnosticEngine()
        documentationCache.add(
            DocumentationNode(reference: sourceRef, symbol: sourceSymbol, platformName: "macOS", moduleReference: moduleRef, article: nil, engine: engine),
            reference: sourceRef,
            symbolID: "A"
        )
        documentationCache.add(
            DocumentationNode(reference: targetRef, symbol: targetSymbol, platformName: "macOS", moduleReference: moduleRef, article: nil, engine: engine),
            reference: targetRef,
            symbolID: "B"
        )
        XCTAssert(engine.problems.isEmpty)
        
        return SymbolGraph.Relationship(source: sourceIdentifier.precise, target: targetIdentifier.precise, kind: .defaultImplementationOf, targetFallback: nil)
    }
    
    private let swiftSelector = UnifiedSymbolGraph.Selector(interfaceLanguage: "swift", platform: nil)
    
    func testImplementsRelationship() async throws {
        let (bundle, context) = try await testBundleAndContext()
        var documentationCache = DocumentationContext.ContentCache<DocumentationNode>()
        let engine = DiagnosticEngine()
        
        let edge = createSymbols(documentationCache: &documentationCache, bundle: bundle, sourceType: .init(parsedIdentifier: .class, displayName: "Class"), targetType: .init(parsedIdentifier: .protocol, displayName: "Protocol"))
        
        // Adding the relationship
        SymbolGraphRelationshipsBuilder.addImplementationRelationship(edge: edge, selector: swiftSelector, in: bundle, context: context, localCache: documentationCache, engine: engine)
        
        // Test default implementation was added
        XCTAssertFalse((documentationCache["B"]!.semantic as! Symbol).defaultImplementations.implementations.isEmpty)
    }

    func testMultipleImplementsRelationships() async throws {
        let (bundle, context) = try await testBundleAndContext()
        var documentationCache = DocumentationContext.ContentCache<DocumentationNode>()
        let engine = DiagnosticEngine()

        let identifierA = SymbolGraph.Symbol.Identifier(precise: "A", interfaceLanguage: SourceLanguage.swift.id)
        let identifierB = SymbolGraph.Symbol.Identifier(precise: "B", interfaceLanguage: SourceLanguage.swift.id)
        let identifierC = SymbolGraph.Symbol.Identifier(precise: "C", interfaceLanguage: SourceLanguage.swift.id)

        let symbolRefA = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/SomeModuleName/A", sourceLanguage: .swift)
        let symbolRefB = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/SomeModuleName/B", sourceLanguage: .swift)
        let symbolRefC = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/SomeModuleName/C", sourceLanguage: .swift)
        let moduleRef = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/SomeModuleName", sourceLanguage: .swift)

        let symbolA = SymbolGraph.Symbol(identifier: identifierA, names: SymbolGraph.Symbol.Names(title: "A", navigator: nil, subHeading: nil, prose: nil), pathComponents: ["SomeModuleName", "A"], docComment: nil, accessLevel: .init(rawValue: "public"), kind: SymbolGraph.Symbol.Kind(parsedIdentifier: .func, displayName: "Function"), mixins: [:])
        let symbolB = SymbolGraph.Symbol(identifier: identifierB, names: SymbolGraph.Symbol.Names(title: "B", navigator: nil, subHeading: nil, prose: nil), pathComponents: ["SomeModuleName", "B"], docComment: nil, accessLevel: .init(rawValue: "public"), kind: SymbolGraph.Symbol.Kind(parsedIdentifier: .func, displayName: "Function"), mixins: [:])
        let symbolC = SymbolGraph.Symbol(identifier: identifierC, names: SymbolGraph.Symbol.Names(title: "C", navigator: nil, subHeading: nil, prose: nil), pathComponents: ["SomeModuleName", "C"], docComment: nil, accessLevel: .init(rawValue: "public"), kind: SymbolGraph.Symbol.Kind(parsedIdentifier: .func, displayName: "Function"), mixins: [:])

        documentationCache.add(
            DocumentationNode(reference: symbolRefA, symbol: symbolA, platformName: "macOS", moduleReference: moduleRef, article: nil, engine: engine),
            reference: symbolRefA,
            symbolID: "A"
        )
        documentationCache.add(
            DocumentationNode(reference: symbolRefB, symbol: symbolB, platformName: "macOS", moduleReference: moduleRef, article: nil, engine: engine),
            reference: symbolRefB,
            symbolID: "B"
        )
        documentationCache.add(
            DocumentationNode(reference: symbolRefC, symbol: symbolC, platformName: "macOS", moduleReference: moduleRef, article: nil, engine: engine),
            reference: symbolRefC,
            symbolID: "C"
        )
        XCTAssert(engine.problems.isEmpty)

        let edge1 = SymbolGraph.Relationship(source: identifierB.precise, target: identifierA.precise, kind: .defaultImplementationOf, targetFallback: nil)
        let edge2 = SymbolGraph.Relationship(source: identifierC.precise, target: identifierA.precise, kind: .defaultImplementationOf, targetFallback: nil)

        SymbolGraphRelationshipsBuilder.addImplementationRelationship(edge: edge1, selector: swiftSelector, in: bundle, context: context, localCache: documentationCache, engine: engine)
        SymbolGraphRelationshipsBuilder.addImplementationRelationship(edge: edge2, selector: swiftSelector, in: bundle, context: context, localCache: documentationCache, engine: engine)

        XCTAssertEqual((documentationCache["A"]!.semantic as! Symbol).defaultImplementations.groups.first?.references.map(\.url?.lastPathComponent), ["B", "C"])
    }

    func testConformsRelationship() async throws {
        let (bundle, _) = try await testBundleAndContext()
        var documentationCache = DocumentationContext.ContentCache<DocumentationNode>()
        let engine = DiagnosticEngine()
        
        let edge = createSymbols(documentationCache: &documentationCache, bundle: bundle, sourceType: .init(parsedIdentifier: .class, displayName: "Class"), targetType: .init(parsedIdentifier: .protocol, displayName: "Protocol"))
        
        // Adding the relationship
        SymbolGraphRelationshipsBuilder.addConformanceRelationship(edge: edge, selector: swiftSelector, in: bundle, localCache: documentationCache, externalCache: .init(), engine: engine)
        
        // Test default conforms to was added
        guard let conformsTo = (documentationCache["A"]!.semantic as! Symbol).relationships.groups.first(where: { group -> Bool in
            return group.kind == RelationshipsGroup.Kind.conformsTo
        }) else {
            XCTFail("Conforms to group not added")
            return
        }
        XCTAssertEqual(conformsTo.destinations.first?.url?.absoluteString, "doc://com.example.test/documentation/SomeModuleName/B")
        
        // Test default conformance was added
        guard let conforming = (documentationCache["B"]!.semantic as! Symbol).relationships.groups.first(where: { group -> Bool in
            return group.kind == RelationshipsGroup.Kind.conformingTypes
        }) else {
            XCTFail("Conforming types not added")
            return
        }
        XCTAssertEqual(conforming.destinations.first?.url?.absoluteString, "doc://com.example.test/documentation/SomeModuleName/A")
    }

    func testInheritanceRelationship() async throws {
        let (bundle, _) = try await testBundleAndContext()
        var documentationCache = DocumentationContext.ContentCache<DocumentationNode>()
        let engine = DiagnosticEngine()
        
        let edge = createSymbols(documentationCache: &documentationCache, bundle: bundle, sourceType: .init(parsedIdentifier: .class, displayName: "Class"), targetType: .init(parsedIdentifier: .protocol, displayName: "Protocol"))
        
        // Adding the relationship
        SymbolGraphRelationshipsBuilder.addInheritanceRelationship(edge: edge, selector: swiftSelector, in: bundle, localCache: documentationCache, externalCache: .init(), engine: engine)
        
        // Test inherits was added
        guard let inherits = (documentationCache["A"]!.semantic as! Symbol).relationships.groups.first(where: { group -> Bool in
            return group.kind == RelationshipsGroup.Kind.inheritsFrom
        }) else {
            XCTFail("Inherits from not added")
            return
        }
        XCTAssertEqual(inherits.destinations.first?.url?.absoluteString, "doc://com.example.test/documentation/SomeModuleName/B")
        
        // Test descendants were added
        guard let inherited = (documentationCache["B"]!.semantic as! Symbol).relationships.groups.first(where: { group -> Bool in
            return group.kind == RelationshipsGroup.Kind.inheritedBy
        }) else {
            XCTFail("Inherited by types not added")
            return
        }
        XCTAssertEqual(inherited.destinations.first?.url?.absoluteString, "doc://com.example.test/documentation/SomeModuleName/A")
    }
    
    func testInheritanceRelationshipFromOtherFramework() async throws {
        let (bundle, _) = try await testBundleAndContext()
        var documentationCache = DocumentationContext.ContentCache<DocumentationNode>()
        let engine = DiagnosticEngine()
        
        let sourceIdentifier = SymbolGraph.Symbol.Identifier(precise: "A", interfaceLanguage: SourceLanguage.swift.id)
        let targetIdentifier = SymbolGraph.Symbol.Identifier(precise: "B", interfaceLanguage: SourceLanguage.swift.id)
        
        let sourceRef = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/SomeModuleName/A", sourceLanguage: .swift)
        let moduleRef = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/SomeModuleName", sourceLanguage: .swift)
        
        let sourceSymbol = SymbolGraph.Symbol(identifier: sourceIdentifier, names: SymbolGraph.Symbol.Names(title: "A", navigator: nil, subHeading: nil, prose: nil), pathComponents: ["SomeModuleName", "A"], docComment: nil, accessLevel: .init(rawValue: "public"), kind: SymbolGraph.Symbol.Kind(parsedIdentifier: .class, displayName: "Class"), mixins: [:])
        
        documentationCache.add(
            DocumentationNode(reference: sourceRef, symbol: sourceSymbol, platformName: "macOS", moduleReference: moduleRef, article: nil, engine: engine),
            reference: sourceRef,
            symbolID: "A"
        )
        XCTAssert(engine.problems.isEmpty)
        
        let edge = SymbolGraph.Relationship(source: sourceIdentifier.precise, target: targetIdentifier.precise, kind: .inheritsFrom, targetFallback: "MyOtherKit.B")
        
        SymbolGraphRelationshipsBuilder.addInheritanceRelationship(edge: edge, selector: swiftSelector, in: bundle, localCache: documentationCache, externalCache: .init(), engine: engine)
        
        let relationships = (documentationCache["A"]!.semantic as! Symbol).relationships
        guard let inheritsShouldHaveFallback = relationships.groups.first(where: { group -> Bool in
            return group.kind == RelationshipsGroup.Kind.inheritsFrom
        }) else {
            XCTFail("Inherits from not added")
            return
        }
        
        XCTAssert(inheritsShouldHaveFallback.destinations.contains(where: { destination -> Bool in
            return relationships.targetFallbacks[destination] == "MyOtherKit.B"
        }), "Could not fallback for parent in inherits from relationship")
    }
    
    func testRequirementRelationship() async throws {
        let (bundle, _) = try await testBundleAndContext()
        var documentationCache = DocumentationContext.ContentCache<DocumentationNode>()
        let engine = DiagnosticEngine()
        
        let edge = createSymbols(documentationCache: &documentationCache, bundle: bundle, sourceType: .init(parsedIdentifier: .method, displayName: "Method"), targetType: .init(parsedIdentifier: .protocol, displayName: "Protocol"))
        
        // Adding the relationship
        SymbolGraphRelationshipsBuilder.addRequirementRelationship(edge: edge, localCache: documentationCache, engine: engine)
        
        // Test default implementation was added
        XCTAssertTrue((documentationCache["A"]!.semantic as! Symbol).isRequired)
    }
    
    func testOptionalRequirementRelationship() async throws {
        let (bundle, _) = try await testBundleAndContext()
        var documentationCache = DocumentationContext.ContentCache<DocumentationNode>()
        let engine = DiagnosticEngine()
        
        let edge = createSymbols(documentationCache: &documentationCache, bundle: bundle, sourceType: .init(parsedIdentifier: .method, displayName: "Method"), targetType: .init(parsedIdentifier: .protocol, displayName: "Protocol"))
        
        // Adding the relationship
        SymbolGraphRelationshipsBuilder.addOptionalRequirementRelationship(edge: edge, localCache: documentationCache, engine: engine)
        
        // Test default implementation was added
        XCTAssertFalse((documentationCache["A"]!.semantic as! Symbol).isRequired)
    }

    func testRequiredAndOptionalRequirementRelationships() async throws {
        do {
            let (bundle, _) = try await testBundleAndContext()
            var documentationCache = DocumentationContext.ContentCache<DocumentationNode>()
            let engine = DiagnosticEngine()

            let edge = createSymbols(documentationCache: &documentationCache, bundle: bundle, sourceType: .init(parsedIdentifier: .method, displayName: "Method"), targetType: .init(parsedIdentifier: .protocol, displayName: "Protocol"))

            // Adding the "required" relationship before the "optional" one
            SymbolGraphRelationshipsBuilder.addRequirementRelationship(edge: edge, localCache: documentationCache, engine: engine)
            SymbolGraphRelationshipsBuilder.addOptionalRequirementRelationship(edge: edge, localCache: documentationCache, engine: engine)

            // Make sure that the "optional" relationship wins
            XCTAssertFalse((documentationCache["A"]!.semantic as! Symbol).isRequired)
        }

        do {
            let (bundle, _) = try await testBundleAndContext()
            var documentationCache = DocumentationContext.ContentCache<DocumentationNode>()
            let engine = DiagnosticEngine()

            let edge = createSymbols(documentationCache: &documentationCache, bundle: bundle, sourceType: .init(parsedIdentifier: .method, displayName: "Method"), targetType: .init(parsedIdentifier: .protocol, displayName: "Protocol"))

            // Adding the "optional" relationship before the "required" one
            SymbolGraphRelationshipsBuilder.addOptionalRequirementRelationship(edge: edge, localCache: documentationCache, engine: engine)
            SymbolGraphRelationshipsBuilder.addRequirementRelationship(edge: edge, localCache: documentationCache, engine: engine)

            // Make sure that the "optional" relationship still wins
            XCTAssertFalse((documentationCache["A"]!.semantic as! Symbol).isRequired)
        }
    }
}
