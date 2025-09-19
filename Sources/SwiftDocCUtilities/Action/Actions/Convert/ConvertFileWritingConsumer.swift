/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

struct ConvertFileWritingConsumer: ConvertOutputConsumer, ExternalNodeConsumer {
    var targetFolder: URL
    var bundleRootFolder: URL?
    var fileManager: any FileManagerProtocol
    var context: DocumentationContext
    var renderNodeWriter: JSONEncodingRenderNodeWriter
    var indexer: ConvertAction.Indexer?
    let enableCustomTemplates: Bool
    var assetPrefixComponent: String?

    private enum CustomTemplateIdentifier: String {
        case header = "custom-header"
        case footer = "custom-footer"
    }
    
    init(
        targetFolder: URL,
        bundleRootFolder: URL?,
        fileManager: any FileManagerProtocol,
        context: DocumentationContext,
        indexer: ConvertAction.Indexer?,
        enableCustomTemplates: Bool = false,
        transformForStaticHostingIndexHTML: URL?,
        bundleID: DocumentationBundle.Identifier?
    ) {
        self.targetFolder = targetFolder
        self.bundleRootFolder = bundleRootFolder
        self.fileManager = fileManager
        self.context = context
        self.renderNodeWriter = JSONEncodingRenderNodeWriter(
            targetFolder: targetFolder,
            fileManager: fileManager,
            transformForStaticHostingIndexHTML: transformForStaticHostingIndexHTML
        )
        self.indexer = indexer
        self.enableCustomTemplates = enableCustomTemplates
        self.assetPrefixComponent = bundleID?.rawValue.split(separator: "/").joined(separator: "-")
    }
    
    @available(*, deprecated, message: "This deprecated API will be removed after 6.2 is released")
    func consume(problems: [Problem]) throws {
        let diagnostics = problems.map { problem in
            Digest.Diagnostic(diagnostic: problem.diagnostic, rootURL: bundleRootFolder)
        }
        let problemsURL = targetFolder.appendingPathComponent("diagnostics.json", isDirectory: false)
        let data = try encode(diagnostics)
        try fileManager.createFile(at: problemsURL, contents: data)
    }
    
    func consume(renderNode: RenderNode) throws {
        // Write the render node to disk
        try renderNodeWriter.write(renderNode, encoder: makeEncoder())
        
        // Index the node, if indexing is enabled.
        indexer?.index(renderNode)
    }
    
    func consume(markdownNode: WritableMarkdownOutputNode) throws {
        try renderNodeWriter.write(markdownNode)
    }
    
    func consume(externalRenderNode: ExternalRenderNode) throws {
        // Index the external node, if indexing is enabled.
        indexer?.index(externalRenderNode)
    }
    
    func consume(assetsInBundle bundle: DocumentationBundle) throws {
        func copyAsset(_ asset: DataAsset, to destinationFolder: URL) throws {
            for sourceURL in asset.variants.values where !sourceURL.isAbsoluteWebURL {
                let assetName = sourceURL.lastPathComponent
                try fileManager._copyItem(
                    at: sourceURL,
                    to: destinationFolder.appendingPathComponent(assetName, isDirectory: false)
                )
            }
        }

        // TODO: Supporting a single bundle for the moment.
        let bundleID = bundle.id
        assert(bundleID.rawValue == self.assetPrefixComponent, "Unexpectedly encoding assets for a bundle other than the one this output consumer was created for.")
        
        // Create images directory if needed.
        let imagesDirectory = targetFolder
            .appendingPathComponent("images", isDirectory: true)
            .appendingPathComponent(bundleID.rawValue, isDirectory: true)
        if !fileManager.directoryExists(atPath: imagesDirectory.path) {
            try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Copy all registered images to the output directory.
        for imageAsset in context.registeredImageAssets(for: bundleID) {
            try copyAsset(imageAsset, to: imagesDirectory)
        }
        
        // Create videos directory if needed.
        let videosDirectory = targetFolder
            .appendingPathComponent("videos", isDirectory: true)
            .appendingPathComponent(bundleID.rawValue, isDirectory: true)
        if !fileManager.directoryExists(atPath: videosDirectory.path) {
            try fileManager.createDirectory(at: videosDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Copy all registered videos to the output directory.
        for videoAsset in context.registeredVideoAssets(for: bundleID) {
            try copyAsset(videoAsset, to: videosDirectory)
        }
        
        // Create downloads directory if needed.
        let downloadsDirectory = targetFolder
            .appendingPathComponent(DownloadReference.locationName, isDirectory: true)
            .appendingPathComponent(bundleID.rawValue, isDirectory: true)
        if !fileManager.directoryExists(atPath: downloadsDirectory.path) {
            try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        // Copy all downloads into the output directory.
        for downloadAsset in context.registeredDownloadsAssets(for: bundleID) {
            try copyAsset(downloadAsset, to: downloadsDirectory)
        }

        // If the bundle contains a `header.html` file, inject a <template> into
        // the `index.html` file using its contents. This will only be done if
        // the --experimental-enable-custom-templates flag is given
        if let customHeader = bundle.customHeader, enableCustomTemplates {
            try injectCustomTemplate(customHeader, identifiedBy: .header)
        }

        // If the bundle contains a `footer.html` file, inject a <template> into
        // the `index.html` file using its contents. This will only be done if
        // the --experimental-enable-custom-templates flag is given
        if let customFooter = bundle.customFooter, enableCustomTemplates {
            try injectCustomTemplate(customFooter, identifiedBy: .footer)
        }

        // Copy the `theme-settings.json` file into the output directory if one
        // is provided. It will override any default `theme-settings.json` file
        // that the renderer template may already contain.
        if let themeSettings = bundle.themeSettings {
            let targetFile = targetFolder.appendingPathComponent(themeSettings.lastPathComponent, isDirectory: false)
            if fileManager.fileExists(atPath: targetFile.path) {
                try fileManager.removeItem(at: targetFile)
            }
            try fileManager._copyItem(at: themeSettings, to: targetFile)
        }
    }
    
    func consume(linkableElementSummaries summaries: [LinkDestinationSummary]) throws {
        let linkableElementsURL = targetFolder.appendingPathComponent(Self.linkableEntitiesFileName, isDirectory: false)
        let data = try encode(summaries)
        try fileManager.createFile(at: linkableElementsURL, contents: data)
    }
    
    func consume(indexingRecords: [IndexingRecord]) throws {
        let recordsURL = targetFolder.appendingPathComponent("indexing-records.json", isDirectory: false)
        let data = try encode(indexingRecords)
        try fileManager.createFile(at: recordsURL, contents: data)
    }
    
    func consume(assets: [RenderReferenceType : [any RenderReference]]) throws {
        let uniqueAssets = assets.mapValues({ referencesForTypeOfAsset in referencesForTypeOfAsset.uniqueElements(by: { $0.identifier }) })
        
        let digest = Digest.Assets(
            images: (uniqueAssets[.image] as? [ImageReference]) ?? [],
            videos: (uniqueAssets[.video] as? [VideoReference]) ?? [],
            downloads: (uniqueAssets[.download] as? [DownloadReference]) ?? []
        )

        let assetsURL = targetFolder.appendingPathComponent("assets.json", isDirectory: false)
        let data = try encode(digest)
        try fileManager.createFile(at: assetsURL, contents: data)
    }
    
    func consume(benchmarks: Benchmark) throws {
        let data = try encode(benchmarks)
        let benchmarkURL = targetFolder.appendingPathComponent("benchmark.json", isDirectory: false)
        try fileManager.createFile(at: benchmarkURL, contents: data)
    }

    func consume(documentationCoverageInfo: [CoverageDataEntry]) throws {
        let data = try encode(documentationCoverageInfo)
        let docCoverageURL = targetFolder.appendingPathComponent(Self.docCoverageFileName, isDirectory: false)
        try fileManager.createFile(at: docCoverageURL, contents: data)
    }
    
    func consume(buildMetadata: BuildMetadata) throws {
        let data = try encode(buildMetadata)
        let buildMetadataURL = targetFolder.appendingPathComponent(Self.buildMetadataFileName, isDirectory: false)
        try fileManager.createFile(at: buildMetadataURL, contents: data)
    }
    
    func consume(linkResolutionInformation: SerializableLinkResolutionInformation) throws {
        let data = try encode(linkResolutionInformation)
        let linkResolutionInfoURL = targetFolder.appendingPathComponent(Self.linkHierarchyFileName, isDirectory: false)
        
        try fileManager.createFile(at: linkResolutionInfoURL, contents: data)
    }
    
    /// Encodes the given value using the default render node JSON encoder.
    private func encode(_ value: some Encodable) throws -> Data {
        try makeEncoder().encode(value)
    }
    
    private func makeEncoder() -> JSONEncoder {
        RenderJSONEncoder.makeEncoder(assetPrefixComponent: assetPrefixComponent)
    }

    // Injects a <template> tag into the index.html <body> using the contents of
    // the given URL for the provided HTML file
    private func injectCustomTemplate(_ templateURL: URL, identifiedBy id: CustomTemplateIdentifier) throws {
        let index = targetFolder.appendingPathComponent("index.html", isDirectory: false)
        guard let indexData = fileManager.contents(atPath: index.path),
              let indexContents = String(data: indexData, encoding: .utf8),
              let templateData = fileManager.contents(atPath: templateURL.path),
              let templateContents = String(data: templateData, encoding: .utf8),
              let bodyTagRange = indexContents.range(of: "<body[^>]*>", options: .regularExpression) else {
            return
        }

        let template = "<template id=\"\(id.rawValue)\">\(templateContents)</template>"
        var newIndexContents = indexContents
        newIndexContents.replaceSubrange(bodyTagRange, with: indexContents[bodyTagRange] + template)
        try newIndexContents.write(to: index, atomically: true, encoding: .utf8)
    }
    
    /// File name for the documentation coverage file emitted during conversion.
    static var docCoverageFileName = "documentation-coverage.json"
    
    /// File name for the build metadata file emitted during conversion.
    static var buildMetadataFileName = "metadata.json"
    
    /// File name for the linkable entity file emitted during conversion.
    static var linkableEntitiesFileName = "linkable-entities.json"
    
    /// File name for the link hierarchy file emitted during conversion.
    static var linkHierarchyFileName = "link-hierarchy.json"
}

enum Digest {
    struct Assets: Codable {
        let images: [ImageReference]
        let videos: [VideoReference]
        let downloads: [DownloadReference]
    }
    
    @available(*, deprecated, message: "This deprecated API will be removed after 6.2 is released")
    struct Diagnostic: Codable {
        struct Location: Codable {
            let line: Int
            let column: Int
        }
        let start: Location?
        let source: URL?
        let severity: DiagnosticSeverity
        let summary: String
        let explanation: String?
        let notes: [Note]
        struct Note: Codable {
            let location: Location
            let message: String
        }
    }
}

@available(*, deprecated, message: "This deprecated API will be removed after 6.2 is released")
private extension Digest.Diagnostic {
    init(diagnostic: Diagnostic, rootURL: URL?) {
        self.start = (diagnostic.range?.lowerBound).map { Location(line: $0.line, column: $0.column) }
        self.source = rootURL.flatMap { diagnostic.source?.relative(to: $0) }
        self.severity = diagnostic.severity
        self.summary = diagnostic.summary
        self.explanation = diagnostic.explanation
        self.notes = diagnostic.notes.map {
            Note(location: Location(line: $0.range.lowerBound.line, column: $0.range.lowerBound.column), message: $0.message)
        }
    }
}
