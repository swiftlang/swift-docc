/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A section of a Tutorial page.
public struct TutorialSectionsRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .tasks
    
    /// The tasks in the section.
    public var tasks: [Section]
    
    /// A render-friendly representation of a tutorial section.
    public struct Section: TextIndexing, Equatable {
        /// The title of the section.
        public var title: String

        /// The content of this section.
        public var contentSection: [ContentLayout]

        /// A list of tutorial steps for this section.
        public var stepsSection: [RenderBlockContent]

        /// An identifier for this section.
        ///
        /// You can use this value to identify the section.
        /// For example, a documentation renderer might use it to create direct links to this section.
        public var anchor: String

        /// Creates a new section for a tutorial page.
        ///
        /// - Parameters:
        ///   - title: The title of the section.
        ///   - contentSection: The main content of the section.
        ///   - stepsSection: A list of tutorial steps for this section.
        ///   - anchor: An identifier for this tutorial section.
        public init(title: String, contentSection: [ContentLayout], stepsSection: [RenderBlockContent], anchor: String) {
            self.title = title
            self.contentSection = contentSection
            self.stepsSection = stepsSection
            self.anchor = anchor
        }
    }
    
    /// Creates a new section for a tutorial from a list of child sections.
    ///
    /// - Parameter sections: A list of child sections.
    public init(sections: [Section]) {
        self.tasks = sections
    }
}

extension TutorialSectionsRenderSection.Section: Codable {
    private enum CodingKeys: CodingKey {
        case contentSection
        case stepsSection
        case anchor
        case title
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        contentSection = try container.decode([ContentLayout].self, forKey: .contentSection)
        stepsSection = try container.decode([RenderBlockContent].self, forKey: .stepsSection)
        anchor = try container.decode(String.self, forKey: .anchor)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(contentSection, forKey: .contentSection)
        try container.encode(stepsSection, forKey: .stepsSection)
        try container.encode(anchor, forKey: .anchor)
    }
}

// Diffable conformance
extension TutorialSectionsRenderSection: RenderJSONDiffable {
    /// Returns the differences between this TutorialSectionsRenderSection and the given one.
    func difference(from other: TutorialSectionsRenderSection, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.tasks, forKey: CodingKeys.tasks)

        return diffBuilder.differences
    }

    /// Returns if this TutorialSectionsRenderSection is similar enough to the given one.
    func isSimilar(to other: TutorialSectionsRenderSection) -> Bool {
        return self.tasks == other.tasks
    }
}

// Diffable conformance
extension TutorialSectionsRenderSection.Section: RenderJSONDiffable {
    /// Returns the differences between this Section and the given one.
    func difference(from other: TutorialSectionsRenderSection.Section, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.title, forKey: CodingKeys.title)
        diffBuilder.addDifferences(atKeyPath: \.contentSection, forKey: CodingKeys.contentSection)
        diffBuilder.addDifferences(atKeyPath: \.stepsSection, forKey: CodingKeys.stepsSection)
        diffBuilder.addDifferences(atKeyPath: \.anchor, forKey: CodingKeys.contentSection)

        return diffBuilder.differences
    }

    /// Returns if this Section is similar enough to the given one.
    func isSimilar(to other: TutorialSectionsRenderSection.Section) -> Bool {
        return self.title == other.title || self.contentSection == other.contentSection
    }
}
