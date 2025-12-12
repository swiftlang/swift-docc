/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(FoundationXML)
// TODO: Consider other HTML rendering options as a future improvement (rdar://165755530)
package import FoundationXML
#else
package import Foundation
#endif

package import Markdown

package extension MarkdownRenderer {
 
    /// Creates a discussion section with the given markup.
    ///
    /// If the markup doesn't start with a level-2 heading, the renderer will insert a level-2 heading based on the `fallbackSectionName`.
    func discussion(_ markup: [any Markup], fallbackSectionName: String) -> [XMLNode] {
        guard !markup.isEmpty else { return [] }
        var remaining = markup[...]
        
        let sectionName: String
        // Check if the markup already contains an explicit heading
        if let heading = remaining.first as? Heading, heading.level == 2 {
            _ = remaining.removeFirst() // Remove the heading so that it's not rendered twice
            sectionName = heading.plainText
        } else {
            sectionName = fallbackSectionName
        }
        
        return selfReferencingSection(named: sectionName, content: remaining.map { visit($0) })
    }
}
