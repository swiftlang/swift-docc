/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class String_WhitespaceTests: XCTestCase {
    
    func testVariousSeparators() {
        XCTAssertEqual("Words separated by spaces".replacingWhitespaceAndPunctuation(with: "-"),
                       "Words-separated-by-spaces")
        XCTAssertEqual("Words_separated_by_underscores".replacingWhitespaceAndPunctuation(with: "-"),
                       "Words-separated-by-underscores")
        XCTAssertEqual("Words'separated'by'single'quotes".replacingWhitespaceAndPunctuation(with: "-"),
                       "Words-separated-by-single-quotes")
        XCTAssertEqual("Words:separated:by:colons".replacingWhitespaceAndPunctuation(with: "-"),
                       "Words-separated-by-colons")
        XCTAssertEqual("Words/separated/by/forward/slashes".replacingWhitespaceAndPunctuation(with: "-"),
                       "Words-separated-by-forward-slashes")
        XCTAssertEqual("Mixig various'separator_characters:between/words".replacingWhitespaceAndPunctuation(with: "-"),
                       "Mixig-various-separator-characters-between-words")
    }
    
    func testMultipleSeparators() {
        XCTAssertEqual("Words   separated by    multiple  spaces".replacingWhitespaceAndPunctuation(with: "-"),
                       "Words-separated-by-multiple-spaces")
        XCTAssertEqual("Words___separated_by____multiple__underscrores".replacingWhitespaceAndPunctuation(with: "-"),
                       "Words-separated-by-multiple-underscrores")
        
        XCTAssertEqual("Words: with, various. punctuation! as - separators".replacingWhitespaceAndPunctuation(with: "-"),
                       "Words-with-various-punctuation-as-separators")
    }
}

