/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import SymbolKit

// MARK: - Comment Style for different languages

/// Defines comment syntax for different programming languages
enum SnippetCommentStyle: Sendable {
    case lineComment(String)  // e.g., "//" for Swift, C, C++, JavaScript
    case blockComment(String, String)  // e.g., "/*" and "*/" for C, C++
    case hashComment(String)  // e.g., "#" for Python, Shell
    case xmlComment(String, String)  // e.g., "<!--" and "-->" for HTML, XML

    /// Check if a line starts with this comment style
    func isCommentLine(_ line: String) -> Bool {
        switch self {
        case .lineComment(let marker):
            return line.trimmingCharacters(in: .whitespaces).hasPrefix(marker)
        case .blockComment(let start, _):
            return line.trimmingCharacters(in: .whitespaces).hasPrefix(start)
        case .hashComment(let marker):
            return line.trimmingCharacters(in: .whitespaces).hasPrefix(marker)
        case .xmlComment(let start, _):
            return line.trimmingCharacters(in: .whitespaces).hasPrefix(start)
        }
    }

    /// Extract snippet region name from a comment line if it matches the pattern
    func extractRegionName(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        switch self {
        case .lineComment(let marker), .hashComment(let marker):
            // Pattern: // snippet.name or # snippet.name
            let prefix = marker + " snippet."
            if trimmed.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
            // Check for snippet.end
            let endPrefix = marker + " snippet.end"
            if trimmed == endPrefix || trimmed.hasPrefix(endPrefix + " ") {
                return nil  // End marker
            }
        case .blockComment(let start, let end):
            // Pattern: /* snippet.name or /* snippet.end
            let prefix = start + " snippet."
            if trimmed.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count)).replacingOccurrences(
                    of: end, with: ""
                ).trimmingCharacters(in: .whitespaces)
            }
            let endMarker = start + " snippet.end"
            if trimmed.hasPrefix(endMarker) {
                return nil  // End marker
            }
        case .xmlComment(let start, let end):
            // Pattern: <!-- snippet.name or <!-- snippet.end
            let prefix = start + " snippet."
            if trimmed.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count)).replacingOccurrences(
                    of: end, with: ""
                ).trimmingCharacters(in: .whitespaces)
            }
            let endMarker = start + " snippet.end"
            if trimmed.hasPrefix(endMarker) {
                return nil  // End marker
            }
        }
        return nil
    }
}

// MARK: - Language Configuration

/// Configuration for a specific language's snippet parsing
struct SnippetLanguageConfig: Sendable {
    let languageID: String
    let commentStyle: SnippetCommentStyle
    let fileExtensions: Set<String>
}

/// Registry of supported languages
struct SnippetLanguageRegistry: Sendable {
    static let configurations: [String: SnippetLanguageConfig] = [
        "swift": SnippetLanguageConfig(
            languageID: "swift",
            commentStyle: .lineComment("//"),
            fileExtensions: ["swift"]
        ),
        "c": SnippetLanguageConfig(
            languageID: "c",
            commentStyle: .blockComment("/*", "*/"),
            fileExtensions: ["c", "h"]
        ),
        "cpp": SnippetLanguageConfig(
            languageID: "cpp",
            commentStyle: .blockComment("/*", "*/"),
            fileExtensions: ["cpp", "cc", "cxx", "hpp", "hh", "hxx"]
        ),
        "objective-c": SnippetLanguageConfig(
            languageID: "objectivec",
            commentStyle: .blockComment("/*", "*/"),
            fileExtensions: ["m", "mm"]
        ),
        "javascript": SnippetLanguageConfig(
            languageID: "javascript",
            commentStyle: .lineComment("//"),
            fileExtensions: ["js", "jsx"]
        ),
        "typescript": SnippetLanguageConfig(
            languageID: "typescript",
            commentStyle: .lineComment("//"),
            fileExtensions: ["ts", "tsx"]
        ),
        "python": SnippetLanguageConfig(
            languageID: "python",
            commentStyle: .hashComment("#"),
            fileExtensions: ["py"]
        ),
        "shell": SnippetLanguageConfig(
            languageID: "shell",
            commentStyle: .hashComment("#"),
            fileExtensions: ["sh", "bash", "zsh"]
        ),
        "go": SnippetLanguageConfig(
            languageID: "go",
            commentStyle: .lineComment("//"),
            fileExtensions: ["go"]
        ),
        "rust": SnippetLanguageConfig(
            languageID: "rust",
            commentStyle: .lineComment("//"),
            fileExtensions: ["rs"]
        ),
        "ruby": SnippetLanguageConfig(
            languageID: "ruby",
            commentStyle: .hashComment("#"),
            fileExtensions: ["rb"]
        ),
        "java": SnippetLanguageConfig(
            languageID: "java",
            commentStyle: .lineComment("//"),
            fileExtensions: ["java"]
        ),
        "kotlin": SnippetLanguageConfig(
            languageID: "kotlin",
            commentStyle: .lineComment("//"),
            fileExtensions: ["kt", "kts"]
        ),
        "html": SnippetLanguageConfig(
            languageID: "html",
            commentStyle: .xmlComment("<!--", "-->"),
            fileExtensions: ["html", "htm"]
        ),
        "markdown": SnippetLanguageConfig(
            languageID: "markdown",
            commentStyle: .lineComment(""),
            fileExtensions: ["md", "markdown"]
        ),
    ]

    static func configuration(forExtension ext: String) -> SnippetLanguageConfig? {
        return configurations.values.first { $0.fileExtensions.contains(ext.lowercased()) }
    }

    static func configuration(forLanguageID id: String) -> SnippetLanguageConfig? {
        return configurations[id]
    }
}

// MARK: - Region Extractor

/// Extracts snippet regions from source files
struct RegionExtractor: Sendable {
    /// Parse regions from lines of source code
    func parseRegions(in lines: [String], using style: SnippetCommentStyle) -> [String: Range<Int>]
    {
        var slices: [String: Range<Int>] = [:]
        var currentSliceStart: Int?
        var currentSliceName: String?

        for (index, line) in lines.enumerated() {
            if let regionName = style.extractRegionName(from: line) {
                if let existingStart = currentSliceStart, let existingName = currentSliceName {
                    // Close previous slice
                    slices[existingName] = existingStart..<index
                }
                // Start new slice
                currentSliceName = regionName
                currentSliceStart = index + 1  // Start after the marker line
            } else if style.isCommentLine(line) {
                // Check for end marker
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let isEndMarker: Bool
                switch style {
                case .lineComment(let marker):
                    isEndMarker =
                        trimmed == "\(marker) snippet.end"
                        || trimmed.hasPrefix("\(marker) snippet.end ")
                case .hashComment(let marker):
                    isEndMarker =
                        trimmed == "\(marker) snippet.end"
                        || trimmed.hasPrefix("\(marker) snippet.end ")
                case .blockComment(let start, let end):
                    isEndMarker =
                        trimmed == "\(start) snippet.end\(end)"
                        || trimmed.hasPrefix("\(start) snippet.end ")
                case .xmlComment(let start, let end):
                    isEndMarker =
                        trimmed == "\(start) snippet.end\(end)"
                        || trimmed.hasPrefix("\(start) snippet.end ")
                }

                if isEndMarker, let existingStart = currentSliceStart,
                    let existingName = currentSliceName
                {
                    slices[existingName] = existingStart..<index
                    currentSliceStart = nil
                    currentSliceName = nil
                }
            }
        }

        // Close final slice if still open
        if let finalStart = currentSliceStart, let finalName = currentSliceName {
            slices[finalName] = finalStart..<lines.count
        }

        return slices
    }
}

// MARK: - External Source Directory

/// Configuration for external source directories to scan
struct ExternalSourceDirectory: Sendable {
    let url: URL
    let recursive: Bool
    let fileExtensions: Set<String>

    init(url: URL, recursive: Bool = true, fileExtensions: Set<String>? = nil) {
        self.url = url
        self.recursive = recursive
        // Default to all registered extensions if not specified
        self.fileExtensions =
            fileExtensions
            ?? Set(SnippetLanguageRegistry.configurations.values.flatMap { $0.fileExtensions })
    }
}

// MARK: - Snippet Resolver

/// A type that resolves snippet paths.
final class SnippetResolver {
    typealias SnippetMixin = SymbolKit.SymbolGraph.Symbol.Snippet
    typealias Explanation = Markdown.Document

    /// Information about a resolved snippet
    struct ResolvedSnippet {
        fileprivate var path: String  // For use in diagnostics
        var mixin: SnippetMixin
        var explanation: Explanation?
    }
    /// A snippet that has been resolved, either successfully or not.
    enum SnippetResolutionResult {
        case success(ResolvedSnippet)
        case failure(TopicReferenceResolutionErrorInfo)
    }

    private var snippets: [String: ResolvedSnippet] = [:]

    /// External source directories to search for snippets
    private var externalSourceDirectories: [ExternalSourceDirectory] = []

    /// Region extractor for parsing snippet regions
    private let regionExtractor = RegionExtractor()

    /// Whether external file loading has been attempted
    private var externalFilesLoaded = false

    init(symbolGraphLoader: SymbolGraphLoader) {
        var snippets: [String: ResolvedSnippet] = [:]

        for graph in symbolGraphLoader.snippetSymbolGraphs.values {
            for symbol in graph.symbols.values {
                guard let snippetMixin = symbol[mixin: SnippetMixin.self] else { continue }

                let path: String =
                    if symbol.pathComponents.first == "Snippets" {
                        symbol.pathComponents.dropFirst().joined(separator: "/")
                    } else {
                        symbol.pathComponents.joined(separator: "/")
                    }

                snippets[path] = .init(
                    path: path, mixin: snippetMixin,
                    explanation: symbol.docComment.map {
                        Document(
                            parsing: $0.lines.map(\.text).joined(separator: "\n"),
                            options: .parseBlockDirectives)
                    })
            }
        }

        self.snippets = snippets
    }

    /// Initialize with external source directories for non-Swift snippet support
    init(
        symbolGraphLoader: SymbolGraphLoader,
        externalSourceDirectories: [ExternalSourceDirectory] = []
    ) {
        // Initialize snippets from symbol graph (same as the other initializer)
        var loadedSnippets: [String: ResolvedSnippet] = [:]

        for graph in symbolGraphLoader.snippetSymbolGraphs.values {
            for symbol in graph.symbols.values {
                guard let snippetMixin = symbol[mixin: SnippetMixin.self] else { continue }

                let path: String =
                    if symbol.pathComponents.first == "Snippets" {
                        symbol.pathComponents.dropFirst().joined(separator: "/")
                    } else {
                        symbol.pathComponents.joined(separator: "/")
                    }

                loadedSnippets[path] = .init(
                    path: path, mixin: snippetMixin,
                    explanation: symbol.docComment.map {
                        Document(
                            parsing: $0.lines.map(\.text).joined(separator: "\n"),
                            options: .parseBlockDirectives)
                    })
            }
        }

        self.snippets = loadedSnippets
        self.externalSourceDirectories = externalSourceDirectories
    }

    /// Load external source files as snippets (lazy loading)
    private func loadExternalSnippetsIfNeeded() {
        guard !externalFilesLoaded, !externalSourceDirectories.isEmpty else { return }
        externalFilesLoaded = true

        let fileManager = FileManager.default

        // Discover and load all potential snippet files
        for directory in externalSourceDirectories {
            guard
                let enumerator = fileManager.enumerator(
                    at: directory.url,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: directory.recursive ? [] : [.skipsSubdirectoryDescendants]
                )
            else { continue }

            for case let fileURL as URL in enumerator {
                guard
                    let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                    resourceValues.isRegularFile == true
                else { continue }

                let ext = fileURL.pathExtension.lowercased()
                guard directory.fileExtensions.contains(ext) else { continue }

                do {
                    let snippet = try parseExternalFile(at: fileURL)

                    // Create a path from the file relative to its source directory
                    let relativePath = makeRelativePath(for: fileURL)

                    // Create the resolved snippet
                    let resolvedSnippet = ResolvedSnippet(
                        path: relativePath,
                        mixin: snippet,
                        explanation: nil
                    )

                    snippets[relativePath] = resolvedSnippet
                } catch {
                    // Log but don't fail - unsupported files are skipped
                    continue
                }
            }
        }
    }

    /// Parse an external source file as a snippet
    private func parseExternalFile(at url: URL) throws -> SnippetMixin {
        let ext = url.pathExtension.lowercased()

        guard let config = SnippetLanguageRegistry.configuration(forExtension: ext) else {
            throw NSError(
                domain: "SnippetResolver", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported file extension: \(ext)"])
        }

        // Read file contents
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        // Parse regions using the appropriate comment style
        let slices = regionExtractor.parseRegions(in: lines, using: config.commentStyle)

        let snippetMixin = SnippetMixin(
            language: config.languageID,
            lines: lines,
            slices: slices
        )

        return snippetMixin
    }

    /// Create a relative path from a file URL
    private func makeRelativePath(for fileURL: URL) -> String {
        // Find the matching base directory
        for directory in externalSourceDirectories {
            if fileURL.path.hasPrefix(directory.url.path) {
                var relativePath = String(fileURL.path.dropFirst(directory.url.path.count))
                // Remove leading slash if present
                if relativePath.hasPrefix("/") {
                    relativePath = String(relativePath.dropFirst())
                }
                // Remove file extension for consistency with Swift snippets
                if let dotIndex = relativePath.lastIndex(of: ".") {
                    relativePath = String(relativePath[..<dotIndex])
                }
                return relativePath
            }
        }
        // Fallback: just use filename without extension
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        return fileName
    }

    func resolveSnippet(path authoredPath: String) -> SnippetResolutionResult {
        // Load external snippets lazily on first resolution attempt
        loadExternalSnippetsIfNeeded()

        // Snippet paths are relative to the root of the Swift Package.
        // The first two components are always the same (the package name followed by "Snippets").
        // The later components can either be subdirectories of the "Snippets" directory or the base name of a snippet '.swift' file (without the extension).

        // Drop the common package name + "Snippets" prefix (that's always the same), if the authored path includes it.
        // This enables the author to omit this prefix (but include it for backwards compatibility with older DocC versions).
        var components = authoredPath.split(separator: "/", omittingEmptySubsequences: true)

        // It's possible that the package name is "Snippets", resulting in two identical components. Skip until the last of those two.
        if let snippetsPrefixIndex = components.prefix(2).lastIndex(of: "Snippets"),
            // Don't search for an empty string if the snippet happens to be named "Snippets"
            let relativePathStart = components.index(
                snippetsPrefixIndex, offsetBy: 1, limitedBy: components.endIndex - 1)
        {
            components.removeFirst(relativePathStart)
        }

        let path = components.joined(separator: "/")
        if let found = snippets[path] {
            return .success(found)
        } else {
            let replacementRange = SourceRange.makeRelativeRange(
                startColumn: authoredPath.utf8.count - path.utf8.count, length: path.utf8.count)

            let nearMisses = NearMiss.bestMatches(for: snippets.keys, against: path)
            let solutions = nearMisses.map { candidate in
                Solution(
                    summary: "\(Self.replacementOperationDescription(from: path, to: candidate))",
                    replacements: [
                        Replacement(range: replacementRange, replacement: candidate)
                    ])
            }

            return .failure(
                .init(
                    "Snippet named '\(path)' couldn't be found", solutions: solutions,
                    rangeAdjustment: replacementRange))
        }
    }

    func validate(slice: String, for resolvedSnippet: ResolvedSnippet)
        -> TopicReferenceResolutionErrorInfo?
    {
        guard resolvedSnippet.mixin.slices[slice] == nil else {
            return nil
        }
        let replacementRange = SourceRange.makeRelativeRange(
            startColumn: 0, length: slice.utf8.count)

        let nearMisses = NearMiss.bestMatches(
            for: resolvedSnippet.mixin.slices.keys, against: slice)
        let solutions = nearMisses.map { candidate in
            Solution(
                summary: "\(Self.replacementOperationDescription(from: slice, to: candidate))",
                replacements: [
                    Replacement(range: replacementRange, replacement: candidate)
                ])
        }

        return .init(
            "Slice named '\(slice)' doesn't exist in snippet '\(resolvedSnippet.path)'",
            solutions: solutions)
    }
}

// MARK: Diagnostics

extension SnippetResolver {
    static func unknownSnippetSliceProblem(
        source: URL?, range: SourceRange?, errorInfo: TopicReferenceResolutionErrorInfo
    ) -> Problem {
        _problem(
            source: source, range: range, errorInfo: errorInfo,
            id: "org.swift.docc.unknownSnippetPath")
    }

    static func unresolvedSnippetPathProblem(
        source: URL?, range: SourceRange?, errorInfo: TopicReferenceResolutionErrorInfo
    ) -> Problem {
        _problem(
            source: source, range: range, errorInfo: errorInfo,
            id: "org.swift.docc.unresolvedSnippetPath")
    }

    private static func _problem(
        source: URL?, range: SourceRange?, errorInfo: TopicReferenceResolutionErrorInfo, id: String
    ) -> Problem {
        var solutions: [Solution] = []
        var notes: [DiagnosticNote] = []
        if let range {
            if let note = errorInfo.note, let source {
                notes.append(DiagnosticNote(source: source, range: range, message: note))
            }

            solutions.append(contentsOf: errorInfo.solutions(referenceSourceRange: range))
        }

        let diagnosticRange: SourceRange?
        if var rangeAdjustment = errorInfo.rangeAdjustment, let range {
            rangeAdjustment.offsetWithRange(range)
            assert(
                rangeAdjustment.lowerBound.column >= 0,
                """
                Unresolved snippet reference range adjustment created range with negative column.
                Source: \(source?.absoluteString ?? "nil")
                Range: \(rangeAdjustment.lowerBound.description):\(rangeAdjustment.upperBound.description)
                Summary: \(errorInfo.message)
                """)
            diagnosticRange = rangeAdjustment
        } else {
            diagnosticRange = range
        }

        let diagnostic = Diagnostic(
            source: source, severity: .warning, range: diagnosticRange, identifier: id,
            summary: errorInfo.message, notes: notes)
        return Problem(diagnostic: diagnostic, possibleSolutions: solutions)
    }

    private static func replacementOperationDescription(
        from: some StringProtocol, to: some StringProtocol
    ) -> String {
        if from.isEmpty {
            return "Insert \(to.singleQuoted)"
        }
        if to.isEmpty {
            return "Remove \(from.singleQuoted)"
        }
        return "Replace \(from.singleQuoted) with \(to.singleQuoted)"
    }
}
