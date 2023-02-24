/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
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
        ]
        
        let expectedPageUSRs: Set<String> = Set(expectedPageUSRsAndLangs.keys)
        
        let expectedNonpageUSRs: Set<String> = [
            // Name string type - ``Name``:
            "data:test:Artist@name",
            
            // Genre string type - ``Genre``:
            "data:test:Artist@genre",
            
            // Age integer type - ``Age``:
            "data:test:Artist@age",
        ]
        
        // Verify we have the right number of cached nodes.
        XCTAssertEqual(context.documentationCache.values.count, expectedPageUSRsAndLangs.count + expectedNonpageUSRs.count)
        
        // Verify each node matches the expectations.
        for documentationNode in context.documentationCache.values {
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
            sourceLanguage: "swift",  // Swift wins default when multiple langauges present
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
            ],
            referenceTitles: [
                "Artist",
                "DictionaryData",
                "FooObjC",
                "FooSwift",
                "Genre",
            ],
            referenceFragments: [
                "object Artist",
                "string Genre",
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
            ],
            referenceTitles: [
                "Artist",
                "DictionaryData",
                "FooObjC",
                "FooSwift",
                "Genre",
            ],
            referenceFragments: [
                "object Artist",
                "string Genre",
            ],
            failureMessage: { fieldName in
                "'DictionaryData' module has unexpected content for '\(fieldName)'."
            }
        )
    }
    
    func testDictionaryRenderNodeHasExpectedContent() throws {
        let outputConsumer = try renderNodeConsumer(for: "DictionaryData")
        let artistRenderNode = try outputConsumer.renderNode(withIdentifier: "data:test:Artist")
        
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
        XCTAssertEqual(propertiesSection.items.count, 3)
        
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
        
        let nameProperty = propertiesSection.items[2]
        XCTAssertEqual(nameProperty.name, "name")
        XCTAssertTrue(nameProperty.required ?? false)
        XCTAssert((nameProperty.attributes ?? []).isEmpty)
    }
}
