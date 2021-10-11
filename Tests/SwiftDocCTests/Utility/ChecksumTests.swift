/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class ChecksumTests: XCTestCase {
    let zipFileURL: URL = Bundle.module.url(
        forResource: "project", withExtension: "zip", subdirectory: "Test Resources")!

    let expectedSHA512Checksum = "2521bb27db3f8b72f8f2bb9e3a33698b9c5c72a5d7862f5b209794099e1cf0acaab7d8a47760b001cb508b5c4f3d7cf7f8ce1c32679b3fde223e63b5a1e7e509"
    
    func testSHA512Checksum() throws {
        let zipData = try Data(contentsOf: zipFileURL)
        XCTAssertEqual(Checksum.sha512(of: zipData), expectedSHA512Checksum)
    }
    
    let expectedMD5Checksum = "326afc64e56ef038fdc4d6a5cc156a9a"
    
    func testMD5Checksum() throws {
        let textToChecksum = "./Test Resources/project.zip"
        XCTAssertEqual(Checksum.md5(of: textToChecksum.data(using: .utf8)!), expectedMD5Checksum)
    }
}
