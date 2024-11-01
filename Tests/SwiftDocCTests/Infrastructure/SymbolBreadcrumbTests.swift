/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class SymbolBreadcrumbTests: XCTestCase {
    func testLanguageSpecificBreadcrumbs() throws {
        let (_, context) = try testBundleAndContext(named: "GeometricalShapes")
        let resolver = try XCTUnwrap(context.linkResolver.localResolver)
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        
        // typedef struct {
        //     CGPoint center;
        //     CGFloat radius;
        // } TLACircle NS_SWIFT_NAME(Circle);
        do {
            let reference = moduleReference.appendingPath("Circle/center")
            
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .swift)?.map(\.path), [
                "/documentation/GeometricalShapes",
                "/documentation/GeometricalShapes/Circle",
            ])
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .objectiveC)?.map(\.path), [
                "/documentation/GeometricalShapes",
                "/documentation/GeometricalShapes/Circle", // named TLACircle in Objective-C
            ])
        }
        
        // extern const TLACircle TLACircleZero NS_SWIFT_NAME(Circle.zero);
        do {
            let reference = moduleReference.appendingPath("Circle/zero")
            
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .swift)?.map(\.path), [
                "/documentation/GeometricalShapes",
                "/documentation/GeometricalShapes/Circle", // The Swift representation is a member
            ])
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .objectiveC)?.map(\.path), [
                "/documentation/GeometricalShapes", // The Objective-C representation is a top-level function
            ])
        }
        
        // BOOL TLACircleIntersects(TLACircle circle, TLACircle otherCircle) NS_SWIFT_NAME(Circle.intersects(self:_:));
        do {
            let reference = moduleReference.appendingPath("Circle/intersects(_:)")
            
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .swift)?.map(\.path), [
                "/documentation/GeometricalShapes",
                "/documentation/GeometricalShapes/Circle", // The Swift representation is a member
            ])
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .objectiveC)?.map(\.path), [
                "/documentation/GeometricalShapes", // The Objective-C representation is a top-level function
            ])
        }

        // TLACircle TLACircleMake(CGPoint center, CGFloat radius) NS_SWIFT_UNAVAILABLE("Use 'Circle.init(center:radius:)' instead.");
        do {
            let reference = moduleReference.appendingPath("TLACircleMake")
            
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .swift)?.map(\.path), nil) // There is no Swift representation
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .objectiveC)?.map(\.path), [
                "/documentation/GeometricalShapes", // The Objective-C representation is a top-level function
            ])
        }
        
        do {
            let reference = moduleReference.appendingPath("Circle/init(center:radius:)")
            
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .swift)?.map(\.path), [
                "/documentation/GeometricalShapes",
                "/documentation/GeometricalShapes/Circle", // The Swift representation is a member
            ])
            XCTAssertEqual(resolver.breadcrumbs(of: reference, in: .objectiveC)?.map(\.path), nil) // There is no Objective-C representation
        }
    }
}
