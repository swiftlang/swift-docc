/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SwiftDocC
import Foundation
import Markdown

protocol CheckerTest: AnyObject {}

extension CheckerTest {
    func createDocumentationNode(for document: Document) -> DocumentationNode {
        return DocumentationNode(reference: ResolvedTopicReference(bundleIdentifier: "test", path : "/test", sourceLanguage: .swift), kind: .article, sourceLanguage: .swift, name: .conceptual(title: "test"), markup: document, semantic: Semantic())
    }
}
