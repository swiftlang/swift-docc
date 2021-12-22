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
import SwiftDocCTestUtilities

class PlistSymbolTests: XCTestCase {
    private let plistSymbolURL = Bundle.module.url(
        forResource: "plist-symbol", withExtension: "json",
        subdirectory: "Rendering Fixtures")!
    
    func testDecodePlistSymbol() throws {
        let data = try Data(contentsOf: plistSymbolURL)
        let symbol = try RenderNode.decode(fromJSON: data)
        
        //
        // Plist Details
        //
        
        guard let section = symbol.primaryContentSections.first(where: { section -> Bool in
            return section.kind == .plistDetails
        }) as? PlistDetailsRenderSection else {
            XCTFail("Plist details section not decoded")
            return
        }
        
        XCTAssertEqual(section.details.name, "com.apple.developer.networking.wifi")
        XCTAssertEqual(section.details.ideTitle, "WiFi access")
        XCTAssertEqual(section.details.titleStyle, .title)
        guard section.details.value.count == 2 else {
            XCTFail("Invalid number of value types found")
            return
        }
        
        XCTAssertEqual(section.details.value[0].baseType, "string")
        XCTAssertEqual(section.details.value[0].arrayMode, true)
        XCTAssertEqual(section.details.value[1].baseType, "number")
        XCTAssertNil(section.details.value[1].arrayMode)
        
        XCTAssertEqual(section.details.platforms, ["iOS", "macOS"])
        
        /// Plist Properties
        guard let properties = symbol.primaryContentSections.first(where: { section -> Bool in
            return section.kind == .properties
        }) as? PropertiesRenderSection else {
            XCTFail("Plist properties section not decoded")
            return
        }
        
        XCTAssertEqual(properties.items.count, 1)
        guard properties.items.count == 1 else { return }
        
        XCTAssertEqual(properties.title, "Properties")
        
        guard let attributes = properties.items[0].attributes else {
            XCTFail("The property doesn't have the expected attributes")
            return
        }

        XCTAssertEqual(attributes.count, 1)
        guard attributes.count == 1 else { return }
        
        if case RenderAttribute.default(let value) = attributes[0] {
            XCTAssertEqual(value, "AABBCC")
        } else {
            XCTFail("Unexpected attribute")
        }
        
        /// Plist Attributes
        guard let attributesSection = symbol.primaryContentSections.first(where: { section -> Bool in
            return section.kind == .attributes
        }) as? AttributesRenderSection else {
            XCTFail("Plist attributes section not decoded")
            return
        }
        
        XCTAssertEqual(attributesSection.attributes?.count, 1)
        guard attributesSection.attributes?.count == 1 else { return }
        
        XCTAssertEqual(attributesSection.title, "Attributes")
        
        XCTAssertEqual(attributesSection.attributes?[0].title, "Default value")
        
        if case .default(let value)? = attributesSection.attributes?[0] {
            XCTAssertEqual(value, "AABBCC")
        } else {
            XCTFail("Unexpected attribute")
        }
        
        /// Plist Possible Values
        guard let values = symbol.primaryContentSections.first(where: { section -> Bool in
            return section.kind == .possibleValues
        }) as? PossibleValuesRenderSection else {
            XCTFail("Plist possible values section not decoded")
            return
        }
        
        XCTAssertEqual(values.title, "Possible Values")
        XCTAssertEqual(values.values.map { $0.name }, ["ppc", "i386", "arm"])
        XCTAssertEqual(values.values.map { $0.content?.firstParagraph.first }, [nil, .text("Any i386 type of processor"), nil])
        
        // Test render reference to plist symbol
        guard let reference = symbol.references["doc://org.swift.docc.example/plist/dataaccess"] as? TopicRenderReference else {
            XCTFail("Did not find doc://org.swift.docc.example/plist/dataaccess reference")
            return
        }
        XCTAssertEqual(reference.titleStyle, .title)
        XCTAssertEqual(reference.name, "com.apple.enabledataaccess")
        XCTAssertEqual(reference.ideTitle, "Enable Data Access")
    
        // Test navigator information
        XCTAssertEqual(symbol.navigatorPageType(), .propertyListKey)
        
        AssertRoundtrip(for: symbol)
    }
    
    func testDecodeDetailsSectionNoIdeTitle() throws {
        let modifiedJSON = try String(contentsOf: plistSymbolURL)
            .replacingOccurrences(of: "\"ideTitle\": \"WiFi access\",", with: "")
        
        let tempFolderURL = try createTempFolder(content: [
            TextFile(name: "missingIdeTitle.json", utf8Content: modifiedJSON),
        ])
        let symbol = try RenderNode.decode(fromJSON: try Data(contentsOf: tempFolderURL.appendingPathComponent("missingIdeTitle.json")))
        
        //
        // Plist Details
        //
        
        guard let section = symbol.primaryContentSections.first(where: { section -> Bool in
            return section.kind == .plistDetails
        }) as? PlistDetailsRenderSection else {
            XCTFail("Plist details section not decoded")
            return
        }
        
        XCTAssertEqual(section.details.name, "com.apple.developer.networking.wifi")
        XCTAssertNil(section.details.ideTitle)
        
        AssertRoundtrip(for: symbol)
    }
        
    func testDecodePossibleValuesNoTitle() throws {
        let modifiedJSON = try String(contentsOf: plistSymbolURL)
            .replacingOccurrences(of: "\"title\": \"Possible Values\",", with: "")
        
        let tempFolderURL = try createTempFolder(content: [
            TextFile(name: "missingPossibleValuesTitle.json", utf8Content: modifiedJSON),
        ])
        let symbol = try RenderNode.decode(fromJSON: try Data(contentsOf: tempFolderURL.appendingPathComponent("missingPossibleValuesTitle.json")))
        
        //
        // Plist Details
        //
        
        guard let section = symbol.primaryContentSections.first(where: { section -> Bool in
            return section.kind == .possibleValues
        }) as? PossibleValuesRenderSection else {
            XCTFail("Plist details section not decoded")
            return
        }
        
        XCTAssertEqual(section.values.count, 3)
        XCTAssertNil(section.title)
        
        AssertRoundtrip(for: symbol)
    }
}


/// Ensures a given render node can be encoded and decode back without throwing.
public func AssertRoundtrip(for renderNode: RenderNode, file: StaticString = #file, line: UInt = #line) {
    // Ensure roundtripping, so we encode the render node and decode it back.
    do {
        let roundtripData = try JSONEncoder().encode(renderNode)
        XCTAssertNoThrow(try RenderNode.decode(fromJSON: roundtripData), file: (file), line: line)
    } catch {
        XCTFail("Encoding process failed with error: \(error.localizedDescription)", file: (file), line: line)
    }
}
