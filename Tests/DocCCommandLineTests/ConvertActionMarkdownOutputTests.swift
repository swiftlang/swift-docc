/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Foundation
import SwiftDocC
@testable import DocCCommandLine
import DocCTestUtilities

struct ConvertActionMarkdownOutputTests {
    @Test
    func writesHostingBasePathIntoMarkdownLinks() async throws {
        let catalog = Folder(name: "Something.docc") {
            TextFile(name: "Something.md", utf8Content: """
            # Something

            A root page that links to <doc:OtherArticle>.
            """)

            TextFile(name: "OtherArticle.md", utf8Content: """
            # Other Article

            An article to link to.
            """)
        }

        let fileSystem = try TestFileSystem {
            Folder(name: "path") {
                Folder(name: "to") {
                    catalog
                }
            }
            Folder(name: "output-dir") {}
        }

        var featureFlags = FeatureFlags()
        featureFlags.isExperimentalMarkdownOutputEnabled = true

        var action = try ConvertAction(
            documentationBundleURL: URL(fileURLWithPath: "/path/to/\(catalog.name)"),
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: URL(fileURLWithPath: "/output-dir"),
            htmlTemplateDirectory: nil,
            emitDigest: false,
            currentPlatforms: nil,
            buildIndex: false,
            fileManager: fileSystem,
            temporaryDirectory: URL(fileURLWithPath: "/tmp"),
            featureFlags: featureFlags,
            hostingBasePath: "some/test/base-path"
        )
        // The old `Indexer` type doesn't work with virtual file systems.
        action._completelySkipBuildingIndex = true

        _ = try await action.perform(logHandle: .none)

        let markdownData = try fileSystem.contents(of: URL(fileURLWithPath: "/output-dir/data/documentation/something.md"))
        let markdown = try #require(String(data: markdownData, encoding: .utf8))

        // Unlike render JSON, the markdown output doesn't have a renderer that adds the hosting base path to links at runtime.
        #expect(markdown.contains("[Other Article](/some/test/base-path/documentation/something/otherarticle)"), "Unexpected markdown:\n\(markdown)")
    }
}
