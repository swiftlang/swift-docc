/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import DocCHTML
import Markdown

struct StubParsedDirectiveProvider: ParsedDirectiveProvider {
    var parsed: (BlockDirective) -> ParsedDirective?
    
    init() { parsed = { _ in return nil } }
    init(parsed: ParsedDirective?) {
        self.parsed = { _ in return parsed }
    }
    func parse(blockDirective: BlockDirective) -> ParsedDirective? { parsed(blockDirective) }
}
