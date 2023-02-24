/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import Markdown

extension XCTestCase {
    
    /// Asserts that a rendered node's content matches expectations.
    func assertExpectedContent(
        _ renderNode: RenderNode,
        sourceLanguage expectedSourceLanguage: String,
        symbolKind expectedSymbolKind: String? = nil,
        title expectedTitle: String,
        navigatorTitle expectedNavigatorTitle: String?,
        abstract expectedAbstract: String,
        declarationTokens expectedDeclarationTokens: [String]?,
        discussionSection expectedDiscussionSection: [String]?,
        topicSectionIdentifiers expectedTopicSectionIdentifiers: [String],
        seeAlsoSectionIdentifiers expectedSeeAlsoSectionIdentifiers: [String]? = nil,
        referenceTitles expectedReferenceTitles: [String],
        referenceFragments expectedReferenceFragments: [String],
        failureMessage failureMessageForField: (_ field: String) -> String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            renderNode.abstract?.plainText,
            expectedAbstract,
            failureMessageForField("abstract"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            (renderNode.primaryContentSections.last as? ContentRenderSection)?.content.paragraphText,
            expectedDiscussionSection,
            failureMessageForField("discussion section"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            renderNode.identifier.sourceLanguage.id,
            expectedSourceLanguage,
            failureMessageForField("source language id"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            (renderNode.primaryContentSections.first as? DeclarationsRenderSection)?
                .declarations
                .flatMap(\.tokens)
                .map(\.text),
            expectedDeclarationTokens,
            failureMessageForField("declaration tokens"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            renderNode.metadata.navigatorTitle?.map(\.text).joined(),
            expectedNavigatorTitle,
            failureMessageForField("navigator title"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            renderNode.metadata.title,
            expectedTitle,
            failureMessageForField("title"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            renderNode.metadata.symbolKind,
            expectedSymbolKind,
            failureMessageForField("symbol kind"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            renderNode.topicSections.flatMap(\.identifiers),
            expectedTopicSectionIdentifiers,
            failureMessageForField("topic sections identifiers"),
            file: file,
            line: line
        )
        
        if let expectedSeeAlsoSectionIdentifiers = expectedSeeAlsoSectionIdentifiers {
            XCTAssertEqual(
                renderNode.seeAlsoSections.flatMap(\.identifiers),
                expectedSeeAlsoSectionIdentifiers,
                failureMessageForField("see also sections identifiers"),
                file: file,
                line: line
            )
        }
        
        XCTAssertEqual(
            renderNode.references.map(\.value).compactMap { reference in
                (reference as? TopicRenderReference)?.title
            }.sorted(),
            expectedReferenceTitles,
            failureMessageForField("reference titles"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            renderNode.references.map(\.value).compactMap { reference in
                (reference as? TopicRenderReference)?.fragments?.map(\.text).joined()
            }.sorted(),
            expectedReferenceFragments,
            failureMessageForField("reference fragments"),
            file: file,
            line: line
        )
    }
}
