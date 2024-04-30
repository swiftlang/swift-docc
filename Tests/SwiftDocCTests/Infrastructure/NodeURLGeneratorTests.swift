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

class NodeURLGeneratorTests: XCTestCase {
    let generator = NodeURLGenerator()

    let unchangedURLs = [
        URL(string: "doc://com.bundle/folder-prefix/type/symbol")!,
        URL(string: "doc://com.bundle/fol.der-pref.ix./type-swift.class/symbol.name.")!,
        URL(string: "doc://com.bundle/?folder-prefix/?type?/?symbol")!,
    ]
    
    /// Tests that a list of URLs are not changed by `NodeURLGenerator.fileSafeURL(_:)`
    func testFileNameSafeURLUnchanged() throws {
        XCTAssertEqual(unchangedURLs.map({ NodeURLGenerator.fileSafeURL($0) }), unchangedURLs)
    }

    let unsafeInputURLs = [
        URL(string: "doc://com.bundle/.folder-prefix/.type-swift.class/.symbol.name")!,
        URL(string: "doc://com.bundle/_folder-prefix/_type-swift.class/_symbol.name")!,
        URL(string: "doc://com.bundle/!folder-prefix/_type-swift.class/.symbol.name")!,
    ]
    
    let safeOutputURLs = [
        URL(string: "doc://com.bundle/'.folder-prefix/'.type-swift.class/'.symbol.name")!,
        URL(string: "doc://com.bundle/_folder-prefix/_type-swift.class/_symbol.name")!,
        URL(string: "doc://com.bundle/!folder-prefix/_type-swift.class/'.symbol.name")!,
    ]
    
    /// Tests that a list of URLs are "safe-ified" successfully
    func testFileNameSafeURLSafeified() throws {
        XCTAssertEqual(unsafeInputURLs.map({ NodeURLGenerator.fileSafeURL($0) }), safeOutputURLs)
    }
    
    /// Tests that baseURL is not "safe-ified" when passed
    func testSafeURLWithBaseURL() throws {
        // This is a realist DerivedData folder.
        let baseURL = URL(string: "file:///path/to/bundle/_testbundle-ctlj/products/documentation.builtbundle/com.example.testbundle/data/")!
        let generator = NodeURLGenerator(baseURL: baseURL)
        
        let basicIdentifier = ResolvedTopicReference(bundleIdentifier: "com.example.testbundle",
                                                     path: "/folder/class/symbol",
                                                     fragment: nil,
                                                     sourceLanguage: .swift)
        
        XCTAssertEqual(generator.urlForReference(basicIdentifier).absoluteString, "file:///path/to/bundle/_testbundle-ctlj/products/documentation.builtbundle/com.example.testbundle/data/folder/class/symbol")
        
        let symbolIdentifier = ResolvedTopicReference(bundleIdentifier: "com.example.testbundle",
                                                      path: "/folder/class/.==",
                                                      fragment: nil,
                                                      sourceLanguage: .swift)
        XCTAssertEqual(generator.urlForReference(symbolIdentifier).absoluteString, "file:///path/to/bundle/_testbundle-ctlj/products/documentation.builtbundle/com.example.testbundle/data/folder/class/'.==")
        
        let privateIdentifier = ResolvedTopicReference(bundleIdentifier: "com.example.testbundle",
                                                       path: "/folder/class/_privateMethod",
                                                       fragment: nil,
                                                       sourceLanguage: .objectiveC)
        XCTAssertEqual(generator.urlForReference(privateIdentifier).absoluteString, "file:///path/to/bundle/_testbundle-ctlj/products/documentation.builtbundle/com.example.testbundle/data/folder/class/_privateMethod")
        XCTAssertEqual(generator.urlForReference(privateIdentifier, lowercased: true).absoluteString, "file:///path/to/bundle/_testbundle-ctlj/products/documentation.builtbundle/com.example.testbundle/data/folder/class/_privatemethod")
        
        let classIdentifier = ResolvedTopicReference(bundleIdentifier: "com.example.testbundle",
                                                     path: "/folder/_privateclass/_privatesubclass",
                                                     fragment: nil,
                                                     sourceLanguage: .objectiveC)
        XCTAssertEqual(generator.urlForReference(classIdentifier).absoluteString, "file:///path/to/bundle/_testbundle-ctlj/products/documentation.builtbundle/com.example.testbundle/data/folder/_privateclass/_privatesubclass")
    }
    
    var inputLongPaths = [
        // Paths within the limits
        "/path/to/symbol.json",
        "/path/to/\(String(repeating: "A", count: 234))", // adding the extension comes to 240 chars
        // Path components over 255 chars long
        "/path/to/\(String(repeating: "A", count: 240))",
        "/path/to/\(String(repeating: "A", count: 300))",
        // Path within the total limit
        "/path/to/\(String(repeating: "A", count: 234))/\(String(repeating: "A", count: 234))/\(String(repeating: "A", count: 234))",
        // Path over the total limit
        "/path/to/\(String(repeating: "A", count: 234))/\(String(repeating: "A", count: 234))/\(String(repeating: "A", count: 234))/\(String(repeating: "A", count: 234))/\(String(repeating: "A", count: 234))",
    ]
    
    var outputLongPaths = [
        "/path/to/symbol.json",
        "/path/to/\(String(repeating: "A", count: 234))",
        "/path/to/\(String(repeating: "A", count: 240))-kks8",
        "/path/to/\(String(repeating: "A", count: 240))-3l1az",
        "/path/to/\(String(repeating: "A", count: 234))/\(String(repeating: "A", count: 234))/\(String(repeating: "A", count: 234))",
        "/path/to/\(String(repeating: "A", count: 234))/\(String(repeating: "A", count: 234))/\(String(repeating: "A", count: 234))/\(String(repeating: "A", count: 166))-8ye9b",
    ]
    
    /// Tests that long path components are trimmed
    func testLongPathComponents() throws {
        for offset in 0..<inputLongPaths.count {
            XCTAssertEqual(NodeURLGenerator.fileSafeURL(URL(fileURLWithPath: inputLongPaths[offset])), URL(fileURLWithPath: outputLongPaths[offset]) )
        }
    }
}
