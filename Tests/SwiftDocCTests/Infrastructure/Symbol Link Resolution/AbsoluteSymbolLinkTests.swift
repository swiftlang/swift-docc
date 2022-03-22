/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class AbsoluteSymbolLinkTests: XCTestCase {
    func testCreationOfValidLinks() throws {
        let validLinks = [
            "doc://org.swift.ShapeKit/documentation/ShapeKit",
            "doc://org.swift.ShapeKit/documentation/ShapeKit/ParentType/Test-swift.class/",
            "doc://org.swift.ShapeKit/documentation/ShapeKit/ParentType/Test-swift.class/testFunc()-k2k9d",
        ]
        
        let expectedLinkDescriptions = [
            """
            {
                catalogID: 'org.swift.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'ShapeKit', suffix: (none)),
                representsModule: true,
                basePathComponents: []
            }
            """,
            """
            {
                catalogID: 'org.swift.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'ParentType', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'Test', suffix: (kind: 'swift.class'))]
            }
            """,
            """
            {
                catalogID: 'org.swift.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'ParentType', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'Test', suffix: (kind: 'swift.class')), (name: 'testFunc()', suffix: (idHash: 'k2k9d'))]
            }
            """,
        ]
        
        let absoluteSymbolLinks = validLinks.compactMap(AbsoluteSymbolLink.init(string:))
        
        XCTAssertEqual(absoluteSymbolLinks.count, expectedLinkDescriptions.count)
        
        for (absoluteSymbolLink, expectedDescription) in zip(absoluteSymbolLinks, expectedLinkDescriptions) {
            XCTAssertEqual(absoluteSymbolLink.description, expectedDescription)
        }
    }
    
    func testCreationOfInvalidLinkWithBadScheme() {
        XCTAssertNil(
            AbsoluteSymbolLink(string: "dc://org.swift.ShapeKit/documentation/ShapeKit")
        )
        
        XCTAssertNil(
            AbsoluteSymbolLink(string: "http://org.swift.ShapeKit/documentation/ShapeKit")
        )
        
        XCTAssertNil(
            AbsoluteSymbolLink(string: "https://org.swift.ShapeKit/documentation/ShapeKit")
        )
    }
    
    func testCreationOfInvalidLinkWithoutDocumentationPath() {
        XCTAssertNil(
            AbsoluteSymbolLink(string: "doc://org.swift.ShapeKit/tutorials/ShapeKit")
        )
        
        XCTAssertNil(
            AbsoluteSymbolLink(string: "doc://org.swift.ShapeKit/ShapeKit")
        )
    }
    
    func testCreationOfInvalidLinkWithNoCatalogID() {
        XCTAssertNil(
            AbsoluteSymbolLink(string: "doc:///documentation/ShapeKit")
        )
        XCTAssertNil(
            AbsoluteSymbolLink(string: "doc:/documentation/ShapeKit")
        )
    }
    
    func testCreationOfInvalidLinkWithBadSuffix() {
        XCTAssertNil(
            // Empty suffix
            AbsoluteSymbolLink(string: "doc://org.swift.ShapeKit/ShapeKit/ParentType/Test-swift.class/testFunc()-")
        )
        
        XCTAssertNil(
            // Empty suffix
            AbsoluteSymbolLink(string: "doc://org.swift.ShapeKit/ShapeKit/ParentType/Test-/testFunc()")
        )
        
        XCTAssertNil(
            // Empty suffix
            AbsoluteSymbolLink(string: "doc://org.swift.ShapeKit/ShapeKit/ParentType-/Test/testFunc()")
        )
        
        XCTAssertNil(
            // Empty suffix
            AbsoluteSymbolLink(string: "doc://org.swift.ShapeKit/ShapeKit-/ParentType/Test/testFunc()")
        )
        
        XCTAssertNil(
            // Invalid type
            AbsoluteSymbolLink(string: "doc://org.swift.ShapeKit/ShapeKit/ParentType/Test-swift.class/testFunc()-swift.funny-1s4Rt")
        )
        
        XCTAssertNil(
            // Invalid type
            AbsoluteSymbolLink(string: "doc://org.swift.ShapeKit/ShapeKit/ParentType/Test-swift.clss-5f7h9/testFunc()")
        )
    }
    
    func testCreationOfValidLinksFromRenderNode() throws {
        let symbolJSON = try String(contentsOf: Bundle.module.url(
            forResource: "symbol-with-automatic-see-also-section", withExtension: "json",
            subdirectory: "Converter Fixtures")!)

        let renderNode = try RenderNodeTransformer(renderNodeData: symbolJSON.data(using: .utf8)!)
        
        let references = Array(renderNode.renderNode.references.keys).sorted()
        
        let absoluteSymbolLinks = references.map(AbsoluteSymbolLink.init(string:))
        let absoluteSymbolLinkDescriptions = absoluteSymbolLinks.map(\.?.description)
        
        let expectedDescriptions: [String?] = [
            // doc://org.swift.docc.example/documentation/MyKit
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyKit', suffix: (none)),
                representsModule: true,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit-Basics: (This is an article link)
            nil,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass/init(_:)-3743d:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'init(_:)', suffix: (idHash: '3743d'))]
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass/init(_:)-98u07:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'init(_:)', suffix: (idHash: '98u07'))]
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction():
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'myFunction()', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/YourClass:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'YourClass', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/Reference-From-Automatic-SeeAlso-Section-Only:
            nil,
            // doc://org.swift.docc.example/documentation/Reference-In-Automatic-SeeAlso-And-Fragments:
            nil,
            // doc://org.swift.docc.example/tutorials/TechnologyX/Tutorial: (Tutorials link):
            nil,
            // doc://org.swift.docc.example/tutorials/TechnologyX/Tutorial2:
            nil,
            // doc://org.swift.docc.example/tutorials/TechnologyX/Tutorial4:
            nil,
        ]
        
        for (index, expectedDescription) in expectedDescriptions.enumerated() {
            XCTAssertEqual(
                absoluteSymbolLinkDescriptions[index],
                expectedDescription,
                """
                Failed to correctly construct link from '\(references[index])'
                """
            )
        }
    }
    
    func testCompileSymbolGraphAndValidateLinks() throws {
        let (url, _, context) = try testCatalogAndContext(
            copying: "TestCatalog",
            excludingPaths: [],
            codeListings: [:]
        )
        defer { try? FileManager.default.removeItem(at: url) }
        let expectedDescriptions = [
            // doc://org.swift.docc.example/documentation/FillIntroduced:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'FillIntroduced', suffix: (none)),
                representsModule: true,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/FillIntroduced/iOSMacOSOnly():
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'iOSMacOSOnly()', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/FillIntroduced/iOSOnlyDeprecated():
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'iOSOnlyDeprecated()', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/FillIntroduced/iOSOnlyIntroduced():
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'iOSOnlyIntroduced()', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/FillIntroduced/macCatalystOnlyDeprecated():
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'macCatalystOnlyDeprecated()', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/FillIntroduced/macCatalystOnlyIntroduced():
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'macCatalystOnlyIntroduced()', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/FillIntroduced/macOSOnlyDeprecated():
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'macOSOnlyDeprecated()', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/FillIntroduced/macOSOnlyIntroduced():
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'macOSOnlyIntroduced()', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyKit', suffix: (none)),
                representsModule: true,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-33vaw:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'init()', suffix: (idHash: '33vaw'))]
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-3743d:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'init()', suffix: (idHash: '3743d'))]
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction():
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'myFunction()', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyProtocol:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/globalFunction(_:considering:):
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'globalFunction(_:considering:)', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideKit', suffix: (none)),
                representsModule: true,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/NonExistent/UncuratedClass:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'NonExistent', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'UncuratedClass', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass/Element:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'Element', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass/Element/inherited():
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'Element', suffix: (none)), (name: 'inherited()', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass/Value(_:):
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'Value(_:)', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass/init():
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'init()', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass/myFunction():
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'myFunction()', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass/path:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'path', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass/url:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'url', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideProtocol:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideProtocol/func()-2dxqn:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'func()', suffix: (idHash: '2dxqn'))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideProtocol/func()-6ijsi:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'func()', suffix: (idHash: '6ijsi'))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/UncuratedClass/angle:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'UncuratedClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'angle', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/Test:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'Test',
                topLevelSymbol: (name: 'Test', suffix: (none)),
                representsModule: true,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/Test/FirstGroup:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'Test',
                topLevelSymbol: (name: 'FirstGroup', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/Test/FirstGroup/MySnippet:
            """
            {
                catalogID: 'org.swift.docc.example',
                module: 'Test',
                topLevelSymbol: (name: 'FirstGroup', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'MySnippet', suffix: (none))]
            }
            """,
        ]
        XCTAssertEqual(expectedDescriptions.count, context.symbolIndex.count)
        
        let validatedSymbolLinkDescriptions = context.symbolIndex.values
            .map(\.reference.url.absoluteString)
            .sorted()
            .compactMap(AbsoluteSymbolLink.init(string:))
            .map(\.description)
        
        XCTAssertEqual(validatedSymbolLinkDescriptions.count, context.symbolIndex.count)
        for (symbolLinkDescription, expectedDescription) in zip(validatedSymbolLinkDescriptions, expectedDescriptions) {
            XCTAssertEqual(symbolLinkDescription, expectedDescription)
        }
    }
    
    func testCompileOverloadedSymbolGraphAndValidateLinks() throws {
        let (url, _, context) = try testCatalogAndContext(
            copying: "OverloadedSymbols",
            excludingPaths: [],
            codeListings: [:]
        )
        defer { try? FileManager.default.removeItem(at: url) }
        
        let expectedDescriptions = [
            // doc://com.shapes.ShapeKit/documentation/ShapeKit:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'ShapeKit', suffix: (none)),
                representsModule: true,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedByCaseStruct:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedByCaseStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedByCaseStruct/ThirdTestMemberName-5vyx9:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedByCaseStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'ThirdTestMemberName', suffix: (idHash: '5vyx9'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedByCaseStruct/thirdTestMemberNamE-4irjn:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedByCaseStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'thirdTestMemberNamE', suffix: (idHash: '4irjn'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedByCaseStruct/thirdTestMemberName-8x5kx:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedByCaseStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'thirdTestMemberName', suffix: (idHash: '8x5kx'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedByCaseStruct/thirdtestMemberName-u0gl:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedByCaseStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'thirdtestMemberName', suffix: (idHash: 'u0gl'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedEnum', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-swift.enum.case:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedEnum', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'firstTestMemberName(_:)', suffix: (kind: 'swift.enum.case'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-swift.method-14g8s:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedEnum', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'firstTestMemberName(_:)', suffix: (kind: 'swift.method', idHash: '14g8s'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-swift.method-14ife:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedEnum', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'firstTestMemberName(_:)', suffix: (kind: 'swift.method', idHash: '14ife'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-swift.method-14ob0:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedEnum', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'firstTestMemberName(_:)', suffix: (kind: 'swift.method', idHash: '14ob0'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-swift.method-4ja8m:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedEnum', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'firstTestMemberName(_:)', suffix: (kind: 'swift.method', idHash: '4ja8m'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-swift.method-88rbf:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedEnum', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'firstTestMemberName(_:)', suffix: (kind: 'swift.method', idHash: '88rbf'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedParentStruct-1jr3p:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedParentStruct', suffix: (idHash: '1jr3p')),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedParentStruct-1jr3p/fifthTestMember-swift.type.property:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedParentStruct', suffix: (idHash: '1jr3p')),
                representsModule: false,
                basePathComponents: [(name: 'fifthTestMember', suffix: (kind: 'swift.type.property'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-1h173:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'fourthTestMemberName(test:)', suffix: (idHash: '1h173'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-8iuz7:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'fourthTestMemberName(test:)', suffix: (idHash: '8iuz7'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-91hxs:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'fourthTestMemberName(test:)', suffix: (idHash: '91hxs'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-961zx:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'fourthTestMemberName(test:)', suffix: (idHash: '961zx'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedStruct:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedStruct/secondTestMemberName-swift.property:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'secondTestMemberName', suffix: (kind: 'swift.property'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedStruct/secondTestMemberName-swift.type.property:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'secondTestMemberName', suffix: (kind: 'swift.type.property'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/RegularParent:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'RegularParent', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/RegularParent/FourthMember:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'RegularParent', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'FourthMember', suffix: (none))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/RegularParent/firstMember:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'RegularParent', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'firstMember', suffix: (none))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/RegularParent/secondMember(first:second:):
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'RegularParent', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'secondMember(first:second:)', suffix: (none))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/RegularParent/thirdMember:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'RegularParent', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'thirdMember', suffix: (none))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/overloadedparentstruct-6a7lx:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'overloadedparentstruct', suffix: (idHash: '6a7lx')),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/overloadedparentstruct-6a7lx/fifthTestMember-swift.property:
            """
            {
                catalogID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'overloadedparentstruct', suffix: (idHash: '6a7lx')),
                representsModule: false,
                basePathComponents: [(name: 'fifthTestMember', suffix: (kind: 'swift.property'))]
            }
            """,
        ]
        XCTAssertEqual(expectedDescriptions.count, context.symbolIndex.count)
        
        let validatedSymbolLinkDescriptions = context.symbolIndex.values
            .map(\.reference.url.absoluteString)
            .sorted()
            .compactMap(AbsoluteSymbolLink.init(string:))
            .map(\.description)
        
        XCTAssertEqual(validatedSymbolLinkDescriptions.count, context.symbolIndex.count)
        for (symbolLinkDescription, expectedDescription) in zip(validatedSymbolLinkDescriptions, expectedDescriptions) {
            XCTAssertEqual(symbolLinkDescription, expectedDescription)
        }
    }
    
    func testLinkComponentStringConversion() throws {
        let (url, _, context) = try testCatalogAndContext(
            copying: "OverloadedSymbols",
            excludingPaths: [],
            codeListings: [:]
        )
        defer { try? FileManager.default.removeItem(at: url) }
        
        let catalogPathComponents = context.symbolIndex.values
            .flatMap(\.reference.pathComponents)
        
        
        catalogPathComponents.forEach { component in
            let symbolLinkComponent = AbsoluteSymbolLink.LinkComponent(string: component)
            // Assert that round-trip conversion doesn't change the string representation
            // of the component
            XCTAssertEqual(symbolLinkComponent?.asLinkComponentString, component)
        }
    }
}
