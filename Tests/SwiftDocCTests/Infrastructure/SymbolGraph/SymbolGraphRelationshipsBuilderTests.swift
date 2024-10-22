/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
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
        
        let sourceRef = ResolvedTopicReference(id: bundle.id, path: "/documentation/MyKit/A", sourceLanguage: .swift)
        let targetRef = ResolvedTopicReference(id: bundle.id, path: "/documentation/MyKit/B", sourceLanguage: .swift)
        
        let moduleRef = ResolvedTopicReference(id: bundle.id, path: "/documentation/MyKit", sourceLanguage: .swift)
        
        let sourceSymbol = SymbolGraph.Symbol(identifier: sourceIdentifier, names: SymbolGraph.Symbol.Names(title: "A", navigator: nil, subHeading: nil, prose: nil), pathComponents: ["MyKit", "A"], docComment: nil, accessLevel: .init(rawValue: "public"), kind: sourceType, mixins: [:])
        let targetSymbol = SymbolGraph.Symbol(identifier: targetIdentifier, names: SymbolGraph.Symbol.Names(title: "B", navigator: nil, subHeading: nil, prose: nil), pathComponents: ["MyKit", "B"], docComment: nil, accessLevel: .init(rawValue: "public"), kind: targetType, mixins: [:])
        
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
    
    func testImplementsRelationship() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var documentationCache = DocumentationContext.ContentCache<DocumentationNode>()
        let engine = DiagnosticEngine()
        
        let edge = createSymbols(documentationCache: &documentationCache, bundle: bundle, sourceType: .init(parsedIdentifier: .class, displayName: "Class"), targetType: .init(parsedIdentifier: .protocol, displayName: "Protocol"))
        
        // Adding the relationship
        SymbolGraphRelationshipsBuilder.addImplementationRelationship(edge: edge, selector: swiftSelector, in: bundle, context: context, localCache: documentationCache, engine: engine)
        
        // Test default implementation was added
        XCTAssertFalse((documentationCache["B"]!.semantic as! Symbol).defaultImplementations.implementations.isEmpty)
    }

    func testConformsRelationship() throws {
        let bundle = try testBundle(named: "TestBundle")
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
        XCTAssertEqual(conformsTo.destinations.first?.url?.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/B")
        
        // Test default conformance was added
        guard let conforming = (documentationCache["B"]!.semantic as! Symbol).relationships.groups.first(where: { group -> Bool in
            return group.kind == RelationshipsGroup.Kind.conformingTypes
        }) else {
            XCTFail("Conforming types not added")
            return
        }
        XCTAssertEqual(conforming.destinations.first?.url?.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/A")
    }

    func testInheritanceRelationship() throws {
        let bundle = try testBundle(named: "TestBundle")
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
        XCTAssertEqual(inherits.destinations.first?.url?.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/B")
        
        // Test descendants were added
        guard let inherited = (documentationCache["B"]!.semantic as! Symbol).relationships.groups.first(where: { group -> Bool in
            return group.kind == RelationshipsGroup.Kind.inheritedBy
        }) else {
            XCTFail("Inherited by types not added")
            return
        }
        XCTAssertEqual(inherited.destinations.first?.url?.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/A")
    }
    
    func testInheritanceRelationshipFromOtherFramework() throws {
        let bundle = try testBundle(named: "TestBundle")
        var documentationCache = DocumentationContext.ContentCache<DocumentationNode>()
        let engine = DiagnosticEngine()
        
        let sourceIdentifier = SymbolGraph.Symbol.Identifier(precise: "A", interfaceLanguage: SourceLanguage.swift.id)
        let targetIdentifier = SymbolGraph.Symbol.Identifier(precise: "B", interfaceLanguage: SourceLanguage.swift.id)
        
        let sourceRef = ResolvedTopicReference(id: bundle.id, path: "/documentation/MyKit/A", sourceLanguage: .swift)
        let moduleRef = ResolvedTopicReference(id: bundle.id, path: "/documentation/MyKit", sourceLanguage: .swift)
        
        let sourceSymbol = SymbolGraph.Symbol(identifier: sourceIdentifier, names: SymbolGraph.Symbol.Names(title: "A", navigator: nil, subHeading: nil, prose: nil), pathComponents: ["MyKit", "A"], docComment: nil, accessLevel: .init(rawValue: "public"), kind: SymbolGraph.Symbol.Kind(parsedIdentifier: .class, displayName: "Class"), mixins: [:])
        
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
    
    func testRequirementRelationship() throws {
        let bundle = try testBundle(named: "TestBundle")
        var documentationCache = DocumentationContext.ContentCache<DocumentationNode>()
        let engine = DiagnosticEngine()
        
        let edge = createSymbols(documentationCache: &documentationCache, bundle: bundle, sourceType: .init(parsedIdentifier: .method, displayName: "Method"), targetType: .init(parsedIdentifier: .protocol, displayName: "Protocol"))
        
        // Adding the relationship
        SymbolGraphRelationshipsBuilder.addRequirementRelationship(edge: edge, localCache: documentationCache, engine: engine)
        
        // Test default implementation was added
        XCTAssertTrue((documentationCache["A"]!.semantic as! Symbol).isRequired)
    }
    
    func testOptionalRequirementRelationship() throws {
        let bundle = try testBundle(named: "TestBundle")
        var documentationCache = DocumentationContext.ContentCache<DocumentationNode>()
        let engine = DiagnosticEngine()
        
        let edge = createSymbols(documentationCache: &documentationCache, bundle: bundle, sourceType: .init(parsedIdentifier: .method, displayName: "Method"), targetType: .init(parsedIdentifier: .protocol, displayName: "Protocol"))
        
        // Adding the relationship
        SymbolGraphRelationshipsBuilder.addOptionalRequirementRelationship(edge: edge, localCache: documentationCache, engine: engine)
        
        // Test default implementation was added
        XCTAssertFalse((documentationCache["A"]!.semantic as! Symbol).isRequired)
    }
}
