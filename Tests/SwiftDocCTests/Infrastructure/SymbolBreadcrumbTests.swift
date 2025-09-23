/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class SymbolBreadcrumbTests: XCTestCase {
    func testLanguageSpecificBreadcrumbs() async throws {
        let context = try await loadFromDisk(catalogName: "GeometricalShapes")
        let resolver = try XCTUnwrap(context.linkResolver.localResolver)
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        
        // typedef struct {
        //     CGPoint center;
        //     CGFloat radius;
        // } TLACircle NS_SWIFT_NAME(Circle);
        do {
            let reference = try XCTUnwrap(context.knownPages.first(where: { $0.path == "\(moduleReference.path)/Circle/center" }))
            XCTAssertEqual(reference.sourceLanguages.count, 2, "Symbol has 2 language representations")
            
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .swift)?.map(\.path), [
                "/documentation/GeometricalShapes",
                "/documentation/GeometricalShapes/Circle",
            ])
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .objectiveC)?.map(\.path), [
                "/documentation/GeometricalShapes",
                "/documentation/GeometricalShapes/Circle", // named TLACircle in Objective-C
            ])
            
            assertNoVariantsForRenderHierarchy(reference, context) // Same breadcrumbs in both languages
        }
        
        // extern const TLACircle TLACircleZero NS_SWIFT_NAME(Circle.zero);
        do {
            let reference = try XCTUnwrap(context.knownPages.first(where: { $0.path == "\(moduleReference.path)/Circle/zero" }))
            XCTAssertEqual(reference.sourceLanguages.count, 2, "Symbol has 2 language representations")
            
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .swift)?.map(\.path), [
                "/documentation/GeometricalShapes",
                "/documentation/GeometricalShapes/Circle", // The Swift representation is a member
            ])
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .objectiveC)?.map(\.path), [
                "/documentation/GeometricalShapes", // The Objective-C representation is a top-level function
            ])
            
            assertHasSomeVariantsForRenderHierarchy(reference, context) // Different breadcrumbs in different languages
        }
        
        // BOOL TLACircleIntersects(TLACircle circle, TLACircle otherCircle) NS_SWIFT_NAME(Circle.intersects(self:_:));
        do {
            let reference = try XCTUnwrap(context.knownPages.first(where: { $0.path == "\(moduleReference.path)/Circle/intersects(_:)" }))
            XCTAssertEqual(reference.sourceLanguages.count, 2, "Symbol has 2 language representations")
            
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .swift)?.map(\.path), [
                "/documentation/GeometricalShapes",
                "/documentation/GeometricalShapes/Circle", // The Swift representation is a member
            ])
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .objectiveC)?.map(\.path), [
                "/documentation/GeometricalShapes", // The Objective-C representation is a top-level function
            ])
            
            assertHasSomeVariantsForRenderHierarchy(reference, context) // Different breadcrumbs in different languages
        }

        // TLACircle TLACircleMake(CGPoint center, CGFloat radius) NS_SWIFT_UNAVAILABLE("Use 'Circle.init(center:radius:)' instead.");
        do {
            let reference = try XCTUnwrap(context.knownPages.first(where: { $0.path == "\(moduleReference.path)/TLACircleMake" }))
            XCTAssertEqual(reference.sourceLanguages.count, 1, "Symbol only has one language representation")
            
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .swift)?.map(\.path), nil) // There is no Swift representation
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .objectiveC)?.map(\.path), [
                "/documentation/GeometricalShapes", // The Objective-C representation is a top-level function
            ])
            
            assertNoVariantsForRenderHierarchy(reference, context) // Only has one language representation
        }
        
        do {
            let reference = try XCTUnwrap(context.knownPages.first(where: { $0.path == "\(moduleReference.path)/Circle/init(center:radius:)" }))
            XCTAssertEqual(reference.sourceLanguages.count, 1, "Symbol only has one language representation")
            
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .swift)?.map(\.path), [
                "/documentation/GeometricalShapes",
                "/documentation/GeometricalShapes/Circle", // The Swift representation is a member
            ])
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .objectiveC)?.map(\.path), nil) // There is no Objective-C representation
            
            assertNoVariantsForRenderHierarchy(reference, context) // Only has one language representation
        }
    }
    
    func testMixedLanguageSpecificBreadcrumbs() async throws {
        let context = try await loadFromDisk(catalogName: "MixedLanguageFramework")
        let resolver = try XCTUnwrap(context.linkResolver.localResolver)
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        
        do {
            let reference = try XCTUnwrap(context.knownPages.first(where: { $0.path == "\(moduleReference.path)/MixedLanguageProtocol/mixedLanguageMethod()" }))
            XCTAssertEqual(reference.sourceLanguages.count, 2, "Symbol has 2 language representations")
            
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .swift)?.map(\.path), [
                "/documentation/MixedLanguageFramework",
                "/documentation/MixedLanguageFramework/MixedLanguageProtocol",
            ])
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .objectiveC)?.map(\.path), [
                "/documentation/MixedLanguageFramework",
                "/documentation/MixedLanguageFramework/MixedLanguageProtocol",
            ])
            
            assertNoVariantsForRenderHierarchy(reference, context) // Same breadcrumbs in both languages
        }
        do {
            let reference = try XCTUnwrap(context.knownPages.first(where: { $0.path == "\(moduleReference.path)/MixedLanguageProtocol" }))
            XCTAssertEqual(reference.sourceLanguages.count, 2, "Symbol has 2 language representations")
            
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .swift)?.map(\.path), [
                "/documentation/MixedLanguageFramework",
            ])
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .objectiveC)?.map(\.path), [
                "/documentation/MixedLanguageFramework",
            ])
            
            assertNoVariantsForRenderHierarchy(reference, context) // Same breadcrumbs in both languages
        }
    }
    
    // MARK: Test helpers
    
    private func assertNoVariantsForRenderHierarchy(
        _ reference: ResolvedTopicReference,
        _ context: DocumentationContext,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var hierarchyTranslator = RenderHierarchyTranslator(context: context)
        let hierarchyVariants = hierarchyTranslator.visitSymbol(reference)
        
        XCTAssertNotNil(hierarchyVariants.defaultValue, "Should always have default breadcrumbs", file: file, line: line)
        XCTAssert(hierarchyVariants.variants.isEmpty, "No need for variants when value is same in Swift and Objective-C", file: file, line: line)
    }
    
    private func assertHasSomeVariantsForRenderHierarchy(
        _ reference: ResolvedTopicReference,
        _ context: DocumentationContext,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var hierarchyTranslator = RenderHierarchyTranslator(context: context)
        let hierarchyVariants = hierarchyTranslator.visitSymbol(reference)
        
        XCTAssertNotNil(hierarchyVariants.defaultValue, "Should always have default breadcrumbs", file: file, line: line)
        XCTAssertFalse(hierarchyVariants.variants.isEmpty, "Either language needs a variant when value is different in Swift and Objective-C", file: file, line: line)
    }
}
