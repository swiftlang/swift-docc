/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

class ResourcesTests: XCTestCase {
    func testEmpty() throws {
        let source = "@\(Resources.directiveName)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let resources = Resources(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(resources)
        XCTAssertEqual(1, problems.count)
      
        XCTAssertEqual(
            [
                "org.swift.docc.Resources.HasContent",
            ],
            Set(problems.map { $0.diagnostic.identifier })
        )
        
        XCTAssert(problems.map { $0.diagnostic.severity }.allSatisfy { $0 == .warning })
    }
    
    func testValid() throws {
        let source = """
@\(Resources.directiveName) {
   Find the tools and a comprehensive set of resources for creating AR experiences on iOS.

   @\(Tile.DirectiveNames.documentation.rawValue)(destination: "https://www.example.com/documentation/technology") {
      Browse and search detailed API documentation.

      - <doc://org.swift.docc/arkit/augmented_reality_with_the_back_camera>
      - <doc://org.swift.docc/arkit/augmented_reality_with_the_front_camera>
   }

   @\(Tile.DirectiveNames.sampleCode.rawValue)(destination: "https://www.example.com/documentation/technology") {
      Browse and search detailed sample code.

      - <doc://org.swift.docc/arkit/augmented_reality_with_the_back_camera>
      - <doc://org.swift.docc/arkit/augmented_reality_with_the_front_camera>
   }

   @\(Tile.DirectiveNames.downloads.rawValue)(destination: "https://www.example.com/download") {
      Download Xcode 10, which includes the latest tools and SDKs.*
   }

   @\(Tile.DirectiveNames.videos.rawValue)(destination: "https://www.example.com/videos") {
      See AR presentation from WWDC and other events.
   }

   @\(Tile.DirectiveNames.forums.rawValue)(destination: "https://www.example.com/forums") {
      Discuss AR with Apple engineers and other developers.
   }
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let resources = Resources(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(resources)
        XCTAssertTrue(problems.isEmpty, "Unexpected problems: \(problems)")
        
        let expectedDump = """
Resources @1:1-29:2
├─ MarkupContainer (1 element)
├─ Tile @4:4-9:5 identifier: documentation title: 'Documentation' destination: 'https://www.example.com/documentation/technology'
│  └─ MarkupContainer (2 elements)
├─ Tile @11:4-16:5 identifier: sampleCode title: 'Sample Code' destination: 'https://www.example.com/documentation/technology'
│  └─ MarkupContainer (2 elements)
├─ Tile @18:4-20:5 identifier: downloads title: 'Xcode and SDKs' destination: 'https://www.example.com/download'
│  └─ MarkupContainer (1 element)
├─ Tile @22:4-24:5 identifier: videos title: 'Videos' destination: 'https://www.example.com/videos'
│  └─ MarkupContainer (1 element)
└─ Tile @26:4-28:5 identifier: forums title: 'Forums' destination: 'https://www.example.com/forums'
   └─ MarkupContainer (1 element)
"""
        resources.map {
            XCTAssertEqual(expectedDump, $0.dump())
        }
    }

    func testMissingLinksWarning() throws {
        let source = """
@\(Resources.directiveName) {
   Find the tools and a comprehensive set of resources for creating AR experiences on iOS.
   
   @\(Tile.DirectiveNames.documentation.rawValue)(destination: "https://www.example.com/documentation/technology") {
      Browse and search detailed API documentation.
   }

   @\(Tile.DirectiveNames.sampleCode.rawValue)(destination: "https://www.example.com/documentation/technology") {
      Browse and search sample projects.
   }

   @\(Tile.DirectiveNames.downloads.rawValue)(destination: "https://www.example.com/download") {
      Download Xcode 10, which includes the latest tools and SDKs.*
   }

   @\(Tile.DirectiveNames.videos.rawValue)(destination: "https://www.example.com/videos") {
      See AR presentation from WWDC and other events.
   }

   @\(Tile.DirectiveNames.forums.rawValue)(destination: "https://www.example.com/forums") {
      Discuss AR with Apple engineers and other developers.
   }
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let resources = Resources(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(resources)
        XCTAssertFalse(problems.containsErrors)
        
        // Two directives are supposed to have at least one link
        XCTAssertEqual(2, problems.count)
      
        // The two warnings have the same id
        XCTAssertEqual(Set([
            "org.swift.docc.Resources.SampleCode.HasLinks", 
            "org.swift.docc.Resources.Documentation.HasLinks",
            ]),
            Set(problems.map { $0.diagnostic.identifier }))
    }
}
