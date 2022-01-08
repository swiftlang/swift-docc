/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@testable import SwiftDocC
import SwiftDocCTestUtilities

/// A folder that represents a fake html-build directory for testing.
extension Folder {
    
    static let emptyHTMLTemplateDirectory = Folder(name: "template", content: [
        TextFile(name: "index.html", utf8Content: ""), TextFile(name: "index-template.html", utf8Content: "")
    ])
    
    static let testHTMLTemplate = """
        <script src="{{BASE_PATH}}/js/chunk-vendors.00bf82af.js"></script>
        <script src="{{BASE_PATH}}/js/index.91d1fa8e.js"></script>
    """

    static func testHTMLTemplate(basePath: String) -> String {

            return """
                <script src="/\(basePath)/js/chunk-vendors.00bf82af.js"></script>
                <script src="/\(basePath)/js/index.91d1fa8e.js"></script>
            """
    }
    
    static let testHTMLTemplateDirectory: Folder = {
        
        let css = Folder(name: "css", content: [
            TextFile(name: "test.css", utf8Content: "")])
            
        let js = Folder(name: "js", content: [
                TextFile(name: "test.js", utf8Content: "")])
                
        let index = TextFile(name: "index.html", utf8Content: "")
                
        let indexTemplate = TextFile(name: "index-template.html", utf8Content: testHTMLTemplate)
                        
        return Folder(name: "template", content: [index, indexTemplate, css, js])
    }()
}
