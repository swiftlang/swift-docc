/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SymbolKit
@testable import SwiftDocC
import Markdown
import SwiftDocCTestUtilities

class SymbolTests: XCTestCase {
    
    func testDocCommentWithoutArticle() throws {
        let (withoutArticle, problems) = try makeDocumentationNodeSymbol(
            docComment: """
                A cool API to call.

                - Parameters:
                  - name: A parameter
                - Returns: Return value
                """,
            articleContent: nil
        )
        
        XCTAssert(problems.isEmpty)
        
        XCTAssertEqual(withoutArticle.abstract?.format(), "A cool API to call.")
        XCTAssertEqual((withoutArticle.discussion?.content ?? []).map { $0.format() }.joined(), "")
        if let parameter = withoutArticle.parametersSection?.parameters.first, withoutArticle.parametersSection?.parameters.count == 1 {
            XCTAssertEqual(parameter.name, "name")
            XCTAssertEqual(parameter.contents.map { $0.format() }, ["A parameter"])
        } else {
            XCTFail("Unexpected parameters for `myFunction` in-source documentation.")
        }
        XCTAssertEqual((withoutArticle.returnsSection?.content ?? []).map { $0.format() }, ["Return value"])
        
        XCTAssertNil(withoutArticle.topics)
    }
    
    func testOverridingInSourceDocumentationWithEmptyArticle() throws {
        // The article heading—which should always be the symbol link header—is not considered part of the article's content
        let (withArticleOverride, problems) = try makeDocumentationNodeSymbol(
            docComment: """
                A cool API to call.

                - Parameters:
                  - name: A parameter
                - Returns: Return value
                """,
            articleContent: """
                # Leading heading is ignored
                
                @Metadata {
                   @DocumentationExtension(mergeBehavior: override)
                }
                """
        )
        XCTAssert(problems.isEmpty)
        
        XCTAssertNil(withArticleOverride.abstract,
                       "The article overrides—and removes—the abstract from the in-source documenation")
        XCTAssertNil(withArticleOverride.discussion,
                       "The article overries the discussion.")
        XCTAssertNil(withArticleOverride.parametersSection?.parameters,
                     "The article overrides—and removes—the parameter section from the in-source documentation.")
        XCTAssertEqual((withArticleOverride.returnsSection?.content ?? []).map { $0.format() }.joined(), "",
                       "The article overrides—and removes—the return section from the in-source documentation.")
        XCTAssertNil(withArticleOverride.topics,
                     "The article did override the topics section.")
    }
    
     func testOverridingInSourceDocumentationWithDetailedArticle() throws {
        let (withArticleOverride, problems) = try makeDocumentationNodeSymbol(
            docComment: """
                A cool API to call.

                - Parameters:
                  - name: A parameter
                - Returns: Return value
                """,
            articleContent: """
                # This is my article

                @Metadata {
                   @DocumentationExtension(mergeBehavior: override)
                }

                This is an abstract.

                This is a multi-paragraph overview.

                It continues here.

                - Parameters:
                  - name: Name parameter is explained here.

                - Returns: Return value is explained here.

                ## Topics

                ### Name of a topic

                - ``MyKit``
                - ``MyKit/MyClass``

                """
        )
        XCTAssert(problems.isEmpty)
        
        XCTAssertEqual(withArticleOverride.abstract?.plainText, "This is an abstract.",
                       "The article overrides the abstract from the in-source documenation")
        XCTAssertEqual((withArticleOverride.discussion?.content ?? []).filter({ markup -> Bool in
            return !(markup.isEmpty) && !(markup is BlockDirective)
        }).map { $0.format().trimmingLines() }, ["This is a multi-paragraph overview.", "It continues here."],
                       "The article overrides—and adds—a discussion.")
        
        if let parameter = withArticleOverride.parametersSection?.parameters.first, withArticleOverride.parametersSection?.parameters.count == 1 {
            XCTAssertEqual(parameter.name, "name")
            XCTAssertEqual(parameter.contents.map { $0.format() }, ["Name parameter is explained here."])
        } else {
            XCTFail("Unexpected parameters for `myFunction` in documentation from article override.")
        }
        
        XCTAssertEqual((withArticleOverride.returnsSection?.content ?? []).map { $0.format() }, ["Return value is explained here."],
                       "The article overries—and removes—the return section from the in-source documentation.")
        
        if let topicContent = withArticleOverride.topics?.content, let heading = topicContent.first as? Heading, let topics = topicContent.last as? UnorderedList {
            XCTAssertEqual(heading.plainText, "Name of a topic")
            XCTAssertEqual(topics.childCount, 2)
        } else {
            XCTFail("Unexpected topics for `myFunction` in documentation from article override.")
        }
    }
    
    func testAppendingInSourceDocumentationWithArticle() throws {
        // The article heading—which should always be the symbol link header—is not considered part of the article's content
        let (withEmptyArticleOverride, problems) = try makeDocumentationNodeSymbol(
            docComment: """
                A cool API to call.

                - Parameters:
                  - name: A parameter
                - Returns: Return value
                """,
            articleContent: """
                # Leading heading is ignored
                """
        )
        XCTAssert(problems.isEmpty)
        
        XCTAssertEqual(withEmptyArticleOverride.abstract?.format(), "A cool API to call.")
        XCTAssertEqual((withEmptyArticleOverride.discussion?.content.filter({ markup -> Bool in
            return !(markup.isEmpty) && !(markup is BlockDirective)
        }) ?? []).map { $0.format() }.joined(), "")
        if let parameter = withEmptyArticleOverride.parametersSection?.parameters.first, withEmptyArticleOverride.parametersSection?.parameters.count == 1 {
            XCTAssertEqual(parameter.name, "name")
            XCTAssertEqual(parameter.contents.map { $0.format() }, ["A parameter"])
        } else {
            XCTFail("Unexpected parameters for `myFunction` in-source documentation.")
        }
        XCTAssertEqual((withEmptyArticleOverride.returnsSection?.content ?? []).map { $0.format() }, ["Return value"])
        
        XCTAssertNil(withEmptyArticleOverride.topics)
    }
        
    func testAppendingArticleToInSourceDocumentation() throws {
        // When no DocumentationExtension behavior is specified, the default behavior is "append to doc comment".
        let withAndWithoutAppendConfiguration = ["", "@Metadata { \n @DocumentationExtension(mergeBehavior: append) \n }"]
        
        // Append curation to doc comment
        for metadata in withAndWithoutAppendConfiguration {
            let (withArticleOverride, problems) = try makeDocumentationNodeSymbol(
                docComment: """
                    A cool API to call.

                    - Parameters:
                      - name: A parameter
                    - Returns: Return value
                    """,
                articleContent: """
                    # This is my article

                    \(metadata)

                    ## Topics

                    ### Name of a topic

                    - ``MyKit``
                    - ``MyKit/MyClass``

                    """
            )
            XCTAssert(problems.isEmpty)
            
            XCTAssertEqual(withArticleOverride.abstract?.format(), "A cool API to call.")
            XCTAssertEqual((withArticleOverride.discussion?.content.filter({ markup -> Bool in
                return !(markup.isEmpty) && !(markup is BlockDirective)
            }) ?? []).map { $0.format() }.joined(), "")
            if let parameter = withArticleOverride.parametersSection?.parameters.first, withArticleOverride.parametersSection?.parameters.count == 1 {
                XCTAssertEqual(parameter.name, "name")
                XCTAssertEqual(parameter.contents.map { $0.format() }, ["A parameter"])
            } else {
                XCTFail("Unexpected parameters for `myFunction` in-source documentation.")
            }
            XCTAssertEqual((withArticleOverride.returnsSection?.content ?? []).map { $0.format() }, ["Return value"])

            if let topicContent = withArticleOverride.topics?.content, let heading = topicContent.first as? Heading, let topics = topicContent.last as? UnorderedList {
                XCTAssertEqual(heading.title, "Name of a topic")
                XCTAssertEqual(topics.childCount, 2)
            } else {
                XCTFail("Unexpected topics for `myFunction` in documentation from article override.")
            }
        }

        // Append overview and curation to doc comment
        for metadata in withAndWithoutAppendConfiguration {
            let (withArticleOverride, problems) = try makeDocumentationNodeSymbol(
                docComment: """
                    A cool API to call.

                    - Parameters:
                      - name: A parameter
                    - Returns: Return value
                    """,
                articleContent: """
                    # This is my article

                    \(metadata)

                    This is a multi-paragraph overview.

                    It continues here.

                    ## Topics

                    ### Name of a topic

                    - ``MyKit``
                    - ``MyKit/MyClass``

                    """
            )
            XCTAssert(problems.isEmpty)
            
            XCTAssertEqual(withArticleOverride.abstract?.format(), "A cool API to call.")

            XCTAssertEqual((withArticleOverride.discussion?.content.filter({ markup -> Bool in
                return !(markup.isEmpty) && !(markup is BlockDirective)
            }) ?? []).map { $0.format().trimmingLines() }, ["This is a multi-paragraph overview.", "It continues here."],
                           "The article overries—and adds—a discussion.")

            if let parameter = withArticleOverride.parametersSection?.parameters.first, withArticleOverride.parametersSection?.parameters.count == 1 {
                XCTAssertEqual(parameter.name, "name")
                XCTAssertEqual(parameter.contents.map { $0.format() }, ["A parameter"])
            } else {
                XCTFail("Unexpected parameters for `myFunction` in-source documentation.")
            }
            XCTAssertEqual((withArticleOverride.returnsSection?.content ?? []).map { $0.format() }, ["Return value"])

            if let topicContent = withArticleOverride.topics?.content, let heading = topicContent.first as? Heading, let topics = topicContent.last as? UnorderedList {
                XCTAssertEqual(heading.title, "Name of a topic")
                XCTAssertEqual(topics.childCount, 2)
            } else {
                XCTFail("Unexpected topics for `myFunction` in documentation from article override.")
            }
        }

        // Append overview and curation to doc comment
        for metadata in withAndWithoutAppendConfiguration {
            let (withArticleOverride, problems) = try makeDocumentationNodeSymbol(
                docComment: """
                    A cool API to call.

                    - Parameters:
                      - name: A parameter
                    - Returns: Return value
                    """,
                articleContent: """
                    # This is my article

                    \(metadata)

                    This is a multi-paragraph overview.

                    It continues here.

                    ## Topics

                    ### Name of a topic

                    - ``MyKit``
                    - ``MyKit/MyClass``

                    """
            )
            XCTAssert(problems.isEmpty)
            
            XCTAssertEqual(withArticleOverride.abstract?.format(), "A cool API to call.")

            XCTAssertEqual((withArticleOverride.discussion?.content.filter({ markup -> Bool in
                return !(markup.isEmpty) && !(markup is BlockDirective)
            }) ?? []).map { $0.format().trimmingLines() }, ["This is a multi-paragraph overview.", "It continues here."],
                           "The article overries—and adds—a discussion.")

            if let parameter = withArticleOverride.parametersSection?.parameters.first, withArticleOverride.parametersSection?.parameters.count == 1 {
                XCTAssertEqual(parameter.name, "name")
                XCTAssertEqual(parameter.contents.map { $0.format() }, ["A parameter"])
            } else {
                XCTFail("Unexpected parameters for `myFunction` in-source documentation.")
            }
            XCTAssertEqual((withArticleOverride.returnsSection?.content ?? []).map { $0.format() }, ["Return value"])

            if let topicContent = withArticleOverride.topics?.content, let heading = topicContent.first as? Heading, let topics = topicContent.last as? UnorderedList {
                XCTAssertEqual(heading.title, "Name of a topic")
                XCTAssertEqual(topics.childCount, 2)
            } else {
                XCTFail("Unexpected topics for `myFunction` in documentation from article override.")
            }
        }

        // Append with only abstract in doc comment
        for metadata in withAndWithoutAppendConfiguration {
            let (withArticleOverride, problems) = try makeDocumentationNodeSymbol(
                docComment: """
                    A cool API to call.
                    """,
                articleContent: """
                    # This is my article

                    \(metadata)

                    This is a multi-paragraph overview.

                    It continues here.

                    - Parameters:
                      - name: A parameter

                    - Returns: Return value

                    ## Topics

                    ### Name of a topic

                    - ``MyKit``
                    - ``MyKit/MyClass``

                    """
            )
            XCTAssert(problems.isEmpty)
            
            XCTAssertEqual(withArticleOverride.abstract?.format(), "A cool API to call.")

            XCTAssertEqual((withArticleOverride.discussion?.content.filter({ markup -> Bool in
                return !(markup.isEmpty) && !(markup is BlockDirective)
            }) ?? []).map { $0.format().trimmingLines() }, ["This is a multi-paragraph overview.", "It continues here."],
                           "The article overries—and adds—a discussion.")

            if let parameter = withArticleOverride.parametersSection?.parameters.first, withArticleOverride.parametersSection?.parameters.count == 1 {
                XCTAssertEqual(parameter.name, "name")
                XCTAssertEqual(parameter.contents.map { $0.format() }, ["A parameter"])
            } else {
                XCTFail("Unexpected parameters for `myFunction` in-source documentation.")
            }
            XCTAssertEqual((withArticleOverride.returnsSection?.content ?? []).map { $0.format() }, ["Return value"])

            if let topicContent = withArticleOverride.topics?.content, let heading = topicContent.first as? Heading, let topics = topicContent.last as? UnorderedList {
                XCTAssertEqual(heading.title, "Name of a topic")
                XCTAssertEqual(topics.childCount, 2)
            } else {
                XCTFail("Unexpected topics for `myFunction` in documentation from article override.")
            }
        }

        // Append by extending overview and adding parameters
        for metadata in withAndWithoutAppendConfiguration {
            let (withArticleOverride, problems) = try makeDocumentationNodeSymbol(
                docComment: """
                    A cool API to call.

                    The overview stats in the doc comment.
                    """,
                articleContent: """
                    # This is my article

                    \(metadata)

                    And continues here in the article.

                    - Parameters:
                      - name: A parameter
                    - Returns: Return value
                    """
            )
            XCTAssert(problems.isEmpty)
            
            XCTAssertEqual(withArticleOverride.abstract?.format(), "A cool API to call.")

            XCTAssertEqual((withArticleOverride.discussion?.content.filter({ markup -> Bool in
                return !(markup.isEmpty) && !(markup is BlockDirective)
            }) ?? []).map { $0.format().trimmingLines() }, ["The overview stats in the doc comment.", "And continues here in the article."],
                           "The article overries—and adds—a discussion.")

            if let parameter = withArticleOverride.parametersSection?.parameters.first, withArticleOverride.parametersSection?.parameters.count == 1 {
                XCTAssertEqual(parameter.name, "name")
                XCTAssertEqual(parameter.contents.map { $0.format() }, ["A parameter"])
            } else {
                XCTFail("Unexpected parameters for `myFunction` in-source documentation.")
            }
            XCTAssertEqual((withArticleOverride.returnsSection?.content ?? []).map { $0.format() }, ["Return value"])

            XCTAssertNil(withArticleOverride.topics)
        }

        // Append by extending the overview (with parameters in the doc comment)
        for metadata in withAndWithoutAppendConfiguration {
            let (withArticleOverride, problems) = try makeDocumentationNodeSymbol(
                docComment: """
                    A cool API to call.

                    The overview starts in the doc comment.

                    - Parameters:
                      - name: A parameter
                    - Returns: Return value
                    """,
                articleContent: """
                    # This is my article

                    \(metadata)

                    This continues the overview from the doc comment.
                    """
            )
            XCTAssert(problems.isEmpty)
            
            XCTAssertEqual(withArticleOverride.abstract?.format(), "A cool API to call.")
            
            XCTAssertEqual((withArticleOverride.discussion?.content.filter({ markup -> Bool in
                return !(markup.isEmpty) && !(markup is BlockDirective)
            }) ?? []).map { $0.format().trimmingLines() }, ["The overview starts in the doc comment.", "This continues the overview from the doc comment."],
                           "The article overries—and adds—a discussion.")
            
            if let parameter = withArticleOverride.parametersSection?.parameters.first, withArticleOverride.parametersSection?.parameters.count == 1 {
                XCTAssertEqual(parameter.name, "name")
                XCTAssertEqual(parameter.contents.map { $0.format() }, ["A parameter"])
            } else {
                XCTFail("Unexpected parameters for `myFunction` in-source documentation.")
            }
            XCTAssertEqual((withArticleOverride.returnsSection?.content ?? []).map { $0.format() }, ["Return value"])
            
            XCTAssertNil(withArticleOverride.topics)
        }
    }
    
    func testRedirectFromArticle() throws {
        let (withRedirectInArticle, problems) = try makeDocumentationNodeSymbol(
            docComment: """
                A cool API to call.

                """,
            articleContent: """
                # This is my article

                @Redirected(from: "some/previous/path/to/this/symbol")
                """
        )
        XCTAssert(problems.isEmpty)
        
        XCTAssertEqual(withRedirectInArticle.redirects?.map { $0.oldPath.absoluteString }, ["some/previous/path/to/this/symbol"])
    }
    
    func testWarningWhenDocCommentContainsUnsupportedDirective() throws {
        let (withRedirectInArticle, problems) = try makeDocumentationNodeSymbol(
            docComment: """
                A cool API to call.

                @Redirected(from: "some/previous/path/to/this/symbol")
                """,
            articleContent: """
                # This is my article
                """
        )
        XCTAssertFalse(problems.isEmpty)
        XCTAssertEqual(withRedirectInArticle.redirects, nil)

        XCTAssertEqual(problems.first?.diagnostic.identifier, "org.swift.docc.UnsupportedDocCommentDirective")
        XCTAssertEqual(problems.first?.diagnostic.range?.lowerBound.line, 3)
        XCTAssertEqual(problems.first?.diagnostic.range?.lowerBound.column, 1)
    }

    func testNoWarningWhenDocCommentContainsDirective() throws {
        let (_, problems) = try makeDocumentationNodeSymbol(
            docComment: """
                A cool API to call.

                @Snippet(from: "Snippets/Snippets/MySnippet")
                """,
            articleContent: """
                # This is my article
                """
        )
        XCTAssertTrue(problems.isEmpty)
    }
    
    func testNoWarningWhenDocCommentContainsDoxygen() throws {
        let tempURL = try createTemporaryDirectory()
        
        let bundleURL = try Folder(name: "Inheritance.docc", content: [
            InfoPlist(displayName: "Inheritance", identifier: "com.test.inheritance"),
            CopyOfFile(original: Bundle.module.url(
                forResource: "Inheritance.symbols", withExtension: "json",
                subdirectory: "Test Resources")!),
        ]).write(inside: tempURL)
        
        let (_, _, context) = try loadBundle(from: bundleURL)
        let problems = context.diagnosticEngine.problems
        XCTAssertEqual(problems.count, 0)
    }

    func testParseDoxygen() throws {
        let deckKitSymbolGraph = Bundle.module.url(
            forResource: "DeckKit-Objective-C",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { url in
            try? FileManager.default.copyItem(at: deckKitSymbolGraph, to: url.appendingPathComponent("DeckKit.symbols.json"))
        }
        let symbol = try XCTUnwrap(context.documentationCache["c:objc(cs)PlayingCard(cm)newWithRank:ofSuit:"]?.semantic as? Symbol)

        XCTAssertEqual(symbol.abstract?.format(), "Allocate and initialize a new card with the given rank and suit.")

        XCTAssertEqual(symbol.parametersSection?.parameters.count, 2)

        let rankParameter = try XCTUnwrap(symbol.parametersSection?.parameters.first(where:{$0.name == "rank"}))
        XCTAssertEqual(rankParameter.contents.map({$0.format()}), ["The rank of the card."])
        let suitParameter = try XCTUnwrap(symbol.parametersSection?.parameters.first(where:{$0.name == "suit"}))
        XCTAssertEqual(suitParameter.contents.map({$0.format()}), ["The suit of the card."])

        XCTAssertEqual(symbol.returnsSection?.content.map({ $0.format() }), ["A new card with the given configuration."])
    }

    func testUnresolvedReferenceWarningsInDocumentationExtension() throws {
        let (url, _, context) = try testBundleAndContext(copying: "TestBundle") { url in
            let myKitDocumentationExtensionComment = """
            # ``MyKit/MyClass``

            @Metadata {
               @DocumentationExtension(mergeBehavior: override)
            }

            A cool API to call.

            This overview has an ``UnresolvableSymbolLinkInMyClassOverview<>(_:))``.

            - Parameters:
              - name: A parameter
            - Returns: Return value

            ## Topics

            ### Curation that won't resolve

            - ``UnresolvableClassInMyClassTopicCuration``
            - ``MyClass/unresolvablePropertyInMyClassTopicCuration``
            - <doc://com.test.external/ExternalPage>

            ### Near Miss

            - ``otherFunction()``
            - ``/MyKit/MyClas``
            - ``MyKit/MyClas/myFunction()``
            - <doc:MyKit/MyClas/myFunction()>
            
            ### Ambiguous curation

            - ``init()``
            - ``MyClass/init()-swift.init``
            - <doc:MyClass/init()-swift.init>
            """
            
            let documentationExtensionURL = url.appendingPathComponent("documentation/myclass.md")
            XCTAssert(FileManager.default.fileExists(atPath: documentationExtensionURL.path), "Make sure that the existing file is replaced.")
            try myKitDocumentationExtensionComment.write(to: documentationExtensionURL, atomically: true, encoding: .utf8)
        }
        
        let unresolvedTopicProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.unresolvedTopicReference" }
        
        XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.summary == "No external resolver registered for 'com.test.external'." }))
        
        var problem: Problem
        problem = try XCTUnwrap(unresolvedTopicProblems.first(where: { $0.diagnostic.summary == "'UnresolvableSymbolLinkInMyClassOverview<>(_:))' doesn't exist at '/MyKit/MyClass'" }))
        XCTAssertEqual(problem.diagnostic.notes.map(\.message), [])
        XCTAssertEqual(problem.possibleSolutions.count, 0)
        
        
        problem = try XCTUnwrap(unresolvedTopicProblems.first(where: { $0.diagnostic.summary == "'UnresolvableClassInMyClassTopicCuration' doesn't exist at '/MyKit/MyClass'" }))
        XCTAssertEqual(problem.diagnostic.notes.map(\.message), [])
        XCTAssertEqual(problem.possibleSolutions.count, 0)

        
        problem = try XCTUnwrap(unresolvedTopicProblems.first(where: { $0.diagnostic.summary == "'unresolvablePropertyInMyClassTopicCuration' doesn't exist at '/MyKit/MyClass'" }))
        XCTAssertEqual(problem.diagnostic.notes.map(\.message), [])
        XCTAssertEqual(problem.possibleSolutions.count, 0)

        
        problem = try XCTUnwrap(unresolvedTopicProblems.first(where: { $0.diagnostic.summary == "'init()' is ambiguous at '/MyKit/MyClass'" }))
        XCTAssert(problem.diagnostic.notes.isEmpty)
        XCTAssertEqual(problem.possibleSolutions.count, 2)
        XCTAssert(problem.possibleSolutions.map(\.replacements.count).allSatisfy { $0 == 1 })
        XCTAssertEqual(problem.possibleSolutions.map { [$0.summary, $0.replacements.first!.replacement] }, [
            ["Insert '33vaw' for \n'init()'", "-33vaw"],
            ["Insert '3743d' for \n'init()'", "-3743d"],
        ])
        XCTAssertEqual(try problem.possibleSolutions.first!.applyTo(contentsOf: url.appendingPathComponent("documentation/myclass.md")), """
        # ``MyKit/MyClass``

        @Metadata {
           @DocumentationExtension(mergeBehavior: override)
        }

        A cool API to call.

        This overview has an ``UnresolvableSymbolLinkInMyClassOverview<>(_:))``.

        - Parameters:
          - name: A parameter
        - Returns: Return value

        ## Topics

        ### Curation that won't resolve

        - ``UnresolvableClassInMyClassTopicCuration``
        - ``MyClass/unresolvablePropertyInMyClassTopicCuration``
        - <doc://com.test.external/ExternalPage>

        ### Near Miss

        - ``otherFunction()``
        - ``/MyKit/MyClas``
        - ``MyKit/MyClas/myFunction()``
        - <doc:MyKit/MyClas/myFunction()>

        ### Ambiguous curation

        - ``init()-33vaw``
        - ``MyClass/init()-swift.init``
        - <doc:MyClass/init()-swift.init>
        """)
        
        
        problem = try XCTUnwrap(unresolvedTopicProblems.first(where: {
            $0.diagnostic.range?.lowerBound.line == 33 && $0.diagnostic.summary == "'init()-swift.init' is ambiguous at '/MyKit/MyClass'"
        }))
        XCTAssert(problem.diagnostic.notes.isEmpty)
        XCTAssertEqual(problem.possibleSolutions.count, 2)
        XCTAssert(problem.possibleSolutions.map(\.replacements.count).allSatisfy { $0 == 1 })
        XCTAssertEqual(problem.possibleSolutions.map { [$0.summary, $0.replacements.first!.replacement] }, [
            ["Replace 'swift.init' with '33vaw' for \n'init()'", "-33vaw"],
            ["Replace 'swift.init' with '3743d' for \n'init()'", "-3743d"],
        ])
        XCTAssertEqual(try problem.possibleSolutions.first!.applyTo(contentsOf: url.appendingPathComponent("documentation/myclass.md")), """
        # ``MyKit/MyClass``

        @Metadata {
           @DocumentationExtension(mergeBehavior: override)
        }

        A cool API to call.

        This overview has an ``UnresolvableSymbolLinkInMyClassOverview<>(_:))``.

        - Parameters:
          - name: A parameter
        - Returns: Return value

        ## Topics

        ### Curation that won't resolve

        - ``UnresolvableClassInMyClassTopicCuration``
        - ``MyClass/unresolvablePropertyInMyClassTopicCuration``
        - <doc://com.test.external/ExternalPage>

        ### Near Miss

        - ``otherFunction()``
        - ``/MyKit/MyClas``
        - ``MyKit/MyClas/myFunction()``
        - <doc:MyKit/MyClas/myFunction()>

        ### Ambiguous curation

        - ``init()``
        - ``MyClass/init()-33vaw``
        - <doc:MyClass/init()-swift.init>
        """)
        
        
        problem = try XCTUnwrap(unresolvedTopicProblems.first(where: {
            $0.diagnostic.range?.lowerBound.line == 34 && $0.diagnostic.summary == "'init()-swift.init' is ambiguous at '/MyKit/MyClass'"
        }))
        XCTAssert(problem.diagnostic.notes.isEmpty)
        XCTAssertEqual(problem.possibleSolutions.count, 2)
        XCTAssert(problem.possibleSolutions.map(\.replacements.count).allSatisfy { $0 == 1 })
        XCTAssertEqual(problem.possibleSolutions.map { [$0.summary, $0.replacements.first!.replacement] }, [
            ["Replace 'swift.init' with '33vaw' for \n'init()'", "-33vaw"],
            ["Replace 'swift.init' with '3743d' for \n'init()'", "-3743d"],
        ])
        XCTAssertEqual(try problem.possibleSolutions.first!.applyTo(contentsOf: url.appendingPathComponent("documentation/myclass.md")), """
        # ``MyKit/MyClass``

        @Metadata {
           @DocumentationExtension(mergeBehavior: override)
        }

        A cool API to call.

        This overview has an ``UnresolvableSymbolLinkInMyClassOverview<>(_:))``.

        - Parameters:
          - name: A parameter
        - Returns: Return value

        ## Topics

        ### Curation that won't resolve

        - ``UnresolvableClassInMyClassTopicCuration``
        - ``MyClass/unresolvablePropertyInMyClassTopicCuration``
        - <doc://com.test.external/ExternalPage>

        ### Near Miss

        - ``otherFunction()``
        - ``/MyKit/MyClas``
        - ``MyKit/MyClas/myFunction()``
        - <doc:MyKit/MyClas/myFunction()>

        ### Ambiguous curation

        - ``init()``
        - ``MyClass/init()-swift.init``
        - <doc:MyClass/init()-33vaw>
        """)

        
        problem = try XCTUnwrap(unresolvedTopicProblems.first(where: { $0.diagnostic.summary == "'otherFunction()' doesn't exist at '/MyKit/MyClass'" }))
        XCTAssertEqual(problem.diagnostic.notes.map(\.message), [])
        XCTAssertEqual(problem.possibleSolutions.count, 1)
        XCTAssert(problem.possibleSolutions.map(\.replacements.count).allSatisfy { $0 == 1 })
        XCTAssertEqual(problem.possibleSolutions.map { [$0.summary, $0.replacements.first!.replacement] }, [
            ["Replace 'otherFunction()' with 'myFunction()'", "myFunction()"],
        ])
        XCTAssertEqual(try problem.possibleSolutions.first!.applyTo(contentsOf: url.appendingPathComponent("documentation/myclass.md")), """
        # ``MyKit/MyClass``

        @Metadata {
           @DocumentationExtension(mergeBehavior: override)
        }

        A cool API to call.

        This overview has an ``UnresolvableSymbolLinkInMyClassOverview<>(_:))``.

        - Parameters:
          - name: A parameter
        - Returns: Return value

        ## Topics

        ### Curation that won't resolve

        - ``UnresolvableClassInMyClassTopicCuration``
        - ``MyClass/unresolvablePropertyInMyClassTopicCuration``
        - <doc://com.test.external/ExternalPage>

        ### Near Miss

        - ``myFunction()``
        - ``/MyKit/MyClas``
        - ``MyKit/MyClas/myFunction()``
        - <doc:MyKit/MyClas/myFunction()>

        ### Ambiguous curation

        - ``init()``
        - ``MyClass/init()-swift.init``
        - <doc:MyClass/init()-swift.init>
        """)
        
        
        problem = try XCTUnwrap(unresolvedTopicProblems.first(where: {
            $0.diagnostic.range?.lowerBound.line == 26 && $0.diagnostic.summary == "'MyClas' doesn't exist at '/MyKit'"
        }))
        XCTAssertEqual(problem.diagnostic.notes.map(\.message), [])
        XCTAssertEqual(problem.possibleSolutions.count, 1)
        XCTAssert(problem.possibleSolutions.map(\.replacements.count).allSatisfy { $0 == 1 })
        XCTAssertEqual(problem.possibleSolutions.map { [$0.summary, $0.replacements.first!.replacement] }, [
            ["Replace 'MyClas' with 'MyClass'", "MyClass"],
        ])
        XCTAssertEqual(try problem.possibleSolutions.first!.applyTo(contentsOf: url.appendingPathComponent("documentation/myclass.md")), """
        # ``MyKit/MyClass``

        @Metadata {
           @DocumentationExtension(mergeBehavior: override)
        }

        A cool API to call.

        This overview has an ``UnresolvableSymbolLinkInMyClassOverview<>(_:))``.

        - Parameters:
          - name: A parameter
        - Returns: Return value

        ## Topics

        ### Curation that won't resolve

        - ``UnresolvableClassInMyClassTopicCuration``
        - ``MyClass/unresolvablePropertyInMyClassTopicCuration``
        - <doc://com.test.external/ExternalPage>

        ### Near Miss

        - ``otherFunction()``
        - ``/MyKit/MyClass``
        - ``MyKit/MyClas/myFunction()``
        - <doc:MyKit/MyClas/myFunction()>

        ### Ambiguous curation

        - ``init()``
        - ``MyClass/init()-swift.init``
        - <doc:MyClass/init()-swift.init>
        """)
        
        
        problem = try XCTUnwrap(unresolvedTopicProblems.first(where: {
            $0.diagnostic.range?.lowerBound.line == 27 && $0.diagnostic.summary == "'MyClas' doesn't exist at '/MyKit'"
        }))
        XCTAssertEqual(problem.diagnostic.notes.map(\.message), [])
        XCTAssertEqual(problem.possibleSolutions.count, 1)
        XCTAssert(problem.possibleSolutions.map(\.replacements.count).allSatisfy { $0 == 1 })
        XCTAssertEqual(problem.possibleSolutions.map { [$0.summary, $0.replacements.first!.replacement] }, [
            ["Replace 'MyClas' with 'MyClass'", "MyClass"],
        ])
        XCTAssertEqual(try problem.possibleSolutions.first!.applyTo(contentsOf: url.appendingPathComponent("documentation/myclass.md")), """
        # ``MyKit/MyClass``

        @Metadata {
           @DocumentationExtension(mergeBehavior: override)
        }

        A cool API to call.

        This overview has an ``UnresolvableSymbolLinkInMyClassOverview<>(_:))``.

        - Parameters:
          - name: A parameter
        - Returns: Return value

        ## Topics

        ### Curation that won't resolve

        - ``UnresolvableClassInMyClassTopicCuration``
        - ``MyClass/unresolvablePropertyInMyClassTopicCuration``
        - <doc://com.test.external/ExternalPage>

        ### Near Miss

        - ``otherFunction()``
        - ``/MyKit/MyClas``
        - ``MyKit/MyClass/myFunction()``
        - <doc:MyKit/MyClas/myFunction()>

        ### Ambiguous curation

        - ``init()``
        - ``MyClass/init()-swift.init``
        - <doc:MyClass/init()-swift.init>
        """)
        
        
        problem = try XCTUnwrap(unresolvedTopicProblems.first(where: {
            $0.diagnostic.range?.lowerBound.line == 28 && $0.diagnostic.summary == "'MyClas' doesn't exist at '/MyKit'"
        }))
        XCTAssertEqual(problem.diagnostic.notes.map(\.message), [])
        XCTAssertEqual(problem.possibleSolutions.count, 1)
        XCTAssert(problem.possibleSolutions.map(\.replacements.count).allSatisfy { $0 == 1 })
        XCTAssertEqual(problem.possibleSolutions.map { [$0.summary, $0.replacements.first!.replacement] }, [
            ["Replace 'MyClas' with 'MyClass'", "MyClass"],
        ])
        XCTAssertEqual(try problem.possibleSolutions.first!.applyTo(contentsOf: url.appendingPathComponent("documentation/myclass.md")), """
        # ``MyKit/MyClass``

        @Metadata {
           @DocumentationExtension(mergeBehavior: override)
        }

        A cool API to call.

        This overview has an ``UnresolvableSymbolLinkInMyClassOverview<>(_:))``.

        - Parameters:
          - name: A parameter
        - Returns: Return value

        ## Topics

        ### Curation that won't resolve

        - ``UnresolvableClassInMyClassTopicCuration``
        - ``MyClass/unresolvablePropertyInMyClassTopicCuration``
        - <doc://com.test.external/ExternalPage>

        ### Near Miss

        - ``otherFunction()``
        - ``/MyKit/MyClas``
        - ``MyKit/MyClas/myFunction()``
        - <doc:MyKit/MyClass/myFunction()>

        ### Ambiguous curation

        - ``init()``
        - ``MyClass/init()-swift.init``
        - <doc:MyClass/init()-swift.init>
        """)
    }
    
    func testUnresolvedReferenceWarningsInDocComment() throws {
        let docComment = """
        A cool API to call.

        This overview has an ``UnresolvableSymbolLinkInMyClassOverview``.

        - Parameters:
          - name: A parameter
        - Returns: Return value

        # Topics

        ## Unresolvable curation

        - ``UnresolvableClassInMyClassTopicCuration``
        - ``MyClass/unresolvablePropertyInMyClassTopicCuration``
        - <doc://com.test.external/ExternalPage>
        """
        
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { url in
            var graph = try JSONDecoder().decode(SymbolGraph.self, from: Data(contentsOf: url.appendingPathComponent("mykit-iOS.symbols.json")))
            let myFunctionUSR = "s:5MyKit0A5ClassC10myFunctionyyF"

            // SymbolKit.SymbolGraph.LineList.SourceRange.Position is indexed from 0, whereas
            // (absolute) Markdown.SourceLocations are indexed from 1
            let newDocComment = SymbolGraph.LineList(docComment.components(separatedBy: .newlines).enumerated().map { lineNumber, lineText in
                .init(text: lineText, range: .init(start: .init(line: lineNumber, character: 0), end: .init(line: lineNumber, character: lineText.count)))
            })
            graph.symbols[myFunctionUSR]?.docComment = newDocComment
            
            let newGraphData = try JSONEncoder().encode(graph)
            try newGraphData.write(to: url.appendingPathComponent("mykit-iOS.symbols.json"))
        }
        
        let unresolvedTopicProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.unresolvedTopicReference" }
        
        var problem: Problem
        problem = try XCTUnwrap(unresolvedTopicProblems.first(where: { $0.diagnostic.summary == "'UnresolvableSymbolLinkInMyClassOverview' doesn't exist at '/MyKit/MyClass/myFunction()'" }))
        XCTAssert(problem.diagnostic.notes.isEmpty)
        XCTAssertEqual(problem.possibleSolutions.count, 1)
        XCTAssert(problem.possibleSolutions.map(\.replacements.count).allSatisfy { $0 == 1 })
        XCTAssertEqual(problem.possibleSolutions.map { [$0.summary, $0.replacements.first!.replacement] }, [
            ["Replace 'UnresolvableSymbolLinkInMyClassOverview' with 'Unresolvable-curation'", "Unresolvable-curation"],
        ])
        XCTAssertEqual(try problem.possibleSolutions.first!.applyTo(docComment), """
        A cool API to call.

        This overview has an ``Unresolvable-curation``.

        - Parameters:
          - name: A parameter
        - Returns: Return value

        # Topics

        ## Unresolvable curation

        - ``UnresolvableClassInMyClassTopicCuration``
        - ``MyClass/unresolvablePropertyInMyClassTopicCuration``
        - <doc://com.test.external/ExternalPage>
        """)
        
        problem = try XCTUnwrap(unresolvedTopicProblems.first(where: { $0.diagnostic.summary == "'UnresolvableClassInMyClassTopicCuration' doesn't exist at '/MyKit/MyClass/myFunction()'" }))
        XCTAssert(problem.diagnostic.notes.isEmpty)
        XCTAssertEqual(problem.possibleSolutions.count, 1)
        XCTAssert(problem.possibleSolutions.map(\.replacements.count).allSatisfy { $0 == 1 })
        XCTAssertEqual(problem.possibleSolutions.map { [$0.summary, $0.replacements.first!.replacement] }, [
            ["Replace 'UnresolvableClassInMyClassTopicCuration' with 'Unresolvable-curation'", "Unresolvable-curation"],
        ])
        XCTAssertEqual(try problem.possibleSolutions.first!.applyTo(docComment), """
        A cool API to call.

        This overview has an ``UnresolvableSymbolLinkInMyClassOverview``.

        - Parameters:
          - name: A parameter
        - Returns: Return value

        # Topics

        ## Unresolvable curation

        - ``Unresolvable-curation``
        - ``MyClass/unresolvablePropertyInMyClassTopicCuration``
        - <doc://com.test.external/ExternalPage>
        """)
        
        
        problem = try XCTUnwrap(unresolvedTopicProblems.first(where: { $0.diagnostic.summary == "'unresolvablePropertyInMyClassTopicCuration' doesn't exist at '/MyKit/MyClass'" }))
        XCTAssert(problem.diagnostic.notes.isEmpty)
        XCTAssertEqual(problem.possibleSolutions.count, 0)
        XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.summary == "No external resolver registered for 'com.test.external'." }))
    }
    
    func testTopicSectionInDocComment() throws {
        let (withArticleOverride, problems) = try makeDocumentationNodeSymbol(
            docComment: """
                This is an abstract.

                This is a multi-paragraph overview.

                It continues here.

                - Parameters:
                  - name: Name parameter is explained here.

                - Returns: Return value is explained here.

                ## Topics

                ### Name of a topic

                - ``MyKit``
                - ``MyKit/MyClass``
                """,
            articleContent: nil
        )
        XCTAssert(problems.isEmpty)
        
        XCTAssertEqual(withArticleOverride.abstract?.format(), "This is an abstract.",
                       "The article overrides the abstract from the in-source documenation")
        XCTAssertEqual((withArticleOverride.discussion?.content ?? []).map { $0.detachedFromParent.format() }, ["This is a multi-paragraph overview.", "It continues here."],
                       "The article overries—and adds—a discussion.")
        
        if let parameter = withArticleOverride.parametersSection?.parameters.first, withArticleOverride.parametersSection?.parameters.count == 1 {
            XCTAssertEqual(parameter.name, "name")
            XCTAssertEqual(parameter.contents.map { $0.format() }, ["Name parameter is explained here."])
        } else {
            XCTFail("Unexpected parameters for `myFunction` in documentation from article override.")
        }
        
        XCTAssertEqual((withArticleOverride.returnsSection?.content ?? []).map { $0.format() }, ["Return value is explained here."],
                       "The article overries—and removes—the return section from the in-source documentation.")
        
        if let topicContent = withArticleOverride.topics?.content, let heading = topicContent.first as? Heading, let topics = topicContent.last as? UnorderedList {
            XCTAssertEqual(heading.detachedFromParent.format(), "### Name of a topic")
            XCTAssertEqual(topics.childCount, 2)
        } else {
            XCTFail("Unexpected topics for `myFunction` in documentation from article override.")
        }
    }
    
    func testCreatesSourceURLFromLocationMixin() throws {
        let identifer = SymbolGraph.Symbol.Identifier(precise: "s:5MyKit0A5ClassC10myFunctionyyF", interfaceLanguage: "swift")
        let names = SymbolGraph.Symbol.Names(title: "", navigator: nil, subHeading: nil, prose: nil)
        let pathComponents = ["path", "to", "my file.swift"]
        let range = SymbolGraph.LineList.SourceRange(
            start: .init(line: 0, character: 0),
            end: .init(line: 0, character: 0)
        )
        let line = SymbolGraph.LineList.Line(text: "@Image this is a known directive", range: range)
        let docComment = SymbolGraph.LineList([line])
        let symbol = SymbolGraph.Symbol(
            identifier: identifer,
            names: names,
            pathComponents: pathComponents,
            docComment: docComment,
            accessLevel: .init(rawValue: "public"),
            kind: SymbolGraph.Symbol.Kind(parsedIdentifier: .func, displayName: "myFunction"),
            mixins: [
                SymbolGraph.Symbol.Location.mixinKey: SymbolGraph.Symbol.Location(uri: "file:///path/to/my file.swift", position: range.start),
            ]
        )
        
        let engine = DiagnosticEngine()
        let _ = DocumentationNode.contentFrom(documentedSymbol: symbol, documentationExtension: nil, engine: engine)
        XCTAssertEqual(engine.problems.count, 0)
    }

    func testAddingConstraintsToSymbol() throws {
        let (withoutArticle, _) = try makeDocumentationNodeSymbol(
            docComment: """
                A cool API to call.

                - Parameters:
                  - name: A parameter
                - Returns: Return value
                """,
            articleContent: nil
        )

        // The original symbol has 3 generic constraints:
        // {
        //   "extendedModule": "MyKit",
        //   "constraints": [
        //     {
        //       "kind": "sameType",
        //       "lhs": "Label",
        //       "rhs": "Text"
        //     },
        //     {
        //       "kind": "superclass",
        //       "lhs": "Observer",
        //       "rhs": "NSObject"
        //     },
        //     {
        //       "kind": "conformance",
        //       "lhs": "S",
        //       "rhs": "StringProtocol"
        //     }
        //   ]
        // }
        XCTAssertEqual("MyKit", withoutArticle.extendedModuleVariants[DocumentationDataVariantsTrait.swift])
        var constraints = try XCTUnwrap(withoutArticle.constraints)
        XCTAssertEqual(3, constraints.count)
        XCTAssertEqual(.init(kind: .sameType, leftTypeName: "Label", rightTypeName: "Text"), constraints[0])
        XCTAssertEqual(.init(kind: .superclass, leftTypeName: "Observer", rightTypeName: "NSObject"), constraints[1])
        XCTAssertEqual(.init(kind: .conformance, leftTypeName: "S", rightTypeName: "StringProtocol"), constraints[2])

        // Declaration fragments are also stored as a mixins variant for this fixture.
        let trait = DocumentationDataVariantsTrait.swift
        let swiftDeclarationVariants = try XCTUnwrap(withoutArticle.declarationVariants[trait])
        XCTAssertEqual(1, swiftDeclarationVariants.count)
        let fragments = swiftDeclarationVariants.first!.value
        XCTAssertEqual(9, fragments.declarationFragments.count)

        // Add a new generic constraint for Swift
        let newConstraint = SymbolGraph.Symbol.Swift.GenericConstraint(
            kind: .sameType,
            leftTypeName: "Self",
            rightTypeName: "MutableCollection"
        )
        withoutArticle.addSwiftExtensionConstraint(extendedModule: "MyKit", constraint: newConstraint)

        // Check there are now 4 constraints
        constraints = try XCTUnwrap(withoutArticle.constraints)
        XCTAssertEqual(4, constraints.count)
        XCTAssertEqual(.init(kind: .sameType, leftTypeName: "Label", rightTypeName: "Text"), constraints[0])
        XCTAssertEqual(.init(kind: .superclass, leftTypeName: "Observer", rightTypeName: "NSObject"), constraints[1])
        XCTAssertEqual(.init(kind: .conformance, leftTypeName: "S", rightTypeName: "StringProtocol"), constraints[2])
        XCTAssertEqual(.init(kind: .sameType, leftTypeName: "Self", rightTypeName: "MutableCollection"), constraints[3])

        // Declaration fragments should remain unchanged
        XCTAssertEqual(1, withoutArticle.declarationVariants[trait]!.count)

        // Add another new generic constraint for Swift, but extending a
        // different module.
        let newConstraint2 = SymbolGraph.Symbol.Swift.GenericConstraint(
            kind: .sameType,
            leftTypeName: "Self",
            rightTypeName: "NSExtensionRequestHandling"
        )

        // Clear all the mixins for this symbol and test adding the first generic constraint
        withoutArticle.mixinsVariants[
            trait,
            default: [:]
        ].removeValue(forKey: SymbolGraph.Symbol.Swift.Extension.mixinKey)
        withoutArticle.addSwiftExtensionConstraint(extendedModule: "Foundation", constraint: newConstraint2)
        constraints = try XCTUnwrap(withoutArticle.constraints)
        XCTAssertEqual(1, constraints.count)
        XCTAssertEqual(.init(kind: .sameType, leftTypeName: "Self", rightTypeName: "NSExtensionRequestHandling"), constraints[0])

        // Declaration fragments should remain unchanged
        XCTAssertEqual(1, withoutArticle.declarationVariants[trait]!.count)
    }

    // MARK: - Helpers
    
    func makeDocumentationNodeSymbol(docComment: String, articleContent: String?, file: StaticString = #file, line: UInt = #line) throws -> (Symbol, [Problem]) {
        let myFunctionUSR = "s:5MyKit0A5ClassC10myFunctionyyF"
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
            var graph = try JSONDecoder().decode(SymbolGraph.self, from: Data(contentsOf: url.appendingPathComponent("mykit-iOS.symbols.json")))
            
            let newDocComment = SymbolGraph.LineList(docComment.components(separatedBy: .newlines).enumerated().map { arg -> SymbolGraph.LineList.Line in
                let (index, line) = arg
                let range = SymbolGraph.LineList.SourceRange(
                    start: .init(line: index, character: 0),
                    end: .init(line: index, character: line.utf8.count)
                )
                return .init(text: line, range: range)
            })
            // The `guard` statement` below will handle the `nil` case by failing the test and
            graph.symbols[myFunctionUSR]?.docComment = newDocComment
            
            let newGraphData = try JSONEncoder().encode(graph)
            try newGraphData.write(to: url.appendingPathComponent("mykit-iOS.symbols.json"))
        }
        
        guard let original = context.documentationCache[myFunctionUSR], let symbol = original.symbol, let symbolSemantic = original.semantic as? Symbol else {
            XCTFail("Couldn't find the expected symbol", file: (file), line: line)
            enum TestHelperError: Error { case missingExpectedMyFuctionSymbol }
            throw TestHelperError.missingExpectedMyFuctionSymbol
        }
        
        let article: Article? = articleContent.flatMap {
            let document = Document(parsing: $0, options: .parseBlockDirectives)
            var problems = [Problem]()
            let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(article, "The sidecar Article couldn't be created.", file: (file), line: line)
            XCTAssert(problems.isEmpty, "Unexpectedly found problems: \(DiagnosticConsoleWriter.formattedDescription(for: problems))", file: (file), line: line)
            return article
        }
        
        let engine = DiagnosticEngine()
        let node = DocumentationNode(reference: original.reference, symbol: symbol, platformName: symbolSemantic.platformName.map { $0.rawValue }, moduleReference: symbolSemantic.moduleReference, article: article, engine: engine)
        let semantic = try XCTUnwrap(node.semantic as? Symbol)
        return (semantic, engine.problems)
    }
}


extension Solution {
    func applyTo(contentsOf url: URL) throws -> String {
        let content = String(data: try Data(contentsOf: url), encoding: .utf8)!
        return try self.applyTo(content)
    }
    
    func applyTo(_ content: String) throws -> String {
        var content = content
        
        // We have to make sure we don't change the indices for later replacements while applying
        // earlier ones. As long as replacement ranges don't overlap it's enough to apply
        // replacements from bottom-most to top-most.
        for replacement in self.replacements.sorted(by: \.range.lowerBound).reversed() {
            content.replaceSubrange(replacement.range.lowerBound.index(in: content)..<replacement.range.upperBound.index(in: content), with: replacement.replacement)
        }
        
        return content
    }
}

extension SourceLocation {
    func index(in string: String) -> String.Index {
        var line = 1
        var column = 1
        for index in string.indices {
            let character = string[index]
            
            if line == self.line && column == self.column || line > self.line {
                return index
            }
            
            if character.isNewline {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }
        
        return string.endIndex
    }
}
