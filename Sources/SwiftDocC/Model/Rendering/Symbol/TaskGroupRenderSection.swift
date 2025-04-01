/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A task group section that contains links to other symbols.
public struct TaskGroupRenderSection: RenderSection, Equatable {
    public let kind: RenderSectionKind = .taskGroup
    
    /// An optional title for the section.
    public let title: String?
    /// An optional abstract summary for the section.
    public let abstract: [RenderInlineContent]?
    /// An optional discussion for the section.
    public var discussion: (any RenderSection)? {
        get {
            typeErasedSection?.value
        }
        set {
            if let newValue {
                typeErasedSection = AnyRenderSection(newValue)
            } else {
                typeErasedSection = nil
            }
        }
    }

    private var typeErasedSection: AnyRenderSection?
    
    /// A list of topic graph references.
    public let identifiers: [String]
    /// If true, this is an automatically generated group. If false, this is an authored group.
    public let generated: Bool
    /// An optional anchor that can be used to link to the task group.
    public let anchor: String?
    
    /// Creates a new task group.
    /// - Parameters:
    ///   - title: An optional title for the section.
    ///   - abstract: An optional abstract summary for the section.
    ///   - discussion: An optional discussion for the section.
    ///   - identifiers: A list of topic-graph references.
    ///   - generated: If `true`, this is an automatically generated group. If `false`, this is an authored group.
    ///   - anchor: An optional anchor that can be used to link to the task group.
    public init(title: String?, abstract: [RenderInlineContent]?, discussion: (any RenderSection)?, identifiers: [String], generated: Bool = false, anchor: String? = nil) {
        self.title = title
        self.abstract = abstract
        self.identifiers = identifiers
        self.generated = generated
        self.anchor = anchor ?? title.map(urlReadableFragment)
        self.discussion = discussion
    }
    
    /// The list of keys you use to encode or decode this section.
    private enum CodingKeys: CodingKey {
        case title, abstract, discussion, identifiers, generated, anchor
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(abstract, forKey: .abstract)
        try container.encodeIfPresent(discussion.map(CodableRenderSection.init), forKey: .discussion)
        try container.encode(identifiers, forKey: .identifiers)
        if generated {
            try container.encode(generated, forKey: .generated)
        }
        try container.encodeIfPresent(anchor, forKey: .anchor)
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decodeIfPresent(String.self, forKey: .title)
        abstract = try container.decodeIfPresent([RenderInlineContent].self, forKey: .abstract)
        identifiers = try container.decode([String].self, forKey: .identifiers)

        decoder.registerReferences(identifiers)

        generated = try container.decodeIfPresent(Bool.self, forKey: .generated) ?? false
        anchor = try container.decodeIfPresent(String.self, forKey: .anchor)
        discussion = (try container.decodeIfPresent(CodableContentSection.self, forKey: .discussion)).map { $0.section }
    }
}

extension TaskGroupRenderSection {

    /// Creates a new instance with the given automatically curated task group data.
    init(taskGroup group: AutomaticCuration.TaskGroup) {
        self.title = group.title
        self.abstract = nil
        self.identifiers = group.references.map({ $0.absoluteString })
        self.generated = true
        self.anchor = group.title.map(urlReadableFragment)
        self.discussion = nil
    }
}

// Conformance to Diffable
extension TaskGroupRenderSection: RenderJSONDiffable {
    /// Returns the differences between this TaskGroupRenderSection and the given one.
    func difference(from other: TaskGroupRenderSection, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.title, forKey: CodingKeys.title)
        diffBuilder.addDifferences(atKeyPath: \.abstract, forKey: CodingKeys.abstract)
        diffBuilder.addDifferences(atKeyPath: \.discussion, forKey: CodingKeys.discussion)
        diffBuilder.addDifferences(atKeyPath: \.identifiers, forKey: CodingKeys.identifiers)
        diffBuilder.addDifferences(atKeyPath: \.generated, forKey: CodingKeys.generated)
        
        return diffBuilder.differences
    }

    /// Returns if this TaskGroupRenderSection is similar enough to the given one.
    func isSimilar(to other: TaskGroupRenderSection) -> Bool {
        return ((self.title != nil) && self.title == other.title) ||
               ((self.abstract != nil) && self.abstract == other.abstract) ||
               self.identifiers == other.identifiers
    }
}
