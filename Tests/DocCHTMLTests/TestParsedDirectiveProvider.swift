/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import DocCHTML
import Markdown

struct StubParsedDirectiveProvider: RenderableDirectiveParser {
    var parsed: (BlockDirective) -> RenderableDirective?
    
    init() { parsed = { _ in return nil } }
    init(parsed: RenderableDirective?) {
        self.parsed = { _ in return parsed }
    }
    func parse(blockDirective: BlockDirective) -> RenderableDirective? { parsed(blockDirective) }
}
