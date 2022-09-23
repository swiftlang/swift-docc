/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class SVGIDExtractorTests: XCTestCase {
    func testExtractIDFromValidSVG() {
        do {
            let id = extractIDFromSVG(
                """
                <svg viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg" id="plus-id">
                    <path d="M9.99 0c-5.461 0-9.99 4.539-9.99 10s4.539 10 10 10 10-4.53 10-10-4.539-10-10.010-10zM14.079 10.863h-3.226v3.049c0 0.589-0.323 0.97-0.873 0.97-0.559 0-0.853-0.401-0.853-0.97v-3.049h-3.216c-0.579 0-0.98-0.304-0.98-0.843 0-0.559 0.383-0.873 0.98-0.873h3.216v-3.246c0-0.569 0.294-0.97 0.853-0.97 0.549 0 0.873 0.383 0.873 0.97v3.246h3.226c0.599 0 0.97 0.314 0.97 0.873 0 0.539-0.391 0.843-0.97 0.843z"></path>
                </svg>
                """
            )
            
            XCTAssertEqual(id, "plus-id")
        }
        
        do {
            let id = extractIDFromSVG(
                """
                <svg viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg" ID="plus-id">
                    <path d="M9.99 0c-5.461 0-9.99 4.539-9.99 10s4.539 10 10 10 10-4.53 10-10-4.539-10-10.010-10zM14.079 10.863h-3.226v3.049c0 0.589-0.323 0.97-0.873 0.97-0.559 0-0.853-0.401-0.853-0.97v-3.049h-3.216c-0.579 0-0.98-0.304-0.98-0.843 0-0.559 0.383-0.873 0.98-0.873h3.216v-3.246c0-0.569 0.294-0.97 0.853-0.97 0.549 0 0.873 0.383 0.873 0.97v3.246h3.226c0.599 0 0.97 0.314 0.97 0.873 0 0.539-0.391 0.843-0.97 0.843z"></path>
                </svg>
                """
            )
            
            XCTAssertEqual(id, "plus-id")
        }
        
        do {
            let id = extractIDFromSVG(
                """
                <svg viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                    <path iD="plus-id" d="M9.99 0c-5.461 0-9.99 4.539-9.99 10s4.539 10 10 10 10-4.53 10-10-4.539-10-10.010-10zM14.079 10.863h-3.226v3.049c0 0.589-0.323 0.97-0.873 0.97-0.559 0-0.853-0.401-0.853-0.97v-3.049h-3.216c-0.579 0-0.98-0.304-0.98-0.843 0-0.559 0.383-0.873 0.98-0.873h3.216v-3.246c0-0.569 0.294-0.97 0.853-0.97 0.549 0 0.873 0.383 0.873 0.97v3.246h3.226c0.599 0 0.97 0.314 0.97 0.873 0 0.539-0.391 0.843-0.97 0.843z"></path>
                </svg>
                """
            )
            
            XCTAssertEqual(id, "plus-id")
        }
    }
    
    func testExtractIDFromSVGWithoutID() {
        let id = extractIDFromSVG(
            """
            <svg viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
                <path d="M9.99 0c-5.461 0-9.99 4.539-9.99 10s4.539 10 10 10 10-4.53 10-10-4.539-10-10.010-10zM14.079 10.863h-3.226v3.049c0 0.589-0.323 0.97-0.873 0.97-0.559 0-0.853-0.401-0.853-0.97v-3.049h-3.216c-0.579 0-0.98-0.304-0.98-0.843 0-0.559 0.383-0.873 0.98-0.873h3.216v-3.246c0-0.569 0.294-0.97 0.853-0.97 0.549 0 0.873 0.383 0.873 0.97v3.246h3.226c0.599 0 0.97 0.314 0.97 0.873 0 0.539-0.391 0.843-0.97 0.843z"></path>
            </svg>
            """
        )
        
        XCTAssertEqual(id, nil)
    }
    
    func testExtractIDFromInvalidSVG() throws {
        let id = extractIDFromSVG(
            """
            # This is a markdown article
            
            It's hiding as an SVG.
            
            Oh no! 😳
            """
        )
        
        XCTAssertEqual(id, nil)
    }
    
    func extractIDFromSVG(_ source: String) -> String? {
        let svgData = Data(source.utf8)
        return SVGIDExtractor._extractID(from: svgData)
    }
}
