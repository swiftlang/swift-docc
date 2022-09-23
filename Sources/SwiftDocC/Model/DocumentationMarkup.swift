/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A structured documentation markup data model.
///
/// ## Discussion
/// `DocumentationMarkup` parses a given piece of structured markup and provides access to the documentation content.
///
/// ### Title
/// The parser parses the title from the first level-one heading. If the markup doesn't start with a level-one heading, it's considered to not have a title.
/// ```
/// # My Document
/// ```
/// ### Abstract
/// The parser parses the abstract from the first leading paragraph (skipping the comments) in the markup after the title. If the markup doesn't start with a paragraph after the title heading, it's considered to not have an abstract.
/// ```
/// # My Document
/// An abstract shortly describing My Document.
/// ```
/// ### Discussion
/// The parser parses the discussion from the end of the abstract section until a "Topics" or "See Also" section is found (or the end of the document).
/// ```
/// # My Document
/// An abstract shortly describing My Document.
/// ## Discussion
/// A discussion that may contain further level-3 sub-sections, text, images, etc.
/// ```
/// ### Topics
/// The parser parses the topics from the end of the discussion section until a "See Also" section is found or the end of the document.
/// Links are organized inside "Topics" into task groups beginning with a level-3 heading.
/// ```
/// ## Topics
/// ### Basics
///  - <doc:article>
///  - ``MyClass``
/// ```
/// ### See Also
/// The parser parses the see also links from the end of the topics section until the end of the document.
/// "See Also" contains a flat list of links.
/// ```
/// ## See Also
///  - [website](https://website.com)
/// ```
struct DocumentationMarkup {
    /// The original markup.
    private let markup: Markup

    /// The various sections that are expected in documentation markup.
    ///
    /// The cases in this enumeration are sorted in the order sections are expected to appear in the documentation markup.
    /// For example the Discussion section is always expected to appear before the See Also section. This also enables
    /// ``init(markup:parseUpToSection:)`` to partially parse a document up to a given section.
    enum ParserSection: Int, Comparable {
        static func < (lhs: DocumentationMarkup.ParserSection, rhs: DocumentationMarkup.ParserSection) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
        case title
        case abstract
        case discussion
        case topics
        case seeAlso
        case end
    }
    
    // MARK: - Parsed Data
    
    /// The documentation title, if found.
    private(set) var titleHeading: Heading?
    
    /// The documentation abstract, if found.
    private(set) var abstractSection: AbstractSection?

    /// The documentation Discussion section, if found.
    private(set) var discussionSection: DiscussionSection?
    
    /// The documentation tags, if found.
    private(set) var discussionTags: TaggedListItemExtractor?
    
    /// The documentation Topics section, if found.
    private(set) var topicsSection: TopicsSection?

    /// The documentation See Also, if found.
    private(set) var seeAlsoSection: SeeAlsoSection?
    
    /// The symbol deprecation information, if found.
    private(set) var deprecation: MarkupContainer?
    
    // MARK: - Initialize and parse the markup

    /// Initialize a documentation model with the given markup.
    /// - Parameters:
    ///   - markup: The source markup.
    ///   - parseUpToSection: Documentation past this section will be ignored.
    init(markup: Markup, parseUpToSection: ParserSection = .end) {
        self.markup = markup
        
        // The current documentation section being parsed.
        var currentSection = ParserSection.title
        
        // Tracking the start indexes of various sections.
        var discussionIndex: Int?
        var topicsIndex: Int?
        var topicsFirstTaskGroupIndex: Int?
        var seeAlsoIndex: Int?
        
        // Index all headings as a lookup during parsing the content
        markup.children.enumerated().forEach({ pair in
            // If we've parsed the last section we're interested in, skip through the rest
            guard currentSection <= parseUpToSection || currentSection == .end else { return }
            
            let (index, child) = pair
            let isLastChild = index == (markup.childCount - 1)
            
            // Already parsed all expected content, return.
            guard currentSection != .end else { return }
            
            // Parse an H1 title, if found.
            if currentSection == .title {
                currentSection = .abstract
                
                // Index the title child node.
                if let heading = child as? Heading, heading.level == 1 {
                    titleHeading = heading
                    return
                }
            }
            
            // Parse an abstract, if found
            if currentSection == .abstract {
                if abstractSection == nil, let firstParagraph = child as? Paragraph {
                    abstractSection = AbstractSection(paragraph: firstParagraph)
                    return
                } else if let directive = child as? BlockDirective {
                    if directive.name == DeprecationSummary.directiveName {
                        // Found deprecation notice in the abstract.
                        deprecation = MarkupContainer(directive.children)
                        return
                    } else if directive.name == Comment.directiveName || directive.name == Metadata.directiveName || directive.name == Options.directiveName {
                        // These directives don't affect content so they shouldn't break us out of
                        // the automatic abstract section.
                        return
                    } else {
                        currentSection = .discussion
                    }
                } else if let _ = child as? HTMLBlock {
                    // Skip HTMLBlock comment.
                    return
                } else {
                    // Only directives and a single paragraph allowed in an abstract,
                    // advance to a discussion section.
                    currentSection = .discussion
                }
            }
            
            // Parse content into a discussion section and assorted tags
            let parseDiscussion: ([Markup])-> (discussion: DiscussionSection, tags: TaggedListItemExtractor) = { children in
                // Extract tags
                var extractor = TaggedListItemExtractor()
                let content: [Markup]
                
                if let remainder = extractor.visit(markup.withUncheckedChildren(children)) {
                    content = Array(remainder.children)
                } else {
                    content = []
                }
                
                return (discussion: DiscussionSection(content: content), tags: extractor)
            }
            
            // Parse a discussion, if found
            if currentSection == .discussion {
                // Scanning for the first discussion content child
                if discussionIndex == nil {
                    // Level 2 heading found at start of discussion
                    if let heading = child as? Heading, heading.level == 2 {
                        switch heading.plainText {
                        case TopicsSection.title:
                            currentSection = .topics
                            return
                        case SeeAlsoSection.title:
                            currentSection = .seeAlso
                            return
                        default: break
                        }
                    }
                    
                    // Discussion content starts at this index
                    discussionIndex = index
                }
                
                guard let discussionIndex = discussionIndex else { return }
                
                // Level 2 heading found inside discussion
                if let heading = child as? Heading, heading.level == 2 {
                    switch heading.plainText {
                    case TopicsSection.title:
                        let (discussion, tags) = parseDiscussion(markup.children(at: discussionIndex ..< index))
                        discussionSection = discussion
                        discussionTags = tags
                        currentSection = .topics
                        return
                        
                    case SeeAlsoSection.title:
                        let (discussion, tags) = parseDiscussion(markup.children(at: discussionIndex ..< index))
                        discussionSection = discussion
                        discussionTags = tags
                        currentSection = .seeAlso
                        return
                    default: break
                    }
                }
                
                // If at end of content, parse discussion
                if isLastChild {
                    let (discussion, tags) = parseDiscussion(markup.children(at: discussionIndex ... index))
                    discussionSection = discussion
                    discussionTags = tags
                }
            }
            
            if currentSection == .topics {
                if let heading = child as? Heading {
                    // Level 2 heading found inside Topics
                    if heading.level == 2 {
                        switch heading.plainText {
                        case SeeAlsoSection.title:
                            if let topicsIndex = topicsIndex, topicsFirstTaskGroupIndex != nil {
                                topicsSection = TopicsSection(content: markup.children(at: topicsIndex ..< index))
                            }
                            currentSection = .seeAlso
                            return
                        default: break
                        }
                    }
                    if heading.level == 3 {
                        topicsFirstTaskGroupIndex = index
                    }
                }
                
                if topicsIndex == nil { topicsIndex = index }
                
                // If at end of content, parse topics
                if isLastChild && topicsFirstTaskGroupIndex != nil {
                    topicsSection = TopicsSection(content: markup.children(at: topicsIndex! ... index))
                }
            }

            if currentSection == .seeAlso {
                // Level 2 heading found inside See Also
                if child is Heading {
                    if let seeAlsoIndex = seeAlsoIndex {
                        seeAlsoSection = SeeAlsoSection(content: markup.children(at: seeAlsoIndex ..< index))
                    }
                    currentSection = .end
                    return
                }
                
                if seeAlsoIndex == nil { seeAlsoIndex = index }
                
                // If at end of content, parse topics
                if isLastChild {
                    seeAlsoSection = SeeAlsoSection(content: markup.children(at: seeAlsoIndex! ... index))
                }
            }
        })
    }
}

// MARK: - Convenience Markup extensions

extension Markup {
    /// Returns a sub-sequence of the children sequence.
    /// - Parameter range: A closed range.
    /// - Returns: A children sub-sequence.
    func children(at range: ClosedRange<Int>) -> [Markup] {
        var iterator = children.makeIterator()
        var counter = 0
        var result = [Markup]()
        
        while let next = iterator.next() {
            defer { counter += 1 }
            guard counter <= range.upperBound else { break }
            guard counter >= range.lowerBound else { continue }
            result.append(next)
        }
        return result
    }

    /// Returns a sub-sequence of the children sequence.
    /// - Parameter range: A half-closed range.
    /// - Returns: A children sub-sequence.
    func children(at range: Range<Int>) -> [Markup] {
        var iterator = children.makeIterator()
        var counter = 0
        var result = [Markup]()
        
        while let next = iterator.next() {
            defer { counter += 1 }
            guard counter < range.upperBound else { break }
            guard counter >= range.lowerBound else { continue }
            result.append(next)
        }
        return result
    }
}
