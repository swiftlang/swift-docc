/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable import SwiftDocC
import Markdown

class LinksTests: XCTestCase {
    func testMissingBasicRequirements() throws {
        do {
            let (renderedContent, problems, links) = try parseDirective(Links.self, in: "BookLikeContent") {
                """
                @Links(visualStyle: compactGrid)
                """
            }
            
            XCTAssertNotNil(links)
            
            XCTAssertEqual(
                problems,
                ["1: warning – org.swift.docc.HasExactlyOneUnorderedList<Links, AnyLink>.InvalidContent"]
            )
            
            XCTAssertEqual(renderedContent, [])
        }
        
        do {
            let (renderedContent, problems, links) = try parseDirective(Links.self, in: "BookLikeContent") {
                """
                @Links {
                    - <doc:MyArticle>
                }
                """
            }
            
            XCTAssertNil(links)
            
            XCTAssertEqual(
                problems,
                [
                    "1: warning – org.swift.docc.HasArgument.visualStyle",
                ]
            )
            
            XCTAssertEqual(renderedContent, [])
        }
    }
    
    func testInvalidBodyContent() throws {
        do {
            let (renderedContent, problems, links) = try parseDirective(Links.self, in: "BookLikeContent") {
                """
                @Links(visualStyle: compactGrid) {
                    This is a paragraph of text in 'Links' directive.
                
                    And a second paragraph.
                }
                """
            }
            
            XCTAssertNotNil(links)
            
            XCTAssertEqual(
                problems,
                [
                    "1: warning – org.swift.docc.HasExactlyOneUnorderedList<Links, AnyLink>.InvalidContent",
                    "2: warning – org.swift.docc.HasExactlyOneUnorderedList<Links, AnyLink>.ExtraneousContent",
                    "4: warning – org.swift.docc.HasExactlyOneUnorderedList<Links, AnyLink>.ExtraneousContent",
                ]
            )
            
            XCTAssertEqual(renderedContent, [])
        }
        
        do {
            let (renderedContent, problems, links) = try parseDirective(Links.self, in: "BookLikeContent") {
                """
                @Links(visualStyle: compactGrid) {
                    This is a paragraph of text in 'Links' directive.
                
                    And a second paragraph preceding a valid link:
                
                    - <doc:MyArticle>
                }
                """
            }
            
            XCTAssertNotNil(links)
            
            XCTAssertEqual(
                problems,
                [
                    "2: warning – org.swift.docc.HasExactlyOneUnorderedList<Links, AnyLink>.ExtraneousContent",
                    "4: warning – org.swift.docc.HasExactlyOneUnorderedList<Links, AnyLink>.ExtraneousContent",
                ]
            )
            
            XCTAssertEqual(
                renderedContent,
                [
                    RenderBlockContent.links(RenderBlockContent.Links(
                        style: .compactGrid,
                        items: ["doc://org.swift.docc.Book/documentation/BestBook/MyArticle"]
                    ))
                ]
            )
        }
        
        do {
            let (renderedContent, problems, links) = try parseDirective(Links.self, in: "BookLikeContent") {
                """
                @Links(visualStyle: compactGrid) {
                    - <doc:MyArticle> Link with some trailing content.
                }
                """
            }
            
            XCTAssertNotNil(links)
            
            XCTAssertEqual(
                problems,
                [
                    "2: warning – org.swift.docc.ExtraneousLinksDirectiveItemContent"
                ]
            )
            
            XCTAssertEqual(
                renderedContent,
                [
                    RenderBlockContent.links(RenderBlockContent.Links(
                        style: .compactGrid,
                        items: [
                            "doc://org.swift.docc.Book/documentation/BestBook/MyArticle",
                        ]
                    ))
                ]
            )
        }
    }
    
    func testLinkResolution() throws {
        do {
            let (renderedContent, problems, links) = try parseDirective(Links.self, in: "BookLikeContent") {
                """
                @Links(visualStyle: compactGrid) {
                    - <doc:MyArticle>
                    - <doc:TabNavigatorArticle>
                    - <doc:MyBook>
                    - <doc:UnknownArticle>
                    - <doc:MyArticle>
                }
                """
            }
            
            XCTAssertNotNil(links)
            
            XCTAssertEqual(
                problems,
                ["5: warning – org.swift.docc.unresolvedTopicReference"]
            )
            
            XCTAssertEqual(
                renderedContent,
                [
                    RenderBlockContent.links(RenderBlockContent.Links(
                        style: .compactGrid,
                        items: [
                            "doc://org.swift.docc.Book/documentation/BestBook/MyArticle",
                            "doc://org.swift.docc.Book/documentation/BestBook/TabNavigatorArticle",
                            "doc://org.swift.docc.Book/documentation/MyBook",
                            "doc://org.swift.docc.Book/documentation/BestBook/MyArticle",
                        ]
                    ))
                ]
            )
        }
        
        do {
            let (renderedContent, problems, links) = try parseDirective(Links.self, in: "TestBundle") {
                """
                @Links(visualStyle: compactGrid) {
                    - ``MyKit/MyClass``
                    - ``MyKit/MyClass/myFunction()``
                    - <doc:TestTutorial>
                    - <doc:article2>
                }
                """
            }
            
            XCTAssertNotNil(links)
            
            XCTAssertEqual(problems, [])
            
            XCTAssertEqual(
                renderedContent,
                [
                    RenderBlockContent.links(RenderBlockContent.Links(
                        style: .compactGrid,
                        items: [
                            "doc://org.swift.docc.example/documentation/MyKit/MyClass",
                            "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()",
                            "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial",
                            "doc://org.swift.docc.example/documentation/Test-Bundle/article2",
                        ]
                    ))
                ]
            )
        }
    }
}
