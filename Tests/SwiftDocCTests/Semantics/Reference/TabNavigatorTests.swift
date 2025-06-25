/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable import SwiftDocC
import Markdown

class TabNavigatorTests: XCTestCase {
    func testNoTabs() async throws {
        let (renderBlockContent, problems, tabNavigator) = try await parseDirective(TabNavigator.self) {
            """
            @TabNavigator
            """
        }
        
        XCTAssertNotNil(tabNavigator)
        
        XCTAssertEqual(
            problems,
            ["1: warning – org.swift.docc.HasAtLeastOne<TabNavigator, Tab>"]
        )
        
        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .tabNavigator(.init(tabs: []))
        )
    }
    
    func testEmptyTab() async throws {
        let (renderBlockContent, problems, tabNavigator) = try await parseDirective(TabNavigator.self) {
            """
            @TabNavigator {
                @Tab("hiya") {
                    
                }
            }
            """
        }
        
        XCTAssertNotNil(tabNavigator)
        XCTAssertEqual(
            problems,
            ["2: warning – org.swift.docc.Tab.HasContent"]
        )
        
        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .tabNavigator(RenderBlockContent.TabNavigator(
                tabs: [RenderBlockContent.TabNavigator.Tab(title: "hiya", content: [])]
            ))
        )
        
    }
    
    func testInvalidParametersAndContent() async throws {
        let (renderBlockContent, problems, tabNavigator) = try await parseDirective(TabNavigator.self) {
            """
            @TabNavigator(tabs: 3) {
                @Tab("hi") {
                    Hello there.
                }
            
                @Tab("hey") {
                    Hey there.
            
                    @TabNavigator(weird: true) {
                        @Tab("bad") {
                            @Unkown {
                                
                            }
                        }
                    }
                }
            }
            """
        }
        
        XCTAssertNotNil(tabNavigator)
        
        XCTAssertEqual(
            problems,
            [
                "1: warning – org.swift.docc.UnknownArgument",
                "9: warning – org.swift.docc.UnknownArgument",
                "11: warning – org.swift.docc.HasOnlyKnownDirectives",
                "11: warning – org.swift.docc.unknownDirective",
            ]
        )
        
        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .tabNavigator(RenderBlockContent.TabNavigator(
                tabs: [
                    RenderBlockContent.TabNavigator.Tab(
                        title: "hi",
                        content: ["Hello there."]
                    ),
                    
                    RenderBlockContent.TabNavigator.Tab(
                        title: "hey",
                        content: [
                            "Hey there.",
                            .tabNavigator(RenderBlockContent.TabNavigator(
                                tabs: [
                                    RenderBlockContent.TabNavigator.Tab(
                                        title: "bad",
                                        content: []
                                    ),
                                ]
                            ))
                        ]
                    ),
                ]
            ))
        )
    }
    
    func testNestedStructuredMarkup() async throws {
        let (renderBlockContent, problems, tabNavigator) = try await parseDirective(TabNavigator.self) {
            """
            @TabNavigator {
                @Tab("hi") {
                    @Row {
                        @Column {
                            Hello!
                        }
            
                        @Column {
                            Hello there!
                        }
                    }
            
                    Hello there.
                }
            
                @Tab("hey") {
                    Hey there.
            
                    @Small {
                        Hey but small.
                    }

                    @Snippet(path: "Snippets/Snippets/MySnippet")
                }
            }
            """
        }
        
        XCTAssertNotNil(tabNavigator)

        // UnresolvedTopicReference warning expected since the reference to the snippet "Snippets/Snippets/MySnippet" 
        // should fail to resolve here and then nothing would be added to the content.
        XCTAssertEqual(
            problems,
            ["23: warning – org.swift.docc.unresolvedTopicReference"]
        )

        
        
        XCTAssertEqual(renderBlockContent.count, 1)
        XCTAssertEqual(
            renderBlockContent.first,
            .tabNavigator(RenderBlockContent.TabNavigator(
                tabs: [
                    RenderBlockContent.TabNavigator.Tab(
                        title: "hi",
                        content: [
                            .row(RenderBlockContent.Row(
                                numberOfColumns: 2,
                                columns: [
                                    RenderBlockContent.Row.Column(
                                        size: 1,
                                        content: ["Hello!"]
                                    ),
                                    
                                    RenderBlockContent.Row.Column(
                                        size: 1,
                                        content: ["Hello there!"]
                                    )
                                ]
                            )),
                            
                            "Hello there.",
                        ]
                    ),
                    
                    RenderBlockContent.TabNavigator.Tab(
                        title: "hey",
                        content: [
                            "Hey there.",
    
                            .small(RenderBlockContent.Small(inlineContent: [.text("Hey but small.")])),
                        ]
                    ),
                ]
            ))
        )
    }
}
