/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import DocCCommon
import Markdown
import Testing

struct TermListItemTests {
    @Test(arguments: [
        ("- term Foo: Bar.", "Foo", "Bar."),
        ("- term **Foo** `a:b`: Bar *baz*.", "**Foo** `a:b`", "Bar *baz*."),
        ("- term [Foo: Bar](https://example.com) baz: Qux.", "[Foo: Bar](https://example.com) baz", "Qux."),
    ])
    func splitsAtFirstColonInText(markdown: String, expectedTerm: String, expectedDefinition: String) throws {
        let termListItem = try #require(TermListItem(firstListItem(in: markdown)))
        #expect(Paragraph(termListItem.term).format() == expectedTerm)
        #expect(Document(termListItem.definition).format() == expectedDefinition)
    }
    
    @Test(arguments: [
        "- **term** Foo: Bar.",
        "- [term](https://example.com) Foo: Bar.",
        "- <span>term</span> Foo: Bar.",
        "- term<!-- comment --> Foo: Bar.",
    ])
    func doesNotDefineTermUnlessTextStartsWithKeywordAndSpace(markdown: String) throws {
        #expect(TermListItem(try firstListItem(in: markdown)) == nil)
    }
    
    private func firstListItem(in markdown: String) throws -> ListItem {
        let list = try #require(Document(parsing: markdown).child(at: 0) as? UnorderedList)
        return try #require(list.child(at: 0) as? ListItem)
    }
}
