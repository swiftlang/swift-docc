/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

import XCTest
@testable import SwiftDocCUtilities

class PlatformArgumentParserTests: XCTestCase {
    let correctInputs: [[String]] = [
        ["name=macOS,version=10.1.2"],
        ["name=macOS,version=10.1.2", "name=Mac Catalyst,version=13.1.0"],
        ["name=macOS,version=10.1.2", "name=Mac Catalyst,version=13.1.0", "name=watchOS,version=6.0.0"],
    ]
    
    let betaInputs: [[String]] = [
        ["name=macOS,version=10.1.2,beta=true"],
        ["name=macOS,version=10.1.2,beta=yes", "name=Mac Catalyst,version=13.1.0,beta=true"],
        ["name=macOS,version=10.1.2,beta=no", "name=Mac Catalyst,version=13.1.0,beta=false", "name=watchOS,version=6.0.0,beta=true"],
    ]
    
    let missingPatchInputs: [[String]] = [
        ["name=macOS,version=10.12"],
        ["name=macOS,version=10.12", "name=Mac Catalyst,version=13.1"],
        ["name=macOS,version=10.12", "name=Mac Catalyst,version=13.1", "name=watchOS,version=6.0"],
    ]

    let unexpectedFormatInputs: [[String]] = [
        ["name"],
        ["name="],
        ["name=name=macOS"],
        ["name=macOS,version=10.1.2=1.0.0"],
        ["name=macOS=iOS,version="],
        ["name=macOS,version=10.12,beta="],
    ]

    let missingKeysInputs: [[String]] = [
        ["name=macOS"],
        ["version=10.1.2"],
        ["name=iOS,version1=12.0.1"],
        ["name=iOS,version=12"],
        ["name=iOS,version=12.0,beta=nope"],
    ]

    func testPlatformParsing() throws {
        XCTAssertEqual(try correctInputs.map(PlatformArgumentParser.parse), [
            //Expected output
            ["macOS": PlatformVersion(.init(10, 1, 2), beta: false)],
            ["macOS": PlatformVersion(.init(10, 1, 2), beta: false), "Mac Catalyst": PlatformVersion(.init(13, 1, 0), beta: false)],
            ["macOS": PlatformVersion(.init(10, 1, 2), beta: false), "Mac Catalyst": PlatformVersion(.init(13, 1, 0), beta: false), "watchOS": PlatformVersion(.init(6, 0, 0), beta: false)],
        ])
        
        XCTAssertEqual(try betaInputs.map(PlatformArgumentParser.parse), [
            //Expected output
            ["macOS": PlatformVersion(.init(10, 1, 2), beta: true)],
            ["macOS": PlatformVersion(.init(10, 1, 2), beta: true), "Mac Catalyst": PlatformVersion(.init(13, 1, 0), beta: true)],
            ["macOS": PlatformVersion(.init(10, 1, 2), beta: false), "Mac Catalyst": PlatformVersion(.init(13, 1, 0), beta: false), "watchOS": PlatformVersion(.init(6, 0, 0), beta: true)],
        ])
        
        XCTAssertEqual(try missingPatchInputs.map(PlatformArgumentParser.parse), [
            //Expected output
            ["macOS": PlatformVersion(.init(10, 12, 0), beta: false)],
            ["macOS": PlatformVersion(.init(10, 12, 0), beta: false), "Mac Catalyst": PlatformVersion(.init(13, 1, 0), beta: false)],
            ["macOS": PlatformVersion(.init(10, 12, 0), beta: false), "Mac Catalyst": PlatformVersion(.init(13, 1, 0), beta: false), "watchOS": PlatformVersion(.init(6, 0, 0), beta: false)],
        ])
        
        for input in unexpectedFormatInputs {
            XCTAssertThrowsError(try PlatformArgumentParser.parse(input), "Didn't throw for incorrect input") { error in
                guard case PlatformArgumentParser.Error.unexpectedFormat = error else {
                    XCTFail("Didn't throw unexpectedFormat error")
                    return
                }
            }
        }

        for input in missingKeysInputs {
            XCTAssertThrowsError(try PlatformArgumentParser.parse(input), "Didn't throw for incorrect input") { error in
                guard case PlatformArgumentParser.Error.missingKey = error else {
                    XCTFail("Didn't throw missingKey error")
                    return
                }
            }
        }
    }
}
