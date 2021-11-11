/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/**
 A markup checker.
 
 A Checker is a `MarkupWalker` that collects a list of `Problem`s along the way.
 */
public protocol Checker: MarkupWalker {
    /// Problems found while walking.
    var problems: [Problem] { get }
}

/**
 An internal base class box for checkers.
 
 This is used to type-erase a `Checker`, which have an associated type constraint, so they cannot be stored verbatim.
 */
fileprivate class AnyCheckerBox: Checker {
    var problems: [Problem] {
        fatalError()
    }
    public func visitBlockQuote(_ blockQuote: BlockQuote) {
        fatalError()
    }
    public func visitCodeBlock(_ codeBlock: CodeBlock) {
        fatalError()
    }
    public func visitCustomBlock(_ customBlock: CustomBlock) {
        fatalError()
    }
    public func visitDocument(_ document: Document) {
        fatalError()
    }
    public func visitHeading(_ heading: Heading) {
        fatalError()
    }
    public func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        fatalError()
    }
    public func visitHTMLBlock(_ html: HTMLBlock) {
        fatalError()
    }
    public func visitListItem(_ listItem: ListItem) {
        fatalError()
    }
    public func visitOrderedList(_ orderedList: OrderedList) {
        fatalError()
    }
    public func visitUnorderedList(_ unorderedList: UnorderedList) {
        fatalError()
    }
    public func visitParagraph(_ paragraph: Paragraph) {
        fatalError()
    }
    public func visitInlineCode(_ inlineCode: InlineCode) {
        fatalError()
    }
    public func visitCustomInline(_ customInline: CustomInline) {
        fatalError()
    }
    public func visitEmphasis(_ emphasis: Emphasis) {
        fatalError()
    }
    public func visitImage(_ image: Image) {
        fatalError()
    }
    public func visitInlineHTML(_ inlineHTML: InlineHTML) {
        fatalError()
    }
    public func visitLineBreak(_ lineBreak: LineBreak) {
        fatalError()
    }
    public func visitLink(_ link: Link) {
        fatalError()
    }
    public func visitSoftBreak(_ softBreak: SoftBreak) {
        fatalError()
    }
    public func visitStrong(_ strong: Strong) {
        fatalError()
    }
    public func visitText(_ text: Text) {
        fatalError()
    }
}

/**
 An internal box for checkers.
 
 This is the leaf box which dispatches `MarkupWalker` methods to the wrapped checker.
 */
fileprivate class CheckerBox<Base: Checker>: AnyCheckerBox {
    private var base: Base
    init(_ base: Base) {
        self.base = base
    }
    
    override var problems: [Problem] {
        return base.problems
    }
    
    public override func visitBlockQuote(_ blockQuote: BlockQuote) {
        base.visitBlockQuote(blockQuote)
    }
    public override func visitCodeBlock(_ codeBlock: CodeBlock) {
        base.visitCodeBlock(codeBlock)
    }
    public override func visitCustomBlock(_ customBlock: CustomBlock) {
        base.visitCustomBlock(customBlock)
    }
    public override func visitDocument(_ document: Document) {
        base.visitDocument(document)
    }
    public override func visitHeading(_ heading: Heading) {
        base.visitHeading(heading)
    }
    public override func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        base.visitThematicBreak(thematicBreak)
    }
    public override func visitHTMLBlock(_ html: HTMLBlock) {
        base.visitHTMLBlock(html)
    }
    public override func visitListItem(_ listItem: ListItem) {
        base.visitListItem(listItem)
    }
    public override func visitOrderedList(_ orderedList: OrderedList) {
        base.visitOrderedList(orderedList)
    }
    public override func visitUnorderedList(_ unorderedList: UnorderedList) {
        base.visitUnorderedList(unorderedList)
    }
    public override func visitParagraph(_ paragraph: Paragraph) {
        base.visitParagraph(paragraph)
    }
    public override func visitInlineCode(_ inlineCode: InlineCode) {
        base.visitInlineCode(inlineCode)
    }
    public override func visitCustomInline(_ customInline: CustomInline) {
        base.visitCustomInline(customInline)
    }
    public override func visitEmphasis(_ emphasis: Emphasis) {
        base.visitEmphasis(emphasis)
    }
    public override func visitImage(_ image: Image) {
        base.visitImage(image)
    }
    public override func visitInlineHTML(_ inlineHTML: InlineHTML) {
        base.visitInlineHTML(inlineHTML)
    }
    public override func visitLineBreak(_ lineBreak: LineBreak) {
        base.visitLineBreak(lineBreak)
    }
    public override func visitLink(_ link: Link) {
        base.visitLink(link)
    }
    public override func visitSoftBreak(_ softBreak: SoftBreak) {
        base.visitSoftBreak(softBreak)
    }
    public override func visitStrong(_ strong: Strong) {
        base.visitStrong(strong)
    }
    public override func visitText(_ text: Text) {
        base.visitText(text)
    }
}

/**
 A type-erased container for any `Checker`.
 */
public struct AnyChecker: Checker {
    private var box: AnyCheckerBox
    
    /// Creates an instance that type erases the given checker.
    public init<C: Checker>(_ checker: C) {
        self.box = CheckerBox(checker)
    }
    
    public var problems: [Problem] {
        return box.problems
    }
    
    public mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        box.visitBlockQuote(blockQuote)
    }
    public mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        box.visitCodeBlock(codeBlock)
    }
    public mutating func visitCustomBlock(_ customBlock: CustomBlock) {
        box.visitCustomBlock(customBlock)
    }
    public mutating func visitDocument(_ document: Document) {
        box.visitDocument(document)
    }
    public mutating func visitHeading(_ heading: Heading) {
        box.visitHeading(heading)
    }
    public mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        box.visitThematicBreak(thematicBreak)
    }
    public mutating func visitHTMLBlock(_ html: HTMLBlock) {
        box.visitHTMLBlock(html)
    }
    public mutating func visitListItem(_ listItem: ListItem) {
        box.visitListItem(listItem)
    }
    public mutating func visitOrderedList(_ orderedList: OrderedList) {
        box.visitOrderedList(orderedList)
    }
    public mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        box.visitUnorderedList(unorderedList)
    }
    public mutating func visitParagraph(_ paragraph: Paragraph) {
        box.visitParagraph(paragraph)
    }
    public mutating func visitInlineCode(_ inlineCode: InlineCode) {
        box.visitInlineCode(inlineCode)
    }
    public mutating func visitCustomInline(_ customInline: CustomInline) {
        box.visitCustomInline(customInline)
    }
    public mutating func visitEmphasis(_ emphasis: Emphasis) {
        box.visitEmphasis(emphasis)
    }
    public mutating func visitImage(_ image: Image) {
        box.visitImage(image)
    }
    public mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        box.visitInlineHTML(inlineHTML)
    }
    public mutating func visitLineBreak(_ lineBreak: LineBreak) {
        box.visitLineBreak(lineBreak)
    }
    public mutating func visitLink(_ link: Link) {
        box.visitLink(link)
    }
    public mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        box.visitSoftBreak(softBreak)
    }
    public mutating func visitStrong(_ strong: Strong) {
        box.visitStrong(strong)
    }
    public mutating func visitText(_ text: Text) {
        box.visitText(text)
    }
}

extension Checker {
    /// Returns this checker wrapped in an `AnyChecker`.
    public func any() -> AnyChecker {
        return AnyChecker(self)
    }
}

/**
 A collection of checkers which all visit the same `Markup` tree.
 */
public struct CompositeChecker: Checker {
    
    /// The checkers that will visit the markup tree.
    public var checkers: [AnyChecker]

    /// Creates a checker that performs the combined work of the given checkers.
    public init<Checkers: Sequence>(_ checkers: Checkers) where Checkers.Element: Checker {
        self.checkers = checkers.map { $0.any() }
    }
    
    public var problems: [Problem] {
        return checkers.flatMap { checker -> [Problem] in
            return checker.problems
        }
    }
    
    public mutating func visit(_ markup: Markup) -> () {
        for i in checkers.indices {
            checkers[i].visit(markup)
        }
    }
    
    public mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        for i in checkers.indices {
            checkers[i].visitBlockQuote(blockQuote)
        }
        descendInto(blockQuote)
    }
    public mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        for i in checkers.indices {
            checkers[i].visitCodeBlock(codeBlock)
        }
        descendInto(codeBlock)
    }
    public mutating func visitCustomBlock(_ customBlock: CustomBlock) {
        for i in checkers.indices {
            checkers[i].visitCustomBlock(customBlock)
        }
        descendInto(customBlock)
    }
    public mutating func visitDocument(_ document: Document) {
        for i in checkers.indices {
            checkers[i].visitDocument(document)
        }
        descendInto(document)
    }
    public mutating func visitHeading(_ heading: Heading) {
        for i in checkers.indices {
            checkers[i].visitHeading(heading)
        }
        descendInto(heading)
    }
    public mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        for i in checkers.indices {
            checkers[i].visitThematicBreak(thematicBreak)
        }
        descendInto(thematicBreak)
    }
    public mutating func visitHTMLBlock(_ html: HTMLBlock) {
        for i in checkers.indices {
            checkers[i].visitHTMLBlock(html)
        }
        descendInto(html)
    }
    public mutating func visitListItem(_ listItem: ListItem) {
        for i in checkers.indices {
            checkers[i].visitListItem(listItem)
        }
        descendInto(listItem)
    }
    public mutating func visitOrderedList(_ orderedList: OrderedList) {
        for i in checkers.indices {
            checkers[i].visitOrderedList(orderedList)
        }
        descendInto(orderedList)
    }
    public mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        for i in checkers.indices {
            checkers[i].visitUnorderedList(unorderedList)
        }
        descendInto(unorderedList)
    }
    public mutating func visitParagraph(_ paragraph: Paragraph) {
        for i in checkers.indices {
            checkers[i].visitParagraph(paragraph)
        }
        descendInto(paragraph)
    }
    public mutating func visitInlineCode(_ inlineCode: InlineCode) {
        for i in checkers.indices {
            checkers[i].visitInlineCode(inlineCode)
        }
        descendInto(inlineCode)
    }
    public mutating func visitCustomInline(_ customInline: CustomInline) {
        for i in checkers.indices {
            checkers[i].visitCustomInline(customInline)
        }
        descendInto(customInline)
    }
    public mutating func visitEmphasis(_ emphasis: Emphasis) {
        for i in checkers.indices {
            checkers[i].visitEmphasis(emphasis)
        }
        descendInto(emphasis)
    }
    public mutating func visitImage(_ image: Image) {
        for i in checkers.indices {
            checkers[i].visitImage(image)
        }
        descendInto(image)
    }
    public mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        for i in checkers.indices {
            checkers[i].visitInlineHTML(inlineHTML)
        }
        descendInto(inlineHTML)
    }
    public mutating func visitLineBreak(_ lineBreak: LineBreak) {
        for i in checkers.indices {
            checkers[i].visitLineBreak(lineBreak)
        }
        descendInto(lineBreak)
    }
    public mutating func visitLink(_ link: Link) {
        for i in checkers.indices {
            checkers[i].visitLink(link)
        }
        descendInto(link)
    }
    public mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        for i in checkers.indices {
            checkers[i].visitSoftBreak(softBreak)
        }
        descendInto(softBreak)
    }
    public mutating func visitStrong(_ strong: Strong) {
        for i in checkers.indices {
            checkers[i].visitStrong(strong)
        }
        descendInto(strong)
    }
    public mutating func visitText(_ text: Text) {
        for i in checkers.indices {
            checkers[i].visitText(text)
        }
        descendInto(text)
    }
}

/*
 A collection of `Heading` properties utilized by `Checker`s.
 */
extension Heading {
    var isTopicsSection: Bool {
        return level == 2 && title == "Topics"
    }
}
