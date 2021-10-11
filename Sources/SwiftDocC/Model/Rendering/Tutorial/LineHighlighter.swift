/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/**
 A utility type that computes highlighted lines for diffs between ``Code``
 elements in a ``TutorialSection``'s ``Step``s.
 
 The logic is tricky, so here's a diagram of what is going on here:
 ```
                          Start
                            |
              N -- < `previousFile`? > ----------------------- Y
              |                                                |
  N -- <  Previous `Code`? > -- Y                    N -- < `reset`? > -- Y
  |                             |                    |                    |
 [ ]               N -- < `name` match? > -- Y    Compare                [ ]
                   |                         |
                  [ ]              N -- < `reset`? > -- Y
                                   |                    |
                                Compare                [ ]
 ```
 */
public struct LineHighlighter {
    /**
     A local utility type to hold incremental results.
    */
    private struct IncrementalResult {
        /// The previous ``Code`` element to compare.
        /// If this is the first ``Step``'s ``Code``, this will be `nil`.
        let previousCode: Code?
        
        /// The highlight results accumulated so far.
        let results: [Result]
        
        init(previousCode: Code? = nil, results: [Result] = []) {
            self.previousCode = previousCode
            self.results = results
        }
    }
    
    /**
     The final resulting highlights for a given file.
     */
    struct Result {
        /// The file to be highlighted (or not).
        let file: ResourceReference
        
        /// The highlights to apply when displaying this file.
        let highlights: [Highlight]
    }
    
    /**
     A single line's highlight.
     */
    public struct Highlight: Codable {
        /// The line to highlight.
        public let line: Int
        
        /// If non-`nil`, the column to start the highlight.
        public let start: Int?
        
        /// If non-`nil`, the length of the highlight in columns.
        public let length: Int?
        
        /// Creates a new highlight for a single line.
        ///
        /// - Parameters:
        ///   - line: The line to highlight.
        ///   - start: The column in which to start the highlight.
        ///   - length: The character length of the highlight.
        public init(line: Int, start: Int? = nil, length: Int? = nil) {
            self.line = line
            self.start = start
            self.length = length
        }
    }
    
    /// The ``DocumentationContext`` to use for loading file lines.
    private let context: DocumentationContext
    
    /// The ``TutorialSection`` whose ``Steps`` will be analyzed for their code highlights.
    private let tutorialSection: TutorialSection
    
    init(context: DocumentationContext, tutorialSection: TutorialSection) {
        self.context = context
        self.tutorialSection = tutorialSection
    }
    
    /// The lines in the `resource` file.
    private func lines(of resource: ResourceReference) throws -> [String] {
        let data = try context.resource(with: ResourceReference(bundleIdentifier: resource.bundleIdentifier, path: resource.path))
        return String(data: data, encoding: .utf8)?.splitByNewlines ?? []
    }
    
    /// Returns the line highlights between two files.
    private func lineHighlights(old: ResourceReference, new: ResourceReference) -> Result {
        // Retrieve the contents of the current file and the file we're comparing against.
        guard let oldLines = try? lines(of: old),
            let newLines = try? lines(of: new) else {
                return Result(file: new, highlights: [])
        }

        let diff = newLines.difference(from: oldLines)
        
        // Convert the insertion offsets to `Highlight` values.
        let highlights = diff.insertions.compactMap { insertion -> Highlight? in
            guard case .insert(let offset, _, _) = insertion else { return nil }
            // Use 1-based indexing for line numbers.
            // TODO: Collect intra-line diffs.
            return Highlight(line: offset + 1)
        }
        
        return Result(file: new, highlights: highlights)
    }
    
    /// Returns the line highlights between two ``Code`` elements.
    private func lineHighlights(old: Code?, new: Code) -> Result {
        if let previousFileOverride = new.previousFileReference {
            guard !new.shouldResetDiff else {
                return Result(file: new.fileReference, highlights: [])
            }
            return lineHighlights(old: previousFileOverride, new: new.fileReference)
        }
        
        guard let old = old,
            old.fileName == new.fileName,
            !new.shouldResetDiff else {
                return Result(file: new.fileReference, highlights: [])
        }
        
        return lineHighlights(old: old.fileReference, new: new.fileReference)
    }
    
    /// The highlights to apply for the given ``TutorialSection``.
    var highlights: [Result] {
        return tutorialSection.stepsContent?.steps
            .compactMap { $0.code }
            .reduce(IncrementalResult(), { (incrementalResult, newCode) -> IncrementalResult in
                let result = lineHighlights(old: incrementalResult.previousCode, new: newCode)
                return IncrementalResult(previousCode: newCode, results: incrementalResult.results + [result])
            }).results ?? []
    }
}
