/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
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
                bundleID: 'org.swift.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'ShapeKit', suffix: (none)),
                representsModule: true,
                basePathComponents: []
            }
            """,
            """
            {
                bundleID: 'org.swift.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'ParentType', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'Test', suffix: (kind: 'swift.class'))]
            }
            """,
            """
            {
                bundleID: 'org.swift.ShapeKit',
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
    
    func testCreationOfInvalidLinkWithNoBundleID() {
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
                bundleID: 'org.swift.docc.example',
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
                bundleID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass/init(_:)-3743d:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'init(_:)', suffix: (idHash: '3743d'))]
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass/init(_:)-98u07:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'init(_:)', suffix: (idHash: '98u07'))]
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction():
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'myFunction()', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/YourClass:
            """
            {
                bundleID: 'org.swift.docc.example',
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
        let (_, _, context) = try testBundleAndContext(
            copying: "TestBundle",
            excludingPaths: [],
            codeListings: [:]
        )
        let expectedDescriptions = [
            // doc://org.swift.docc.example/documentation/FillIntroduced:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'FillIntroduced', suffix: (none)),
                representsModule: true,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/FillIntroduced/iOSMacOSOnly():
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'iOSMacOSOnly()', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/FillIntroduced/iOSOnlyDeprecated():
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'iOSOnlyDeprecated()', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/FillIntroduced/iOSOnlyIntroduced():
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'iOSOnlyIntroduced()', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/FillIntroduced/macCatalystOnlyDeprecated():
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'macCatalystOnlyDeprecated()', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/FillIntroduced/macCatalystOnlyIntroduced():
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'macCatalystOnlyIntroduced()', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/FillIntroduced/macOSOnlyDeprecated():
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'macOSOnlyDeprecated()', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/FillIntroduced/macOSOnlyIntroduced():
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'FillIntroduced',
                topLevelSymbol: (name: 'macOSOnlyIntroduced()', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyKit', suffix: (none)),
                representsModule: true,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-33vaw:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'init()', suffix: (idHash: '33vaw'))]
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-3743d:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'init()', suffix: (idHash: '3743d'))]
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction():
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'myFunction()', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/MyProtocol:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'MyProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/MyKit/globalFunction(_:considering:):
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'MyKit',
                topLevelSymbol: (name: 'globalFunction(_:considering:)', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideKit', suffix: (none)),
                representsModule: true,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass/Element:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'Element', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass/Element/inherited():
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'Element', suffix: (none)), (name: 'inherited()', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass/Value(_:):
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'Value(_:)', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass/init():
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'init()', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass/myFunction():
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'myFunction()', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass/path:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'path', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideClass/url:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'url', suffix: (none))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideProtocol:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideProtocol/func()-2dxqn:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'func()', suffix: (idHash: '2dxqn'))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/SideProtocol/func()-6ijsi:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'SideProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'func()', suffix: (idHash: '6ijsi'))]
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/UncuratedClass:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'UncuratedClass', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://org.swift.docc.example/documentation/SideKit/UncuratedClass/angle:
            """
            {
                bundleID: 'org.swift.docc.example',
                module: 'SideKit',
                topLevelSymbol: (name: 'UncuratedClass', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'angle', suffix: (none))]
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
        let (_, _, context) = try testBundleAndContext(
            copying: "OverloadedSymbols",
            excludingPaths: [],
            codeListings: [:]
        )
        
        var expectedDescriptions = [
            // doc://com.shapes.ShapeKit/documentation/ShapeKit:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'ShapeKit', suffix: (none)),
                representsModule: true,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedByCaseStruct:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedByCaseStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedByCaseStruct/ThirdTestMemberName-5vyx9:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedByCaseStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'ThirdTestMemberName', suffix: (idHash: '5vyx9'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedByCaseStruct/thirdTestMemberNamE-4irjn:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedByCaseStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'thirdTestMemberNamE', suffix: (idHash: '4irjn'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedByCaseStruct/thirdTestMemberName-8x5kx:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedByCaseStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'thirdTestMemberName', suffix: (idHash: '8x5kx'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedByCaseStruct/thirdtestMemberName-u0gl:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedByCaseStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'thirdtestMemberName', suffix: (idHash: 'u0gl'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedEnum', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-14g8s:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedEnum', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'firstTestMemberName(_:)', suffix: (idHash: '14g8s'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-14ife:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedEnum', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'firstTestMemberName(_:)', suffix: (idHash: '14ife'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-14ob0:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedEnum', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'firstTestMemberName(_:)', suffix: (idHash: '14ob0'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-4ja8m:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedEnum', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'firstTestMemberName(_:)', suffix: (idHash: '4ja8m'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-88rbf:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedEnum', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'firstTestMemberName(_:)', suffix: (idHash: '88rbf'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-swift.enum.case:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedEnum', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'firstTestMemberName(_:)', suffix: (kind: 'swift.enum.case'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedParentStruct-1jr3p:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedParentStruct', suffix: (idHash: '1jr3p')),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedParentStruct-1jr3p/fifthTestMember:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedParentStruct', suffix: (idHash: '1jr3p')),
                representsModule: false,
                basePathComponents: [(name: 'fifthTestMember', suffix: (none))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-1h173:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'fourthTestMemberName(test:)', suffix: (idHash: '1h173'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-8iuz7:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'fourthTestMemberName(test:)', suffix: (idHash: '8iuz7'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-91hxs:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'fourthTestMemberName(test:)', suffix: (idHash: '91hxs'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-961zx:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedProtocol', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'fourthTestMemberName(test:)', suffix: (idHash: '961zx'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedStruct:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedStruct/secondTestMemberName-swift.property:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'secondTestMemberName', suffix: (kind: 'swift.property'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedStruct/secondTestMemberName-swift.type.property:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'OverloadedStruct', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'secondTestMemberName', suffix: (kind: 'swift.type.property'))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/RegularParent:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'RegularParent', suffix: (none)),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/RegularParent/FourthMember:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'RegularParent', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'FourthMember', suffix: (none))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/RegularParent/firstMember:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'RegularParent', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'firstMember', suffix: (none))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/RegularParent/secondMember(first:second:):
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'RegularParent', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'secondMember(first:second:)', suffix: (none))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/RegularParent/thirdMember:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'RegularParent', suffix: (none)),
                representsModule: false,
                basePathComponents: [(name: 'thirdMember', suffix: (none))]
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/overloadedparentstruct-6a7lx:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'overloadedparentstruct', suffix: (idHash: '6a7lx')),
                representsModule: false,
                basePathComponents: []
            }
            """,
            // doc://com.shapes.ShapeKit/documentation/ShapeKit/overloadedparentstruct-6a7lx/fifthTestMember:
            """
            {
                bundleID: 'com.shapes.ShapeKit',
                module: 'ShapeKit',
                topLevelSymbol: (name: 'overloadedparentstruct', suffix: (idHash: '6a7lx')),
                representsModule: false,
                basePathComponents: [(name: 'fifthTestMember', suffix: (none))]
            }
            """,
        ]
        if !LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver {
            // The cache-based resolver redundantly disambiguates these overloads with both kind and hash ...
            for index in 7...11 {
                expectedDescriptions[index] = expectedDescriptions[index].replacingOccurrences(
                    of:   "basePathComponents: [(name: 'firstTestMemberName(_:)', suffix: (idHash: '",
                    with: "basePathComponents: [(name: 'firstTestMemberName(_:)', suffix: (kind: 'swift.method', idHash: '"
                )
            }
            // ... because of the above, the cache-based resolver sort the enum case before the methods
            expectedDescriptions.insert(
                expectedDescriptions.remove(at: 12),
                at: 7
            )
            
            // The cache-based resolver redundantly disambiguates these overloads which already have disambiguated parents.
            expectedDescriptions[14] = expectedDescriptions[14].replacingOccurrences(
                of:   "basePathComponents: [(name: 'fifthTestMember', suffix: (none))]",
                with: "basePathComponents: [(name: 'fifthTestMember', suffix: (kind: 'swift.type.property'))]"
            )
            expectedDescriptions[29] = expectedDescriptions[29].replacingOccurrences(
                of:   "basePathComponents: [(name: 'fifthTestMember', suffix: (none))]",
                with: "basePathComponents: [(name: 'fifthTestMember', suffix: (kind: 'swift.property'))]"
            )
        }
        
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
        let (_, _, context) = try testBundleAndContext(
            copying: "OverloadedSymbols",
            excludingPaths: [],
            codeListings: [:]
        )
        
        let bundlePathComponents = context.symbolIndex.values
            .flatMap(\.reference.pathComponents)
        
        
        bundlePathComponents.forEach { component in
            let symbolLinkComponent = AbsoluteSymbolLink.LinkComponent(string: component)
            // Assert that round-trip conversion doesn't change the string representation
            // of the component
            XCTAssertEqual(symbolLinkComponent?.asLinkComponentString, component)
        }
    }
}
