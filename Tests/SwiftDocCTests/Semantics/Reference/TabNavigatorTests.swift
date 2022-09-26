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

class TabNavigatorTests: XCTestCase {
    func testNoTabs() throws {
        let (renderBlockContent, problems, tabNavigator) = try parseDirective(TabNavigator.self) {
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
    
    func testEmptyTab() throws {
        let (renderBlockContent, problems, tabNavigator) = try parseDirective(TabNavigator.self) {
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
    
    func testInvalidParametersAndContent() throws {
        let (renderBlockContent, problems, tabNavigator) = try parseDirective(TabNavigator.self) {
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
    
    func testNestedStructuredMarkup() throws {
        let (renderBlockContent, problems, tabNavigator) = try parseDirective(TabNavigator.self) {
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
                }
            }
            """
        }
        
        XCTAssertNotNil(tabNavigator)
        XCTAssertEqual(problems, [])
        
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
