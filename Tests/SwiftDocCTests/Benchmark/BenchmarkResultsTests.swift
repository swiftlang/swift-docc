/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class BenchmarkResultsTests: XCTestCase {
    func testDecodingLegacyFormat() throws {
        let data = try XCTUnwrap(legacyBenchmark.data(using: .utf8))
        let results = try JSONDecoder().decode(BenchmarkResults.self, from: data)
        
        XCTAssertEqual(results.platformName, "macOS")
        XCTAssertEqual(results.doccArguments, ["convert", "TestBundle.docc"])
        XCTAssertEqual(results.timestamp.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: 1.0) // The encoded format doesn't include sub-second information.
        
        // Unordered metrics should be ordered by kind (in the order duration, bytesInMemory, bytesOnDisk, checksum), and then by name.
        XCTAssertEqual(results.metrics, [
            .init(id: "duration-bundle-registration", displayName: "Duration for \'bundle-registration\'", value: .duration(0.108)),
            .init(id: "duration-convert-action", displayName: "Duration for \'convert-action\'", value: .duration(0.139)),
            .init(id: "duration-navigation-index", displayName: "Duration for \'navigation-index\'", value: .duration(0.0)),
            .init(id: "test-extra-duration", displayName: "Duration for \'test-extra\'", value: .duration(1.234)),
            .init(id: "peak-memory", displayName: "Peak memory footprint", value: .bytesInMemory(8273920)),
            .init(id: "test-extra-memory", displayName: "Test extra memory footprint", value: .bytesInMemory(1234567)),
            .init(id: "data-subdirectory-output-size", displayName: "Data subdirectory size", value: .bytesOnDisk(181337)),
            .init(id: "index-subdirectory-output-size", displayName: "Index subdirectory size", value: .bytesOnDisk(13768)),
            .init(id: "test-extra-output-size", displayName: "Test extra output size", value: .bytesOnDisk(12345678)),
            .init(id: "total-archive-output-size", displayName: "Total DocC archive size", value: .bytesOnDisk(1231030)),
            .init(id: "topic-anchor-hash", displayName: "Topic Anchor Checksum", value: .checksum("5afbde3ec6d3ee7b84e8aa1342f6839a")),
            .init(id: "topic-graph-hash", displayName: "Topic Graph Checksum", value: .checksum("9dd02a80ae466010c8925aebe9a1ca02"))
        ])
    }
}


// The legacy format encoded the date using the current locale.
//
// The expectation is that benchmark files are not compared across machines.
//
// Instead of using a hardcoded date string in a specific locale, this test encodes a new value using the current locale
// behaves the same as the real use case, regardless of the current locale.

private let testDate = Date()
private let legacyEncodedDate: String = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .medium
    return dateFormatter.string(from: testDate)
}()

private let legacyBenchmark = """
{
  "arguments": [
    "convert",
    "TestBundle.docc"
  ],
  "platform": "macOS",
  "metrics": [
    {
      "displayName": "Duration for 'bundle-registration' (msec)",
      "result": 108,
      "identifier": "duration-bundle-registration"
    },
    {
      "displayName": "Duration for 'convert-action' (msec)",
      "result": 139,
      "identifier": "duration-convert-action"
    },
    {
      "displayName": "Test extra memory footprint (bytes)",
      "result": 1234567,
      "identifier": "test-extra-memory"
    },
    {
      "displayName": "Topic Graph Checksum",
      "result": "9dd02a80ae466010c8925aebe9a1ca02",
      "identifier": "topic-graph-hash"
    },
    {
      "displayName": "Topic Anchor Checksum",
      "result": "5afbde3ec6d3ee7b84e8aa1342f6839a",
      "identifier": "topic-anchor-hash"
    },
    {
      "displayName": "Peak memory footprint (bytes)",
      "result": 8273920,
      "identifier": "peak-memory"
    },
    {
      "displayName": "Duration for 'navigation-index' (msec)",
      "result": 0,
      "identifier": "duration-navigation-index"
    },
    {
      "displayName": "Duration for 'test-extra' (msec)",
      "result": 1234,
      "identifier": "test-extra-duration"
    },
    {
      "displayName": "Total DocC archive size (bytes)",
      "result": 1231030,
      "identifier": "total-archive-output-size"
    },
    {
      "displayName": "Data subdirectory size (bytes)",
      "result": 181337,
      "identifier": "data-subdirectory-output-size"
    },
    {
      "displayName": "Test extra output size (bytes)",
      "result": 12345678,
      "identifier": "test-extra-output-size"
    },
    {
      "displayName": "Index subdirectory size (bytes)",
      "result": 13768,
      "identifier": "index-subdirectory-output-size"
    }
  ],
  "date": "\(legacyEncodedDate)"
}
"""
