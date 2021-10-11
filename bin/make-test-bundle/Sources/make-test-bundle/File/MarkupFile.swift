/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A markup file.
struct MarkupFile {
    enum Kind {
        case docExt(String)
        case article
    }
    
    let kind: Kind
    var bundle: OutputBundle
    
    var path: String = ""
    let fileName: String
    
    static var counter = 0
    
    var collectedArticles = [MarkupFile]()
    
    init(kind: Kind, bundle: OutputBundle) {
        self.kind = kind
        self.bundle = bundle
        
        switch kind {
        case .article:
            Self.counter += 1
            self.fileName = "article-\(Self.counter).md"
        case .docExt(let path):
            self.path = path
            self.fileName = path.replacingOccurrences(of: "/", with: "-").appending(".md")
        }
    }
    
    mutating func source() -> String {
        var result = ""
        switch kind {
        case .article:
            result += "# \(Text.sentence(maxWords: 10))"
            result += Text.docs(for: path.components(separatedBy: "/").last!, bundle: bundle, numSections: 3)

        case .docExt(let path):
            result += "# ``\(path)``\n\n"
            result += """
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            """
            result += "\n"
            result += Text.docs(for: path.components(separatedBy: "/").last!, bundle: bundle)
        }
        
        result += "> Tip: Added via a documentation extension file _\(fileName)_."
        result = result.replacingOccurrences(of: "/// ", with: "")
        result += "\n\n"
        
        switch kind {
        case .docExt(let fullPath):
            if let node = TypeNode.index[fullPath], !node.childNames.isEmpty {
                result += "## Topics\n\n"
                
                var items = node.childNames.shuffled()
                let groupCount = max(1, items.count / 4)
                var groups = [[String]]()
                while items.count > groupCount {
                    groups.append(Array(items.prefix(groupCount)))
                    items.removeFirst(groupCount)
                }
                groups.append(items)
                
                for group in groups {
                    result += "### \(Text.sentence(maxWords: 5))\n\n"
                    result += Text.sentence().appending("\n\n")
                    
                    let freeFormArticle = MarkupFile(kind: .article, bundle: bundle)
                    collectedArticles.append(freeFormArticle)
                    
                    result += " - <doc:\(freeFormArticle.fileName.replacingOccurrences(of: ".md", with: ""))> \n"
                    result += group.map({ " - ``\($0)``\n" }).joined()
                }
                result += "\n\n"
            }
        default: break
        }
        
        return result
    }
}
