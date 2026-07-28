/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

enum HTMLTemplate: String {
    case templateFileName = "index-template.html"
    case indexFileName = "index.html"
    case tag = "{{BASE_PATH}}"
}

enum StaticHostableTransformerError: DescribedError {
    case dataProviderDoesNotReferenceValidInput(url: URL)
    
    var errorDescription: String {
        switch self {
        case .dataProviderDoesNotReferenceValidInput(let url):
            return """
            The content of `\(url.absoluteString)` is not in the format expected by the transformer.
            """
        }
    }
}

/// Navigates the contents of a FileSystemProvider pointing at the data folder of a `.doccarchive` to emit a static hostable website.
struct StaticHostableTransformer {
    /// The data directory to create static hostable files for.
    private let dataDirectory: URL
    /// The directory to write the static hostable files in.
    private let outputURL: URL
    /// The index.html contents to write for each static hostable file.
    private let indexHTMLData: Data
    /// The file manager used to create directories and files.
    private let fileManager: any FileManagerProtocol
    
    /// Initialize with a dataProvider to the source doccarchive.
    /// - Parameters:
    ///   - dataDirectory: The data directory to create static hostable files for.
    ///   - fileManager: The file manager used to create directories and files.
    ///   - outputURL: The output directory where the transformer will write the static hostable files in.
    ///   - indexHTMLData: Data representing the index.html content that the static
    init(dataDirectory: URL, fileManager: any FileManagerProtocol, outputURL: URL, indexHTMLData: Data) {
        self.dataDirectory = dataDirectory.standardizedFileURL
        self.fileManager = fileManager
        self.outputURL = outputURL.standardizedFileURL
        self.indexHTMLData = indexHTMLData
    }
    
    /// Creates a static hostable version of the documentation in the data folder of an archive pointed to by the `dataProvider`
    func transform() throws {
        for file in fileManager.recursiveFiles(startingPoint: dataDirectory) where file.pathExtension.lowercased() == "json" {
            // For each "/relative/something.json" file, create a "/relative/something/index.html" file.
            
            guard let relativeFileURL = file.relative(to: dataDirectory) else {
                // Our `URL.relative(to:)` extension only return `nil` if the URLComponents aren't valid.
                continue
            }
            
            let outputDirectoryURL = outputURL.appendingPathComponent(
                relativeFileURL.deletingPathExtension().path, // A directory with the same base name as the file
                isDirectory: true
            )

            // Ensure that the intermediate directories exist
            if !fileManager.fileExists(atPath: outputDirectoryURL.path) {
                try fileManager.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true, attributes: [:])
            }
            
            let outputIndexHTMLURL = outputDirectoryURL.appendingPathComponent("index.html")
            let outputIndexHTMLData = indexHTMLDataPreservingPageContent(
                at: outputIndexHTMLURL
            )

            try fileManager.createFile(
                at: outputIndexHTMLURL,
                contents: outputIndexHTMLData
            )
        }
    }

    private func indexHTMLDataPreservingPageContent(at outputURL: URL) -> Data {
        guard fileManager.fileExists(atPath: outputURL.path),
              let existingData = try? fileManager.contents(of: outputURL),
              let existingHTML = String(data: existingData, encoding: .utf8),
              let pageContent = PageSpecificHTMLContent(html: existingHTML),
              let templateHTML = String(data: indexHTMLData, encoding: .utf8),
              let updatedHTML = pageContent.inserting(into: templateHTML)
        else {
            return indexHTMLData
        }

        return Data(updatedHTML.utf8)
    }
}

private struct PageSpecificHTMLContent {
    let title: String
    let description: String?
    let noScriptContent: String

    init?(html: String) {
        guard
            let titleRange = Self.contentRange(of: "title", in: html),
            let noScriptRange = Self.contentRange(of: "noscript", in: html)
        else {
            return nil
        }

        let noScriptContent = String(html[noScriptRange])

        // Contentful route HTML uses an article as its semantic fallback.
        guard noScriptContent.range(
            of: #"<article(?:\s|>)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil else {
            return nil
        }

        self.title = String(html[titleRange])
        self.description = Self.descriptionRange(in: html).map {
            String(html[$0])
        }
        self.noScriptContent = noScriptContent
    }

    func inserting(into template: String) -> String? {
        var result = template

        guard let noScriptRange = Self.contentRange(
            of: "noscript",
            in: result
        ) else {
            return nil
        }
        result.replaceSubrange(noScriptRange, with: noScriptContent)

        if let existingDescriptionRange = Self.descriptionRange(in: result) {
            result.replaceSubrange(
                existingDescriptionRange,
                with: description ?? ""
            )
        } else if let description {
            guard let headRange = Self.contentRange(
                of: "head",
                in: result
            ) else {
                return nil
            }
            result.insert(contentsOf: description, at: headRange.upperBound)
        }

        guard let titleRange = Self.contentRange(
            of: "title",
            in: result
        ) else {
            return nil
        }
        result.replaceSubrange(titleRange, with: title)

        return result
    }

    private static func contentRange(
        of elementName: String,
        in html: String
    ) -> Range<String.Index>? {
        guard
            let openingTag = html.range(
                of: "<\(elementName)\\b[^>]*>",
                options: [.regularExpression, .caseInsensitive]
            ),
            let closingTag = html.range(
                of: "</\(elementName)\\s*>",
                options: [.regularExpression, .caseInsensitive],
                range: openingTag.upperBound..<html.endIndex
            )
        else {
            return nil
        }

        return openingTag.upperBound..<closingTag.lowerBound
    }

    private static func descriptionRange(
        in html: String
    ) -> Range<String.Index>? {
        guard let headRange = contentRange(of: "head", in: html) else {
            return nil
        }

        return html.range(
            of: #"<meta\b[^>]*\bname\s*=\s*["']description["'][^>]*\/?>"#,
            options: [.regularExpression, .caseInsensitive],
            range: headRange
        )
    }
}

extension StaticHostableTransformer {
    
    /// Returns the data for the `index.html` file that should be used in the DocC archive
    /// produced by this conversion.
    ///
    /// Takes into account whether or not a custom hosting base path is provided and inserts
    /// that path into the returned data if necessary.
    ///
    /// - Parameters:
    ///   - htmlTemplateDirectory: The directory containing the `index.html` and `index-template.html`
    ///     file that should be used.
    ///   - hostingBasePath: The base path the produced DocC archive will be hosted at.
    ///   - fileManager: The file manager that should be used for all file operations.
    static func indexHTMLData(
        in htmlTemplateDirectory: URL,
        with hostingBasePath: String?,
        fileManager: any FileManagerProtocol
    ) throws -> Data {
        let customHostingBasePathProvided = !(hostingBasePath?.isEmpty ?? true)
        
        let indexHTMLFileName = if customHostingBasePathProvided {
            HTMLTemplate.templateFileName.rawValue
        } else {
            HTMLTemplate.indexFileName.rawValue
        }
        
        let indexHTMLFile = htmlTemplateDirectory.appendingPathComponent(indexHTMLFileName, isDirectory: false)
        
        guard let indexHTMLData = try? fileManager.contents(of: indexHTMLFile),
              var indexHTML = String(data: indexHTMLData, encoding: .utf8)
        else {
            throw TemplateOption.missingRequiredFile(fileName: indexHTMLFileName, inHTMLTemplateAt: htmlTemplateDirectory)
        }
        
        if customHostingBasePathProvided, var replacementString = hostingBasePath {
            // We need to ensure that the base path has a leading /
            if !replacementString.hasPrefix("/") {
                replacementString = "/" + replacementString
            }

            // Trailing /'s are not required so will be removed if provided.
            if replacementString.hasSuffix("/") {
                replacementString = String(replacementString.dropLast(1))
            }

            indexHTML = indexHTML.replacingOccurrences(of: HTMLTemplate.tag.rawValue, with: replacementString)
        }
        
        return Data(indexHTML.utf8)
    }
}
