/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
import Testing
@testable import SwiftDocC

struct MarkdownLinkFixitTests {
    @Test(arguments: [
        LinkFixItCase(
            source: "<doc:MyClass/init()>",
            expected: "<doc:MyClass/init()-33vaw>"
        ),
        LinkFixItCase(
            source: "[custom title](doc:MyClass/init())",
            expected: "[custom title](doc:MyClass/init()-33vaw)"
        ),
        LinkFixItCase(
            source: "[custom title](doc:MyClass/init() \"Initializer\")",
            expected: "[custom title](doc:MyClass/init()-33vaw \"Initializer\")"
        ),
        LinkFixItCase(
            source: "[doc:MyClass/init()](doc:MyClass/init())",
            expected: "[doc:MyClass/init()](doc:MyClass/init()-33vaw)"
        ),
        LinkFixItCase(
            source: "``MyClass/init()``",
            expected: "``MyClass/init()-33vaw``"
        ),
    ])
    func fixItReplacementRangesUseAuthoredReferenceBody(testCase: LinkFixItCase) throws {
        let link = try #require(firstLink(in: testCase.source))
        let diagnostic = unresolvedReferenceDiagnostic(
            source: nil,
            link: link,
            severity: .warning,
            errorInfo: TopicReferenceResolutionErrorInfo(
                "Test diagnostic",
                solutions: [
                    Solution(summary: "Insert '-33vaw'", replacements: [
                        .init(
                            range: .makeRelativeRange(startColumn: "MyClass/init()".count, length: 0),
                            replacement: "-33vaw"
                        )
                    ])
                ]
            ),
        )

        let solution = try #require(diagnostic.solutions.first)
        #expect(try solution.applyTo(testCase.source) == testCase.expected)
    }

    private func firstLink(in source: String) -> (any AnyLink)? {
        let document = Document(parsing: source, options: [.parseSymbolLinks])
        let links = links(in: document)
        return links.first { link in
            (link as? Link)?.isAutolink == false
        } ?? links.first
    }

    private func links(in markup: any Markup) -> [any AnyLink] {
        var result: [any AnyLink] = []
        if let link = markup as? any AnyLink {
            result.append(link)
        }

        for index in 0..<markup.childCount {
            if let child = markup.child(at: index) {
                result.append(contentsOf: links(in: child))
            }
        }

        return result
    }
}

struct LinkFixItCase: CustomStringConvertible, Sendable {
    var source: String
    var expected: String

    var description: String {
        source
    }
}
