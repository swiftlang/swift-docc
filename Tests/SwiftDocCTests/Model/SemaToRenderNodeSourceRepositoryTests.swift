/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@testable import SwiftDocC
import SymbolKit
import XCTest

class SemaToRenderNodeSourceRepositoryTests: XCTestCase {
    func testDoesNotEmitsSourceRepositoryInformationWhenNoSourceIsGiven() throws {
        let outputConsumer = try renderNodeConsumer(
            for: "SourceLocations",
            configureConverter: { converter in
                converter.sourceRepository = nil
            }
        )
        
        XCTAssertNil(try outputConsumer.renderNode(withTitle: "MyStruct").metadata.remoteSource)
    }
    
    func testEmitsSourceRepositoryInformationForSymbolsWhenPresent() throws {
        let outputConsumer = try renderNodeConsumer(
            for: "SourceLocations",
            configureConverter: { converter in
                converter.sourceRepository = SourceRepository.github(
                    checkoutPath: "/path/to/checkout",
                    sourceServiceBaseURL: URL(string: "https://example.com/my-repo")!
                )
            }
        )
        XCTAssertEqual(
            try outputConsumer.renderNode(withTitle: "MyStruct").metadata.remoteSource,
            RenderMetadata.RemoteSource(
                fileName: "MyStruct.swift",
                url: URL(string: "https://example.com/my-repo/SourceLocations/MyStruct.swift#L10")!
            )
        )
    }
}
