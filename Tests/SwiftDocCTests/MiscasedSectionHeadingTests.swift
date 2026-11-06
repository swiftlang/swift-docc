/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import SwiftDocC
import Markdown

struct MiscasedSectionHeadingTests {
    @Test(arguments: [
        "Topics", "TOPICS", "topics", "ToPiCs"
    ])
    func identifiesTopicsSection(headingTitle: String) {
        let document = Document(parsing: """
        ## \(headingTitle)
        - ``SomeUnresolvedLink``
        """, options: .parseSymbolLinks)
        let structuredMarkup = DocumentationMarkup(markup: document.root)
        
        #expect(structuredMarkup.abstractSection   == nil)
        #expect(structuredMarkup.discussionSection == nil)
        #expect(structuredMarkup.seeAlsoSection    == nil)
        
        #expect(structuredMarkup.topicsSection != nil)
    }
    
    @Test(arguments: [
        "See Also", "SEE ALSO", "see also", "SeE aLsO"
    ])
    func identifiesSeeAlsoSection(headingTitle: String) {
        let document = Document(parsing: """
        ## \(headingTitle)
        - ``SomeUnresolvedLink``
        """, options: .parseSymbolLinks)
        let structuredMarkup = DocumentationMarkup(markup: document.root)
        
        #expect(structuredMarkup.abstractSection   == nil)
        #expect(structuredMarkup.discussionSection == nil)
        #expect(structuredMarkup.topicsSection     == nil)
        
        #expect(structuredMarkup.seeAlsoSection != nil)
    }
    
    @Test(arguments: [
        "Overview",   "OVERVIEW",   "overview",   "OvErViEw",
        "Discussion", "DISCUSSION", "discussion", "DiScUsSiOn",
    ])
    func identifiesDiscussionSection(headingTitle: String) {
        let document = Document(parsing: """
        ## \(headingTitle)
        - ``SomeUnresolvedLink``
        """, options: .parseSymbolLinks)
        let structuredMarkup = DocumentationMarkup(markup: document.root)
        
        #expect(structuredMarkup.abstractSection == nil)
        #expect(structuredMarkup.topicsSection   == nil)
        #expect(structuredMarkup.seeAlsoSection  == nil)
        
        #expect(structuredMarkup.discussionSection != nil)
    }
}
