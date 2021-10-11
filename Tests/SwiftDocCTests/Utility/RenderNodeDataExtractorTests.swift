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

class RenderNodeDataExtractorTests: XCTestCase {
    
    // MARK: - Test Extractor
    
    func testExtractingDataTutorials() throws {
        let jsonData = """
        {
            "metadata": {
                "categoryPathComponent": "TechnologyX",
                "category": "Technology X"
            },
            "sections": [
                {
                    "xcodeRequirement": "Xcode 10 beta",
                    "chapter": "Chapter 1",
                    "video": "video.mov",
                    "title": "Advanced Augmented Reality App",
                    "projectFiles": "project.zip",
                    "estimatedTimeInMinutes": 50
                }
            ],
            "references": {
                "project.zip": {
                    "url": "https://example.com/48d78128c6/project.zip",
                    "type": "download",
                    "checksum": "ad4adacc8ad53230b59d6158efe603bae57fcc95358b6346b919a5e5d9a98bf5aeac664d9be33a7bc23298f01265a9ca29c5cb26e38d50736b8dccb7a3d515d3",
                    "identifier": "project.zip"
                }
            }
        }

        """.utf8
        
        let extractor = try RenderNodeDataExtractor(with: Data(jsonData))
        
        let resource = extractor.projectFiles
        XCTAssertEqual(resource?.url.absoluteString, "https://example.com/48d78128c6/project.zip")
        XCTAssertEqual(resource?.checksum, "ad4adacc8ad53230b59d6158efe603bae57fcc95358b6346b919a5e5d9a98bf5aeac664d9be33a7bc23298f01265a9ca29c5cb26e38d50736b8dccb7a3d515d3")
        
        let metadata = extractor.metadata(for: "categoryPathComponent")
        XCTAssertEqual(metadata, "TechnologyX")
    }
    
    func testExtractingDataSampleCode() throws {
        let jsonData = """
        {
            "metadata": {
                "role": "sampleCode",
                "roleHeading": "Sample Code",
                "title": "Developing a Sample Test App"
            },
            "sampleCodeDownload": {
                "action": {
                  "identifier": "project.zip",
                  "isActive": true,
                  "overridingTitle": "Download",
                  "type": "reference"
                },
                "kind": "sampleDownload"
            },
            "references": {
                "project.zip": {
                    "url": "https://example.com/48d78128c6/project.zip",
                    "type": "download",
                    "checksum": "ad4adacc8ad53230b59d6158efe603bae57fcc95358b6346b919a5e5d9a98bf5aeac664d9be33a7bc23298f01265a9ca29c5cb26e38d50736b8dccb7a3d515d3",
                    "identifier": "project.zip"
                }
            }
        }

        """.utf8
        
        let extractor = try RenderNodeDataExtractor(with: Data(jsonData))
        
        let resource = extractor.projectFiles
        XCTAssertEqual(resource?.url.absoluteString, "https://example.com/48d78128c6/project.zip")
        XCTAssertEqual(resource?.checksum, "ad4adacc8ad53230b59d6158efe603bae57fcc95358b6346b919a5e5d9a98bf5aeac664d9be33a7bc23298f01265a9ca29c5cb26e38d50736b8dccb7a3d515d3")
        
        let metadata = extractor.metadata(for: "role")
        XCTAssertEqual(metadata, "sampleCode")
    }
    
}
