/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@testable import SwiftDocC
import SymbolKit
import XCTest

class SemaToRenderNodeDictionaryDataTests: XCTestCase {
    func testBaseRenderNodeFromDictionaryData() throws {
        let (_, context) = try testBundleAndContext(named: "DictionaryData")
        
        let expectedPageUSRsAndLangs: [String : Set<SourceLanguage>] = [
            // Artist dictionary - ``Artist``:
            "data:test:Artist": [.data],
            
            // Genre string type - ``Genre``:
            "data:test:Genre": [.data],
            
            // Module - ``DictionaryData``:
            "DictionaryData": [.data, .swift, .objectiveC],
            
            // ObjC class - ``FooObjC``:
            "c:FooObjC": [.objectiveC],
            
            // Swift class - ``FooSwift``:
            "s:FooSwift": [.swift],
            
            // Month dictionary - ``Month``:
            "data:test:Month": [.data],
        ]
        
        let expectedPageUSRs: Set<String> = Set(expectedPageUSRsAndLangs.keys)
        
        let expectedNonpageUSRs: Set<String> = [
            // Name string field - ``name``:
            "data:test:Artist@name",
            
            // Genre string field - ``genre``:
            "data:test:Artist@genre",
            
            // Month of birth string field - ``monthOfBirth``:
            "data:test:Artist@monthOfBirth",
            
            // Age integer field - ``age``:
            "data:test:Artist@age",
        ]
        
        // Verify we have the right number of cached nodes.
        XCTAssertEqual(context.documentationCache.count, expectedPageUSRsAndLangs.count + expectedNonpageUSRs.count)
        
        // Verify each node matches the expectations.
        for (_, documentationNode) in context.documentationCache {
            let symbolUSR = try XCTUnwrap((documentationNode.semantic as? Symbol)?.externalID)
            
            if documentationNode.kind.isPage {
                XCTAssertTrue(
                    expectedPageUSRs.contains(symbolUSR),
                    "Unexpected symbol page: \(symbolUSR)"
                )
                XCTAssertEqual(documentationNode.availableSourceLanguages, expectedPageUSRsAndLangs[symbolUSR])
            } else {
                XCTAssertTrue(
                    expectedNonpageUSRs.contains(symbolUSR),
                    "Unexpected symbol non-page: \(symbolUSR)"
                )
            }
        }
    }

    func testFrameworkRenderNodeHasExpectedContent() throws {
        let outputConsumer = try renderNodeConsumer(for: "DictionaryData")
        let frameworkRenderNode = try outputConsumer.renderNode(
            withIdentifier: "DictionaryData"
        )
        
        assertExpectedContent(
            frameworkRenderNode,
            sourceLanguage: "swift",  // Swift wins default when multiple languages present
            symbolKind: "module",
            title: "DictionaryData",
            navigatorTitle: nil,
            abstract: "DictionaryData framework.",
            declarationTokens: nil,
            discussionSection: ["Root level discussion."],
            topicSectionIdentifiers: [
                // Data symbols are present, but FooObjC is missing from swift rendering
                "doc://org.swift.docc.DictionaryData/documentation/DictionaryData/Artist",
                "doc://org.swift.docc.DictionaryData/documentation/DictionaryData/Genre",
                "doc://org.swift.docc.DictionaryData/documentation/DictionaryData/FooSwift",
                "doc://org.swift.docc.DictionaryData/documentation/DictionaryData/Month",
            ],
            referenceTitles: [
                "Artist",
                "DictionaryData",
                "FooObjC",
                "FooSwift",
                "Genre",
                "Month"
            ],
            referenceFragments: [
                "object Artist",
                "string Genre",
                "string Month"
            ],
            failureMessage: { fieldName in
                "'DictionaryData' module has unexpected content for '\(fieldName)'."
            }
        )
        
        let objcFrameworkNode = try renderNodeApplying(variant: "occ", to: frameworkRenderNode)
        
        assertExpectedContent(
            objcFrameworkNode,
            sourceLanguage: "occ",
            symbolKind: "module",
            title: "DictionaryData",
            navigatorTitle: nil,
            abstract: "DictionaryData framework.",
            declarationTokens: nil,
            discussionSection: ["Root level discussion."],
            topicSectionIdentifiers: [
                // Data symbols are present, but FooSwift is missing from ObjC rendering
                "doc://org.swift.docc.DictionaryData/documentation/DictionaryData/Artist",
                "doc://org.swift.docc.DictionaryData/documentation/DictionaryData/Genre",
                "doc://org.swift.docc.DictionaryData/documentation/DictionaryData/FooObjC",
                "doc://org.swift.docc.DictionaryData/documentation/DictionaryData/Month",
            ],
            referenceTitles: [
                "Artist",
                "DictionaryData",
                "FooObjC",
                "FooSwift",
                "Genre",
                "Month"
            ],
            referenceFragments: [
                "object Artist",
                "string Genre",
                "string Month"
            ],
            failureMessage: { fieldName in
                "'DictionaryData' module has unexpected content for '\(fieldName)'."
            }
        )
    }
    
    func testDictionaryRenderNodeHasExpectedContent() throws {
        let outputConsumer = try renderNodeConsumer(for: "DictionaryData")
        let artistRenderNode = try outputConsumer.renderNode(withIdentifier: "data:test:Artist")
        let monthRenderNode = try outputConsumer.renderNode(withIdentifier: "data:test:Month")
        
        assertExpectedContent(
            artistRenderNode,
            sourceLanguage: "data",
            symbolKind: "dictionary",
            title: "Artist",
            navigatorTitle: "Artist",
            abstract: "Artist object.",
            declarationTokens: [
                "object ",
                "Artist",
            ],
            discussionSection: [
                "The artist discussion.",
            ],
            topicSectionIdentifiers: [],
            referenceTitles: [
                "Artist",
                "DictionaryData",
                "Genre",
            ],
            referenceFragments: [
                "object Artist",
                "string Genre",
            ],
            failureMessage: { fieldName in
                "'Artist' symbol has unexpected content for '\(fieldName)'."
            }
        )
        
        guard let propertiesSection = (artistRenderNode.primaryContentSections[1] as? PropertiesRenderSection) else {
            XCTFail("Second primary content section not a render section")
            return
        }
        
        XCTAssertEqual(propertiesSection.kind, .properties)
        XCTAssertEqual(propertiesSection.items.count, 4)
        
        let ageProperty = propertiesSection.items[0]
        XCTAssertEqual(ageProperty.name, "age")
        XCTAssertTrue(ageProperty.deprecated ?? false)
        var attributeTitles = ageProperty.attributes?.map{$0.title.lowercased()}.sorted() ?? []
        XCTAssertEqual(attributeTitles, ["maximum", "minimum"])
        
        let genreProperty = propertiesSection.items[1]
        XCTAssertEqual(genreProperty.name, "genre")
        XCTAssertTrue(genreProperty.readOnly ?? false)
        attributeTitles = genreProperty.attributes?.map{$0.title.lowercased()}.sorted() ?? []
        XCTAssertEqual(attributeTitles, ["default value", "possible values"])
        
        let monthProperty = propertiesSection.items[2]
        XCTAssertEqual(monthProperty.name, "monthOfBirth")
        XCTAssertNotNil(monthProperty.typeDetails)
        if let details = monthProperty.typeDetails {
            XCTAssertEqual(details.count, 2)
            XCTAssertEqual(details[0].baseType, "integer")
            XCTAssertEqual(details[1].baseType, "string")
        }
        attributeTitles = monthProperty.attributes?.map{$0.title.lowercased()}.sorted() ?? []
        XCTAssertEqual(attributeTitles, ["possible types"])
        monthProperty.attributes?.forEach { attribute in
            if case let .allowedTypes(decls) = attribute {
                XCTAssertEqual(decls.count, 2)
                XCTAssertEqual(decls[0][0].text, "integer")
                XCTAssertEqual(decls[1][0].text, "string")
            }
        }
        
        let nameProperty = propertiesSection.items[3]
        XCTAssertEqual(nameProperty.name, "name")
        XCTAssertTrue(nameProperty.required ?? false)
        XCTAssert((nameProperty.attributes ?? []).isEmpty)
    }
    
    func testTypeRenderNodeHasExpectedContent() throws {
        let outputConsumer = try renderNodeConsumer(for: "DictionaryData")
        let genreRenderNode = try outputConsumer.renderNode(withIdentifier: "data:test:Genre")
        
        let type1 = DeclarationRenderSection.Token(fragment: SymbolGraph.Symbol.DeclarationFragments.Fragment(kind: .text, spelling: "string", preciseIdentifier: nil), identifier: nil)
        let type2 = DeclarationRenderSection.Token(fragment: SymbolGraph.Symbol.DeclarationFragments.Fragment(kind: .text, spelling: "GENCODE", preciseIdentifier: nil), identifier: nil)
        
        assertExpectedContent(
            genreRenderNode,
            sourceLanguage: "data",
            symbolKind: "typealias",
            title: "Genre",
            navigatorTitle: nil,
            abstract: nil,
            attributes: [.maximumLength("40"), .allowedTypes([[type1], [type2]]), .allowedValues(["Classic Rock", "Folk", "null"])],
            declarationTokens: [
                "string ",
                "Genre"
            ],
            discussionSection: nil,
            topicSectionIdentifiers: [],
            referenceTitles: [
                "Artist",
                "DictionaryData",
                "Genre",
            ],
            referenceFragments: [
                "object Artist",
                "string Genre",
            ],
            failureMessage: { fieldName in
                "'Genre' symbol has unexpected content for '\(fieldName)'."
            }
        )
    }

}
