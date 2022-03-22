/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import SwiftDocC
@testable import SwiftDocCUtilities
import Markdown
import SwiftDocCTestUtilities

class IndexActionTests: XCTestCase {
    #if !os(iOS)
    func testIndexActionOutputIsDeterministic() throws {
        // Convert a test catalog as input for the IndexAction
        let catalogURL = Bundle.module.url(forResource: "TestCatalog", withExtension: "docc", subdirectory: "Test Catalogs")!
        
        let targetURL = try createTemporaryDirectory()
        let templateURL = try createTemporaryDirectory().appendingPathComponent("template")
        try Folder.emptyHTMLTemplateDirectory.write(to: templateURL)
        
        let targetCatalogURL = targetURL.appendingPathComponent("Result.builtdocs")
        
        var action = try ConvertAction(
            documentationCatalogURL: catalogURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetCatalogURL,
            htmlTemplateDirectory: templateURL,
            emitDigest: false,
            currentPlatforms: nil,
            temporaryDirectory: createTemporaryDirectory()
        )
        _ = try action.perform(logHandle: .standardOutput)
        
        let catalogIdentifier = "org.swift.docc.example"
        
        // Repeatedly index the same catalog and verify that the result is the same every time.
        
        var resultIndexDumps = Set<String>()
        
        for iteration in 1...10 {
            let indexURL = targetURL.appendingPathComponent("index_\(iteration)")
            
            let engine = DiagnosticEngine(filterLevel: .warning)
            
            var indexAction = try IndexAction(
                documentationCatalogURL: targetCatalogURL,
                outputURL: indexURL,
                catalogIdentifier: catalogIdentifier,
                diagnosticEngine: engine
            )
            _ = try indexAction.perform(logHandle: .standardOutput)
            
            let index = try NavigatorIndex(url: indexURL)
            
            resultIndexDumps.insert(index.navigatorTree.root.dumpTree())
            XCTAssertTrue(engine.problems.isEmpty, "Indexing catalog at \(targetURL) resulted in unexpected issues")
        }
        
        // All dumps should be the same, so there should only be one unique index dump
        XCTAssertEqual(resultIndexDumps.count, 1)
    }
    #endif
}
