/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

struct InitTemplateCatalog: Catalog {
    
    var title: String
    var articles: [String : Article] {
        [
            "\(title).md": Article(
                title: title,
                content: """
                
                Add a single sentence or sentence fragment, which DocC uses as the page’s abstract or summary.

                ## Overview

                Add one or more paragraphs that introduce your content overview.

                ## Usage Instructions

                To preview this documentation, use your terminal to navigate to the root of this
                DocC catalog and run:
                ```
                docc preview
                ```

                To generate a doccarchive navigate to the root of this
                DocC catalog and run:
                ```
                docc convert \(title).docc -o \(title).doccarchive
                ```
                
                ## Topics

                ### Essentials

                - <doc:getting_started>
                - <doc:more_information>
                """,
                isTechnologyRoot: true
            ),
            "Essentials/getting_started.md": Article(
                title: "Getting Started",
                content: """
                
                Summary
                
                Overview
                """
            ),
            "Essentials/more_information.md": Article(
                title: "More Information",
                content: """
                
                Summary
                
                Overview
                """
            )
        ]
    }
}


