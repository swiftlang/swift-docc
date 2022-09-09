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

class DefaultCodeBlockSyntaxTests: XCTestCase {
    enum Errors: Error {
        case noCodeBlockFound
    }
    
    var renderSectionWithLanguageDefault: ContentRenderSection!
    var renderSectionWithoutLanguageDefault: ContentRenderSection!

    var testBundleWithLanguageDefault: DocumentationBundle!
    var testBundleWithoutLanguageDefault: DocumentationBundle!

    override func setUpWithError() throws {
        func renderSection(for bundle: DocumentationBundle, in context: DocumentationContext) throws -> ContentRenderSection {
            let identifier = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/Test-Bundle/Default-Code-Listing-Syntax", fragment: nil, sourceLanguage: .swift)

            let source = context.documentURL(for: identifier)

            let node = try context.entity(with: identifier)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: source)
            let renderNode = translator.visit(node.semantic) as! RenderNode

            return renderNode.primaryContentSections.first! as! ContentRenderSection
        }

        let (_, bundleWithLanguageDefault, context) = try testBundleAndContext(copying: "TestBundle")

        testBundleWithLanguageDefault = bundleWithLanguageDefault

        // Copy the bundle but explicitly set `defaultCodeListingLanguage` to `nil` to mimic having no default language set.
        testBundleWithoutLanguageDefault = DocumentationBundle(
            info: DocumentationBundle.Info(
                displayName: testBundleWithLanguageDefault.displayName,
                identifier: testBundleWithLanguageDefault.identifier,
                version: testBundleWithLanguageDefault.version,
                defaultCodeListingLanguage: nil
            ),
            baseURL: testBundleWithLanguageDefault.baseURL,
            attributedCodeListings: testBundleWithLanguageDefault.attributedCodeListings,
            symbolGraphURLs: testBundleWithLanguageDefault.symbolGraphURLs,
            markupURLs: testBundleWithLanguageDefault.markupURLs,
            miscResourceURLs: testBundleWithLanguageDefault.miscResourceURLs
        )

        renderSectionWithLanguageDefault = try renderSection(for: testBundleWithLanguageDefault, in: context)
        renderSectionWithoutLanguageDefault = try renderSection(for: testBundleWithoutLanguageDefault, in: context)
    }

    struct CodeListing {
        var language: String?
        var lines: [String]
    }

    private func codeListing(at index: Int, in renderSection: ContentRenderSection, file: StaticString = #file, line: UInt = #line) throws -> CodeListing {
        if case let .codeListing(l) = renderSection.content[index] {
            return CodeListing(language: l.syntax, lines: l.code)
        }

        XCTFail("Expected code listing at index \(index)", file: (file), line: line)
        throw Errors.noCodeBlockFound
    }

    func testDefaultCodeBlockSyntaxForFencedCodeListingWithoutExplicitLanguage() throws {
        let fencedCodeListing = try codeListing(at: 1, in: renderSectionWithLanguageDefault)

        XCTAssertEqual("swift", fencedCodeListing.language, "Default a language of 'CDDefaultCodeListingLanguage' if  it is set in the 'Info.plist'")

        XCTAssertEqual(fencedCodeListing.lines, [
            "// With no language set, this should highlight to 'swift' because the 'CDDefaultCodeListingLanguage' key is set to 'swift'.",
            "func foo()",
        ])
    }

    func testDefaultCodeBlockSyntaxForNonFencedCodeListing() throws {
        let indentedCodeListing = try codeListing(at: 2, in: renderSectionWithLanguageDefault)

        XCTAssertEqual("swift", indentedCodeListing.language, "Default a language of 'CDDefaultCodeListingLanguage' if  it is set in the 'Info.plist'")
        XCTAssertEqual(indentedCodeListing.lines, [
            "/// This is a non fenced code listing and should also default to the 'CDDefaultCodeListingLanguage' language.",
            "func foo()",
        ])
    }

    func testExplicitlySetLanguageOverridesBundleDefault() throws {
        let explicitlySetLanguageCodeListing = try codeListing(at: 3, in: renderSectionWithLanguageDefault)

        XCTAssertEqual("objective-c", explicitlySetLanguageCodeListing.language, "The explicit language of the code listing should override the bundle's default language")

        XCTAssertEqual(explicitlySetLanguageCodeListing.lines, [
            "/// This is a fenced code block with an explicit language set, and it should override the default language for the bundle.",
            "- (void)foo;",
        ])
    }

    func testHasNoLanguageWhenNoPlistKeySetAndNoExplicitLanguageProvided() throws {
        let fencedCodeListing = try codeListing(at: 1, in: renderSectionWithoutLanguageDefault)
        let indentedCodeListing = try codeListing(at: 2, in: renderSectionWithoutLanguageDefault)
        let explicitlySetLanguageCodeListing = try codeListing(at: 3, in: renderSectionWithoutLanguageDefault)

        XCTAssertEqual(fencedCodeListing.language, nil)
        XCTAssertEqual(indentedCodeListing.language, nil)
        XCTAssertEqual(explicitlySetLanguageCodeListing.language, "objective-c")
    }
}
