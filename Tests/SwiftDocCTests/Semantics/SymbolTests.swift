/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
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
                
                @Metadata {
                   @DocumentationExtension(mergeBehavior: append)
                }
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
    
    func testWarningWhenDocCommentContainsDirective() throws {
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

    func testUnresolvedReferenceWarningsInDocumentationExtension() throws {
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { url in
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

            ### Unresolvable curation

            - ``UnresolvableClassInMyClassTopicCuration``
            - ``MyClass/unresolvablePropertyInMyClassTopicCuration``
            - <doc://com.test.external/ExternalPage>
            
             ### Ambiguous curation
             
             - ``init()``
             - ``MyClass/init()-swift.init``
            """
            
            let documentationExtensionURL = url.appendingPathComponent("documentation/myclass.md")
            XCTAssert(FileManager.default.fileExists(atPath: documentationExtensionURL.path), "Make sure that the existing file is replaced.")
            try myKitDocumentationExtensionComment.write(to: documentationExtensionURL, atomically: true, encoding: .utf8)
        }
        
        let unresolvedTopicProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.unresolvedTopicReference" }
        
        XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'doc://com.test.external/ExternalPage' couldn't be resolved. No external resolver registered for 'com.test.external'." }))
        if LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver {
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'UnresolvableSymbolLinkInMyClassOverview<>(_:))' couldn't be resolved. Reference at '/MyKit/MyClass' can't resolve 'UnresolvableSymbolLinkInMyClassOverview<>(_:))'. Available children: init(), myFunction()." }))
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'UnresolvableClassInMyClassTopicCuration' couldn't be resolved. Reference at '/MyKit/MyClass' can't resolve 'UnresolvableClassInMyClassTopicCuration'. Available children: init(), myFunction()." }))

            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'MyClass/unresolvablePropertyInMyClassTopicCuration' couldn't be resolved. Reference at '/MyKit/MyClass' can't resolve 'unresolvablePropertyInMyClassTopicCuration'. Available children: init(), myFunction()." }))
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'init()' couldn't be resolved. Reference is ambiguous after '/MyKit/MyClass': Append '-33vaw' to refer to 'init()'. Append '-3743d' to refer to 'init()'." }))
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'MyClass/init()-swift.init' couldn't be resolved. Reference is ambiguous after '/MyKit/MyClass': Append '-33vaw' to refer to 'init()'. Append '-3743d' to refer to 'init()'." }))
        } else {
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'UnresolvableSymbolLinkInMyClassOverview<>(_:))' couldn't be resolved. No local documentation matches this reference." }))
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'UnresolvableClassInMyClassTopicCuration' couldn't be resolved. No local documentation matches this reference." }))
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'MyClass/unresolvablePropertyInMyClassTopicCuration' couldn't be resolved. No local documentation matches this reference." }))
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'init()' couldn't be resolved. No local documentation matches this reference." }))
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'MyClass/init()-swift.init' couldn't be resolved. No local documentation matches this reference." }))
        }
    }
    
    func testUnresolvedReferenceWarningsInDocComment() throws {
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { url in
            var graph = try JSONDecoder().decode(SymbolGraph.self, from: Data(contentsOf: url.appendingPathComponent("mykit-iOS.symbols.json")))
            let myFunctionUSR = "s:5MyKit0A5ClassC10myFunctionyyF"
            
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

            let position: SymbolGraph.LineList.SourceRange.Position = .init(line: 1, character: 1)
            let newDocComment = SymbolGraph.LineList(docComment.components(separatedBy: .newlines).map { .init(text: $0, range: .init(start: position, end: position)) })
            graph.symbols[myFunctionUSR]?.docComment = newDocComment
            
            let newGraphData = try JSONEncoder().encode(graph)
            try newGraphData.write(to: url.appendingPathComponent("mykit-iOS.symbols.json"))
        }
        
        let unresolvedTopicProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.unresolvedTopicReference" }
        
        if LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver {
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'UnresolvableSymbolLinkInMyClassOverview' couldn't be resolved. Reference at '/MyKit/MyClass/myFunction()' can't resolve 'UnresolvableSymbolLinkInMyClassOverview'. Available children: Unresolvable-curation." }))
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'UnresolvableClassInMyClassTopicCuration' couldn't be resolved. Reference at '/MyKit/MyClass/myFunction()' can't resolve 'UnresolvableClassInMyClassTopicCuration'. Available children: Unresolvable-curation." }))
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'MyClass/unresolvablePropertyInMyClassTopicCuration' couldn't be resolved. Reference at '/MyKit/MyClass' can't resolve 'unresolvablePropertyInMyClassTopicCuration'. Available children: init(), myFunction()." }))
        } else {
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'UnresolvableSymbolLinkInMyClassOverview' couldn't be resolved. No local documentation matches this reference." }))
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'UnresolvableClassInMyClassTopicCuration' couldn't be resolved. No local documentation matches this reference." }))
            XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'MyClass/unresolvablePropertyInMyClassTopicCuration' couldn't be resolved. No local documentation matches this reference." }))
        }
        XCTAssertTrue(unresolvedTopicProblems.contains(where: { $0.diagnostic.localizedSummary == "Topic reference 'doc://com.test.external/ExternalPage' couldn't be resolved. No external resolver registered for 'com.test.external'." }))
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
        XCTAssertEqual(engine.problems.count, 1)
        let problem = try XCTUnwrap(engine.problems.first)
        XCTAssertEqual(problem.diagnostic.source?.path, "/path/to/my file.swift")
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
        
        guard let original = context.symbolIndex[myFunctionUSR], let symbol = original.symbol, let symbolSemantic = original.semantic as? Symbol else {
            XCTFail("Couldn't find the expected symbol", file: (file), line: line)
            enum TestHelperError: Error { case missingExpectedMyFuctionSymbol }
            throw TestHelperError.missingExpectedMyFuctionSymbol
        }
        
        let article: Article? = articleContent.flatMap {
            let document = Document(parsing: $0, options: .parseBlockDirectives)
            var problems = [Problem]()
            let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(article, "The sidecar Article couldn't be created.", file: (file), line: line)
            XCTAssert(problems.isEmpty, "Unexpectedly found problems: \(problems.localizedDescription)", file: (file), line: line)
            return article
        }
        
        let engine = DiagnosticEngine()
        let node = DocumentationNode(reference: original.reference, symbol: symbol, platformName: symbolSemantic.platformName.map { $0.rawValue }, moduleReference: symbolSemantic.moduleReference, article: article, engine: engine)
        let semantic = try XCTUnwrap(node.semantic as? Symbol)
        return (semantic, engine.problems)
    }
}
