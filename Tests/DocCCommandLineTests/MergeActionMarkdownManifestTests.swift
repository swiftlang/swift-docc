/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@testable import SwiftDocC
@testable import DocCCommandLine
import Testing
import DocCTestUtilities

struct MergeActionMarkdownManifestTests {
    @Test
    func keepsTheMarkdownManifestOfEveryArchive() async throws {
        let fileSystem = try TestFileSystem(
            folders: [
                Folder(name: "Output.doccarchive", content: []),
                makeArchive(name: "First", manifestTitle: "First"),
                makeArchive(name: "Second", manifestTitle: "Second"),
            ]
        )

        try await merge(["First", "Second"], fileSystem: fileSystem)

        for name in ["First", "Second"] {
            let manifest = try readManifest(named: "\(name)-markdown-manifest.json", fileSystem: fileSystem)
            let expected = makeManifest(title: name, archiveName: name)
            #expect(manifest.title == name)
            #expect(manifest.documents == expected.documents)
            #expect(manifest.relationships == expected.relationships)
        }
    }

    @Test
    func combinesMarkdownManifestsWithTheSameName() async throws {
        // Archives with the same display name write manifests with the same file name.
        let fileSystem = try TestFileSystem(
            folders: [
                Folder(name: "Output.doccarchive", content: []),
                makeArchive(name: "First", manifestTitle: "Docs"),
                makeArchive(name: "Second", manifestTitle: "Docs"),
            ]
        )

        try await merge(["First", "Second"], fileSystem: fileSystem)

        let manifest = try readManifest(named: "Docs-markdown-manifest.json", fileSystem: fileSystem)
        let first = makeManifest(title: "Docs", archiveName: "First")
        let second = makeManifest(title: "Docs", archiveName: "Second")
        #expect(manifest.title == "Docs")
        #expect(manifest.documents == first.documents.union(second.documents))
        #expect(manifest.relationships == first.relationships.union(second.relationships))
    }

    // MARK: Test helpers

    private func makeManifest(title: String, archiveName: String) -> MarkdownOutputManifest {
        MarkdownOutputManifest(
            title: title,
            documents: [
                .init(identifier: "/documentation/\(archiveName)", documentType: .symbol, title: archiveName),
                .init(identifier: "/documentation/\(archiveName)/Guide", documentType: .article, title: "\(archiveName) Guide"),
            ],
            relationships: [
                .init(sourceIdentifier: "/documentation/\(archiveName)/Guide", relationshipType: .belongsToTopic, targetIdentifier: "/documentation/\(archiveName)"),
            ]
        )
    }

    private func makeArchive(name: String, manifestTitle: String) -> Folder {
        let archive = MergeActionTests.makeArchive(name: name, documentationPages: [name, "\(name)/Guide"], tutorialPages: [])
        return Folder(name: archive.name, content: archive.content + [
            JSONFile(name: "\(manifestTitle)-markdown-manifest.json", content: makeManifest(title: manifestTitle, archiveName: name)),
        ])
    }

    private func merge(_ archiveNames: [String], fileSystem: TestFileSystem) async throws {
        let logStorage = LogHandle.LogStorage()
        let action = MergeAction(
            archives: archiveNames.map { URL(fileURLWithPath: "/\($0).doccarchive") },
            landingPageInfo: .synthesize(.init(name: "Landing Page", kind: "Kind", style: .detailedGrid)),
            outputURL: URL(fileURLWithPath: "/Output.doccarchive"),
            fileManager: fileSystem
        )
        _ = try await action.perform(logHandle: .memory(logStorage))
        #expect(logStorage.text == "", "The action didn't log anything")
    }

    private func readManifest(named fileName: String, fileSystem: TestFileSystem) throws -> MarkdownOutputManifest {
        let data = try fileSystem.contents(of: URL(fileURLWithPath: "/Output.doccarchive/\(fileName)"))
        return try JSONDecoder().decode(MarkdownOutputManifest.self, from: data)
    }
}
