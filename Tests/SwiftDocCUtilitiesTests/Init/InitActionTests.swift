/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
import SwiftDocCTestUtilities
@testable import SwiftDocCUtilities

final class InitActionTests: XCTestCase {
    
    let fileManager = FileManager.default
    let documentationTitle = "MyTestDocumentation"
    
    func testInitActionCreatesArticleOnlyCatalog() throws {
        let outputLocation = Folder(name: "output", content: [])
        let fileManager = try TestFileSystem(folders: [outputLocation])
        var action = try InitAction(
            catalogOutputDirectory: outputLocation.absoluteURL.appendingPathComponent("\(documentationTitle).docc"),
            documentationTitle: documentationTitle,
            catalogTemplate: .articleOnly,
            fileManager: fileManager
        )
        let result = try action.perform(logHandle: .none)
        // Test the content of the output folder is the expected one.
        let outputCatalogContent = fileManager.files.filter { $0.key.hasPrefix(result.outputs.first!.path()) }
        XCTAssertEqual(outputCatalogContent.keys.sorted(), [
            "/output/\(documentationTitle).docc",
            "/output/\(documentationTitle).docc/\(documentationTitle).md",
            "/output/\(documentationTitle).docc/Resources"
        ].sorted(), "Unexpected output")
    }
    
    func testInitActionCreatesTutorialCatalog() throws {
        let outputLocation = Folder(name: "output", content: [])
        let fileManager = try TestFileSystem(folders: [outputLocation])
        var action = try InitAction(
            catalogOutputDirectory: outputLocation.absoluteURL.appendingPathComponent(
                "\(documentationTitle).docc"
            ),
            documentationTitle: documentationTitle,
            catalogTemplate: .tutorial,
            fileManager: fileManager
        )
        let result = try action.perform(logHandle: .standardOutput)
        // Test the content of the output folder is the expected one.
        let outputCatalogContent = fileManager.files.filter { $0.key.hasPrefix(result.outputs.first!.path()) }
        XCTAssertEqual(outputCatalogContent.keys.sorted(), [
            "/output/\(documentationTitle).docc",
            "/output/\(documentationTitle).docc/table-of-contents.tutorial",
            "/output/\(documentationTitle).docc/Chapter01",
            "/output/\(documentationTitle).docc/Chapter01/page-01.tutorial",
            "/output/\(documentationTitle).docc/Chapter01/Resources",
            "/output/\(documentationTitle).docc/Resources"
        ].sorted(), "Unexpected output")
    }
    
    func testArticleOnlyCatalogContent() throws {
        let outputLocation = Folder(name: "output", content: [])
        let fileManager = try TestFileSystem(folders: [outputLocation])
        var action = try InitAction(
            catalogOutputDirectory: outputLocation.absoluteURL.appendingPathComponent("\(documentationTitle).docc"),
            documentationTitle: documentationTitle,
            catalogTemplate: .articleOnly,
            fileManager: fileManager
        )
        let _ = try action.perform(logHandle: .none)
        // Test the content of the articleOnly root template is the expected one.
        let rootFile = fileManager.files.first { $0.key == "/output/\(documentationTitle).docc/\(documentationTitle).md"  }
        guard let rootFile = rootFile else {
            XCTFail("Expected non-nil file")
            return
        }
        XCTAssertEqual(String(decoding: rootFile.value, as: UTF8.self), """
        # \(documentationTitle)

        <!--- Metadata configuration to make appear this documentation page as a top-level page -->

        @Metadata {
          @TechnologyRoot
        }

        Add a single sentence or sentence fragment, which DocC uses as the page’s abstract or summary.

        ## Overview

        Add one or more paragraphs that introduce your content overview.
        """, "Unexpected output")
    }
    
    func testTutorialCatalogContent() throws {
        let outputLocation = Folder(name: "output", content: [])
        let fileManager = try TestFileSystem(folders: [outputLocation])
        var action = try InitAction(
            catalogOutputDirectory: outputLocation.absoluteURL.appendingPathComponent("\(documentationTitle).docc"),
            documentationTitle: documentationTitle,
            catalogTemplate: .tutorial,
            fileManager: fileManager
        )
        let _ = try action.perform(logHandle: .none)
        // Test the content of the articleOnly root template is the expected one.
        let tableOfContentFile = fileManager.files.first { $0.key == "/output/\(documentationTitle).docc/table-of-contents.tutorial"  }
        let page01File = fileManager.files.first { $0.key == "/output/\(documentationTitle).docc/Chapter01/page-01.tutorial"  }
        guard let tableOfContentFile = tableOfContentFile, let page01File = page01File else {
            XCTFail("Expected non-nil file")
            return
        }
        XCTAssertEqual(String(decoding: tableOfContentFile.value, as: UTF8.self), """
        @Tutorials(name: "\(documentationTitle)" {
            @Intro(title: "Tutorial Introduction") {
                Add one or more paragraphs that introduce your tutorial.
            }
            @Chapter(name: "Chapter Name") {
                @Image(source: "add-your-chapter-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                @TutorialReference(tutorial: "doc:page-01")
            }
        }
        """, "Unexpected output")
        XCTAssertEqual(String(decoding: page01File.value, as: UTF8.self), """
        @Tutorial() {
            @Intro(title: "Tutorial Page Title") {
                Add one paragraph that introduce your tutorial.
            }
            @Section(title: "Section Name") {
                @ContentAndMedia {
                    Add text that introduces the tasks that the reader needs to follow.
                    @Image(source: "add-your-section-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                }
                @Steps {
                    @Step {
                        This is a step with code.
                        @Code(name: "", file: "")
                    }
                    @Step {
                        This is a step with an image.
                        @Image(source: "", alt: "")
                    }
                }
            }
        }
        """, "Unexpected output")
    }

}


