/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
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
        let renderHierarchy = translator.visitTechnologyNode(technologyReference)?.hierarchy

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
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: identifier, source: nil)
        let renderNode = translator.visit(node.semantic) as! RenderNode

        guard let renderHierarchy = renderNode.hierarchy, case RenderHierarchy.tutorials(let hierarchy) = renderHierarchy else {
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
}
