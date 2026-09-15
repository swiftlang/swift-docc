/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
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
    public struct Highlight: Codable, Equatable {
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
    
    /// The topic reference of the tutorial whose section will be analyzed for their code highlights.
    private let tutorialReference: ResolvedTopicReference
    
    init(context: DocumentationContext, tutorialSection: TutorialSection, tutorialReference: ResolvedTopicReference) {
        self.context = context
        self.tutorialSection = tutorialSection
        self.tutorialReference = tutorialReference
    }
    
    /// The lines in the `resource` file.
    private func lines(of resource: borrowing ResourceReference) -> [String]? {
        let fileContent: String?
        // Check if the file is a local asset that can be read directly from the context
        if let fileData = try? context.resource(with: resource) {
            fileContent = String(data: fileData, encoding: .utf8)
        }
        // Check if the file needs to be resolved to read its content
        else if let asset = context.resolveAsset(named: resource.path, in: tutorialReference) {
            fileContent = try? String(contentsOf: asset.data(bestMatching: DataTraitCollection()).url, encoding: .utf8)
        }
        // Couldn't find the file reference's content
        else {
            fileContent = nil
        }
        return fileContent?.splitByNewlines
    }
    
    /// Returns the line highlights between two files.
    private func lineHighlights(old: borrowing ResourceReference, new: ResourceReference) -> Result {
        // Retrieve the contents of the current file and the file we're comparing against.
        guard let oldLines = lines(of: old), let newLines = lines(of: new) else {
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
    private func lineHighlights(old: consuming Code?, new: borrowing Code) -> Result {
        if let previousFileOverride = new.previousFileReference {
            guard !new.shouldResetDiff else {
                return Result(file: new.fileReference, highlights: [])
            }
            return lineHighlights(old: previousFileOverride, new: new.fileReference)
        }
        
        guard let old,
            old.fileName == new.fileName,
            !new.shouldResetDiff else {
                return Result(file: new.fileReference, highlights: [])
        }
        
        return lineHighlights(old: old.fileReference, new: new.fileReference)
    }
    
    /// The highlights to apply for the given ``TutorialSection``.
    var highlights: [Result] {
        guard let steps = tutorialSection.stepsContent?.steps else { return [] }
        
        var previousCode: Code? = nil
        var results: [Result] = []
        
        for step in steps {
            guard let newCode = step.code else { continue }
            results.append(lineHighlights(old: previousCode, new: newCode))
            previousCode = newCode
        }
        
        return results
    }
}
