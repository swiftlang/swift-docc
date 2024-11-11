/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import SwiftDocC
import XCTest

class RenderHierarchyTranslatorTests: XCTestCase {
    func test() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let technologyReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/TestOverview", sourceLanguage: .swift)
        
        var translator = RenderHierarchyTranslator(context: context, bundle: bundle)
        let renderHierarchyVariants = translator.visitTutorialTableOfContentsNode(technologyReference)?.hierarchyVariants
        XCTAssertEqual(renderHierarchyVariants?.variants, [], "Unexpected variant hierarchies for tutorial table of content page")
        let renderHierarchy = renderHierarchyVariants?.defaultValue
        
        // Verify that the hierarchy translator has collected all topic references from the hierarchy
        XCTAssertEqual(translator.collectedTopicReferences.sorted(by: { $0.absoluteString <= $1.absoluteString }).map{ $0.absoluteString }, [
            "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial",
            "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB",
            "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Duplicate",
            "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Initiate-ARKit-Plane-Detection",
            "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial2",
            "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial2#Create-a-New-AR-Project",
            "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorialArticle",
            "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorialArticle#A-Section",
            "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorialArticle#This-is-an-H2",
            "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorialArticle#This-is-an-H3",
            "doc://org.swift.docc.example/tutorials/Test-Bundle/TutorialMediaWithSpaces",
            "doc://org.swift.docc.example/tutorials/Test-Bundle/TutorialMediaWithSpaces#Create-a-New-AR-Project",
            "doc://org.swift.docc.example/tutorials/TestOverview",
            "doc://org.swift.docc.example/tutorials/TestOverview/Chapter-1",
        ])
        
        let pending = translator.linkReferences
            .map({ pair -> String in
                return pair.value.title + ", " + pair.value.url
            })
            .sorted()

        // Verify that the hierarchy translator has collected all "fake" references
        // & their titles that need to be added to the node
        XCTAssertEqual(pending, [
            "Check Your Understanding, /tutorials/test-bundle/testtutorial#Check-Your-Understanding",
            "Check Your Understanding, /tutorials/test-bundle/testtutorial2#Check-Your-Understanding",
            "Check Your Understanding, /tutorials/test-bundle/tutorialmediawithspaces#Check-Your-Understanding",
        ])
        
        guard case .tutorials(let technologyHierarchy)? = renderHierarchy else {
            XCTFail("Unexpected hierarchy type")
            return
        }

        XCTAssertEqual(technologyHierarchy.modules?.count, 1)
        
        guard let modules = technologyHierarchy.modules, !modules.isEmpty else {
            XCTFail("Could not find modules")
            return
        }
        let chapter = modules[0]
        
        XCTAssertEqual(chapter.reference.identifier, "doc://org.swift.docc.example/tutorials/TestOverview/Chapter-1")
        
        XCTAssertEqual(chapter.tutorials.count, 4)
        
        let tutorial = chapter.tutorials[0]
        
        XCTAssertEqual(tutorial.reference.identifier, "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial")
        
        XCTAssertEqual(tutorial.landmarks.count, 4)
        
        let section1 = tutorial.landmarks[0]
        let section2 = tutorial.landmarks[1]
        let section3 = tutorial.landmarks[2]
        let assessments = tutorial.landmarks[3]
        
        XCTAssertEqual(section1.reference.identifier, "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB")
        XCTAssertEqual(section2.reference.identifier, "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Initiate-ARKit-Plane-Detection")
        XCTAssertEqual(section3.reference.identifier, "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Duplicate")
        XCTAssertEqual(assessments.reference.identifier, "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Check-Your-Understanding")
    }
    
    func testMultiplePaths() throws {
        // Curate "TestTutorial" under MyKit as well as TechnologyX.
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
            let myKitURL = root.appendingPathComponent("documentation/mykit.md")
            let text = try String(contentsOf: myKitURL).replacingOccurrences(of: "## Topics", with: """
            ## Topics

            ### Tutorials
             - <doc:/tutorials/Test-Bundle/TestTutorial>
             - <doc:/tutorials/Test-Bundle/TestTutorial2>
            """)
            try text.write(to: myKitURL, atomically: true, encoding: .utf8)
        }
        
        // Get a translated render node
        let identifier = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift)
        let node = try context.entity(with: identifier)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: identifier)
        let renderNode = translator.visit(node.semantic) as! RenderNode

        guard case .tutorials(let hierarchy) = renderNode.hierarchyVariants.defaultValue else {
            XCTFail("Did not find the node hierarchy")
            return
        }
        
        XCTAssertEqual(hierarchy.paths.sorted(by: { $0.count < $1.count }), [
            [
                "doc://org.swift.docc.example/documentation/MyKit",
            ],
            [
                "doc://org.swift.docc.example/documentation/MyKit",
                "doc://org.swift.docc.example/documentation/Test-Bundle/article",
            ],
            [
                "doc://org.swift.docc.example/tutorials/TestOverview",
                "doc://org.swift.docc.example/tutorials/TestOverview/$volume",
                "doc://org.swift.docc.example/tutorials/TestOverview/Chapter-1",
            ],
        ])
    }
    
    func testLanguageSpecificHierarchies() throws {
        let (bundle, context) = try testBundleAndContext(named: "GeometricalShapes")
        let moduleReference = try XCTUnwrap(context.soleRootModuleReference)
        
        // An inner function to assert the rendered hierarchy values for a given reference
        func assertExpectedHierarchies(
            for reference: ResolvedTopicReference,
            expectedSwiftPaths: [String]?,
            expectedObjectiveCPaths: [String]?,
            file: StaticString = #filePath,
            line: UInt = #line
        ) throws {
            let documentationNode = try context.entity(with: reference)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let renderNode = try XCTUnwrap(translator.visit(documentationNode.semantic) as? RenderNode, file: file, line: line)
            
            if let expectedSwiftPaths {
                guard case .reference(let defaultHierarchy) = renderNode.hierarchyVariants.defaultValue else {
                    XCTFail("Unexpectedly found `.tutorials` main hierarchy for symbol", file: file, line: line)
                    return
                }
                XCTAssertEqual(defaultHierarchy.paths.count, 1, "Unexpectedly found \(defaultHierarchy.paths.count) symbol paths", file: file, line: line)
                XCTAssertEqual(defaultHierarchy.paths.first, expectedSwiftPaths, file: file, line: line)
            } else {
                XCTAssertNil(renderNode.hierarchyVariants.defaultValue, "Unexpectedly found main hierarchy", file: file, line: line)
            }
                
            if let expectedObjectiveCPaths {
                let variants = try XCTUnwrap(renderNode.hierarchyVariants.variants.first, file: file, line: line)
                let patch = try XCTUnwrap(variants.patch.first, file: file, line: line)
                guard case .replace(value: .reference(let variantHierarchy)) = patch else {
                    XCTFail("Unexpectedly found `.tutorials` variant hierarchy for symbol", file: file, line: line)
                    return
                }
                XCTAssertEqual(variantHierarchy.paths.count, 1, "Unexpectedly found \(variantHierarchy.paths.count) symbol paths", file: file, line: line)
                XCTAssertEqual(variantHierarchy.paths.first, expectedObjectiveCPaths, file: file, line: line)
            } else {
                XCTAssertNil(renderNode.hierarchyVariants.variants.first, "Unexpectedly found variant hierarchy", file: file, line: line)
            }
        }
        
        // typedef struct {
        //     CGPoint center;
        //     CGFloat radius;
        // } TLACircle NS_SWIFT_NAME(Circle);
        try assertExpectedHierarchies(
            for: moduleReference.appendingPath("Circle/center"),
            expectedSwiftPaths: [
                "doc://GeometricalShapes/documentation/GeometricalShapes",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle",
            ],
            expectedObjectiveCPaths: [
                "doc://GeometricalShapes/documentation/GeometricalShapes",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle", // named TLACircle in Objective-C
            ]
        )

        // extern const TLACircle TLACircleZero NS_SWIFT_NAME(Circle.zero);
        try assertExpectedHierarchies(
            for: moduleReference.appendingPath("Circle/zero"),
            expectedSwiftPaths: [
                "doc://GeometricalShapes/documentation/GeometricalShapes",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle", // The Swift representation is a member
            ],
            expectedObjectiveCPaths: [
                "doc://GeometricalShapes/documentation/GeometricalShapes", // The Objective-C representation is a top-level function
            ]
        )
        
        // BOOL TLACircleIntersects(TLACircle circle, TLACircle otherCircle) NS_SWIFT_NAME(Circle.intersects(self:_:));
        try assertExpectedHierarchies(
            for: moduleReference.appendingPath("Circle/intersects(_:)"),
            expectedSwiftPaths: [
                "doc://GeometricalShapes/documentation/GeometricalShapes",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle", // The Swift representation is a member
            ],
            expectedObjectiveCPaths: [
                "doc://GeometricalShapes/documentation/GeometricalShapes", // The Objective-C representation is a top-level function
            ]
        )
        
        // TLACircle TLACircleMake(CGPoint center, CGFloat radius) NS_SWIFT_UNAVAILABLE("Use 'Circle.init(center:radius:)' instead.");
        try assertExpectedHierarchies(
            for: moduleReference.appendingPath("TLACircleMake"),
            expectedSwiftPaths: nil, // There is no Swift representation
            expectedObjectiveCPaths: [
                "doc://GeometricalShapes/documentation/GeometricalShapes", // The Objective-C representation is a top-level function
            ]
        )
          
        try assertExpectedHierarchies(
            for: moduleReference.appendingPath("Circle/init(center:radius:)"),
            expectedSwiftPaths: [
                "doc://GeometricalShapes/documentation/GeometricalShapes",
                "doc://GeometricalShapes/documentation/GeometricalShapes/Circle", // The Swift representation is a member
            ],
            expectedObjectiveCPaths: nil // There is no Objective-C representation
        )
    }
}
