/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class PathHierarchyBasedLinkResolverTests: XCTestCase {
    
    func testOverloadedSymbolsWithOverloadGroups() async throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)
        
        let context = try await loadFromDisk(catalogName: "OverloadedSymbols")
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        
        // Returns nil for all non-overload groups
        for reference in context.knownIdentifiers {
            let node = try context.entity(with: reference)
            guard node.symbol?.isOverloadGroup != true else { continue }
            
            XCTAssertNil(context.linkResolver.localResolver.overloads(ofGroup: reference), "Unexpectedly found overloads for non-overload group \(reference.path)" )
        }
        
        let firstOverloadGroup  = moduleReference.appendingPath("OverloadedEnum/firstTestMemberName(_:)-8v5g7")
        let secondOverloadGroup = moduleReference.appendingPath("OverloadedProtocol/fourthTestMemberName(test:)")
        
        XCTAssertEqual(context.linkResolver.localResolver.overloads(ofGroup: firstOverloadGroup)?.map(\.path).sorted(), [
            "/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-14g8s",
            "/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-14ife",
            "/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-14ob0",
            "/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-4ja8m",
            "/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-88rbf",
        ])
        
        XCTAssertEqual(context.linkResolver.localResolver.overloads(ofGroup: secondOverloadGroup)?.map(\.path).sorted(), [
            "/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-1h173", 
            "/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-8iuz7",
            "/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-91hxs",
            "/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-961zx",
        ])
    }
}
