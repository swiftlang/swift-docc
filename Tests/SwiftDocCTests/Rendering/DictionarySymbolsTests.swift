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

class DictionarySymbolsTests: XCTestCase {
    func testDecodeDictionarySymbol() throws {
        let restSymbolURL = Bundle.module.url(
            forResource: "dictionary-symbol", withExtension: "json",
            subdirectory: "Rendering Fixtures")!
        
        let data = try Data(contentsOf: restSymbolURL)
        let symbol = try RenderNode.decode(fromJSON: data)
        
        //
        // Dictionary
        //
        
        let metadata = symbol.metadata
        XCTAssertEqual(metadata.role , "dictionarySymbol")
        XCTAssertEqual(metadata.roleHeading, "Test Management Command")
        XCTAssertEqual(metadata.symbolKind, "dict")
        XCTAssertEqual(metadata.title, "DeviceRequestCommand")
        
        guard let section = symbol.primaryContentSections.first(where: { section -> Bool in
            return section.kind == .properties
        }) as? PropertiesRenderSection else {
            XCTFail("Plist details section not decoded")
            return
        }
        
        XCTAssertEqual(section.items.map { $0.name }, ["Command", "CommandUUID"])
        XCTAssertEqual(section.items[0].typeDetails?.first?.baseType, "dictionary")
        XCTAssertEqual(section.items[1].typeDetails?.first?.baseType, "string")
        
        AssertRoundtrip(for: symbol)
    }
    
}
