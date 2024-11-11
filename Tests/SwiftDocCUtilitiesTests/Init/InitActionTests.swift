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
    private let documentationTitle = "MyTestDocumentation"
    
    func testInitActionCreatesArticleOnlyCatalog() async throws {
        let outputLocation = Folder(name: "output", content: [])
        let fileManager = try TestFileSystem(folders: [outputLocation])
        let action = try InitAction(
            catalogOutputDirectory: outputLocation.absoluteURL.appendingPathComponent("\(documentationTitle).docc"),
            documentationTitle: documentationTitle,
            catalogTemplate: .articleOnly,
            fileManager: fileManager
        )
        let result = try await action.perform(logHandle: .none)
        // Test the content of the output folder is the expected one.
        let outputCatalogContent = try fileManager.contentsOfDirectory(atPath: result.outputs.first!.path).sorted()
        XCTAssertEqual(outputCatalogContent, [
            "\(documentationTitle).md",
            "Resources"
        ].sorted())
    }
    
    func testInitActionCreatesTutorialCatalog() async throws {
        let outputLocation = Folder(name: "output", content: [])
        let fileManager = try TestFileSystem(folders: [outputLocation])
        let action = try InitAction(
            catalogOutputDirectory: outputLocation.absoluteURL.appendingPathComponent(
                "\(documentationTitle).docc"
            ),
            documentationTitle: documentationTitle,
            catalogTemplate: .tutorial,
            fileManager: fileManager
        )
        let result = try await action.perform(logHandle: .none)
        // Test the content of the output folder is the expected one.
        let outputCatalogContent = try fileManager.recursiveContentsOfDirectory(atPath: result.outputs.first!.path).sorted()
        XCTAssertEqual(outputCatalogContent, [
            "table-of-contents.tutorial",
            "Chapter01",
            "Chapter01/page-01.tutorial",
            "Chapter01/Resources",
            "Resources"
        ].sorted())
    }
    
    func testArticleOnlyCatalogContent() async throws {
        let outputLocation = Folder(name: "output", content: [])
        let fileManager = try TestFileSystem(folders: [outputLocation])
        let action = try InitAction(
            catalogOutputDirectory: outputLocation.absoluteURL.appendingPathComponent("\(documentationTitle).docc"),
            documentationTitle: documentationTitle,
            catalogTemplate: .articleOnly,
            fileManager: fileManager
        )
        let _ = try await action.perform(logHandle: .none)
        // Test the content of the articleOnly root template is the expected one.
        let rootFile = try XCTUnwrap(fileManager.contents(atPath: "/output/\(documentationTitle).docc/\(documentationTitle).md"))
        XCTAssertEqual(String(data: rootFile, encoding: .utf8), """
        # \(documentationTitle)

        <!--- Metadata configuration to make appear this documentation page as a top-level page -->

        @Metadata {
          @TechnologyRoot
        }

        Add a single sentence or sentence fragment, which DocC uses as the page’s abstract or summary.

        ## Overview

        Add one or more paragraphs that introduce your content overview.
        """)
    }
    
    func testTutorialCatalogContent() async throws {
        let outputLocation = Folder(name: "output", content: [])
        let fileManager = try TestFileSystem(folders: [outputLocation])
        let action = try InitAction(
            catalogOutputDirectory: outputLocation.absoluteURL.appendingPathComponent("\(documentationTitle).docc"),
            documentationTitle: documentationTitle,
            catalogTemplate: .tutorial,
            fileManager: fileManager
        )
        let _ = try await action.perform(logHandle: .none)
        // Test the content of the articleOnly root template is the expected one.
        let tableOfContentFile = try XCTUnwrap(fileManager.contents(atPath: "/output/\(documentationTitle).docc/table-of-contents.tutorial"))
        let page01File = try XCTUnwrap(fileManager.contents(atPath: "/output/\(documentationTitle).docc/Chapter01/page-01.tutorial"))
        XCTAssertEqual(String(data: tableOfContentFile, encoding: .utf8), """
        @Tutorials(name: "\(documentationTitle)") {
            @Intro(title: "Tutorial Introduction") {
                Add one or more paragraphs that introduce your tutorial.
            }
            @Chapter(name: "Chapter Name") {
                @Image(source: "add-your-chapter-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                @TutorialReference(tutorial: "doc:page-01")
            }
        }
        """)
        XCTAssertEqual(String(data: page01File, encoding: .utf8), """
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
        """)
    }
}
