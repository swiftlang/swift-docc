/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

struct CatalogFileTemplate {
    let title: String?
    let content: String
    var isTechnologyRoot: Bool = false
    
    init(content: String) {
        self.title = nil
        self.content = content
        self.isTechnologyRoot = false
    }
    
    init(title: String, content: String, isTechnologyRoot: Bool) {
        self.title = title
        self.isTechnologyRoot = isTechnologyRoot
        guard isTechnologyRoot else {
            self.content = content
            return
        }
        // Format the content of a DocC Article by adding
        // the title and the technology root.
        self.content = """
        # \(title)
        
        <!--- Metadata configuration to make appear this documentation page as a top-level page -->
        
        @Metadata {
          @TechnologyRoot
        }
        
        \(content)
        """
    }
}
