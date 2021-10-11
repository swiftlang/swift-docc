/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension String {
    var titleCase: String { prefix(1).capitalized.appending(dropFirst()) }
}

/// Complete sentences to use for constructing texts.
fileprivate let sentences = [
    "TestFramework provides APIs, data-models, controls, and layout structures for declaring a rich model to describe relationships and dependencies along with rich user interfaces.",
    "Define your application's structure using the rich data model and relationships defined by expressing relationships in a graph of nodes that interact with each other throughout the app life.",
    "Create your own custom node-based graph models by using the TestFramework rich APIs for describing connections between entities that are related via rich connections.",
    "Apply powerful modifiers to expressive chain-able queries that allow you to fetch batches of nodes via a rich query language from a graph-based in-memory model.",
    "You can integrate your app's workflow directly with TestFramework by adopting a hierarchy of protocol-based models that describe an in-memory model graph data queries."
]

/// A list of words to use for naming things.
var words = WrappingEnumerator<String>(items: [
    "Apple",
    "Apricot",
    "Avocado",
    "Banana",
    "Crabapple",
    "Currant",
    "Cherry",
    "Coconut",
    "Cranberry",
    "Date",
    "Dragonfruit",
    "Fig",
    "Grape",
    "Guava",
    "Kiwi",
    "Lemon",
    "Lime"
])

/// A set of functions to generate gibberish text.
enum Text {
    /// Makes a sentence with the given word limit.
    static func sentence(maxWords: Int? = nil) -> String {
        var result = sentences[Int.random(in: 0..<sentences.count)]
        if let words = maxWords {
            result = result.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter({ !$0.isEmpty })
                .prefix(words)
                .joined(separator: " ")
        }
        return result
    }
    
    /// Makes a paragraph.
    static func paragraph() -> String {
        return sentence() + "\n" + sentence() + "\n" + sentence() + "\n"
    }
    
    enum RichText: CaseIterable {
        case formatting, inlineCode, blockCode, images
    }
    
    /// Creates a text with the given traits.
    static func text(bundle: OutputBundle, numSections: Int = 2, formatting: [RichText] = []) -> String {
        var result = ""
        
        for _ in 1...numSections {
            var body = ""
            
            if formatting.contains(.images) {
                body += "![Accessible image description](\(bundle.topLevelImages.next().name))"
            }
            
            for i in 0 ..< 3 {
                if i == 2 {
                    body += "### Sub-Section \(i)\n\n"
                }
                
                if formatting.contains(.formatting) {
                    body += "This __paragraph__ contains ~~un~~formatted _text_. "
                }
                if formatting.contains(.inlineCode) {
                    body += "This type not only conforms to `Equatable` and `Hashable` but also to `StringLiteral`. "
                }
                body += paragraph() + "\n"
            }
            
            if formatting.contains(.blockCode) {
                body += """
                ```swift
                if ProcessInfo.Time.local.isAM {
                    print("Good morning")
                } else if ProcessInfo.Time.local.isBedTime {
                    print("Good night")
                } else {
                    print("Hello")
                }
                ```
                """.appending("\n")
            }
            
            result += body
        }
        return result
    }
    
    /// Creates a "Topics" section.
    static func topics(for name: String) -> String {
        var result = "## Topics\n"
        let name = name.components(separatedBy: CharacterSet.letters.inverted).joined()
        let idString = name.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let id = Int(idString) ?? 1
        
        for i in 0...3 {
            result += " - ``\(name)\(id+i)``\n"
        }
        return result
    }
    
    /// Creates a markup note.
    static func note() -> String {
        return "> Note: " + sentence() + "\n"
    }
    
    /// Converts the lines of a text as source comments.
    static func asComment(_ string: String) -> String {
        return string.components(separatedBy: .newlines)
            .map({ "/// \($0)" })
            .joined(separator: "\n")
    }
    
    enum DocSection: CaseIterable {
        case abstract, discussion, topics, note
    }
    
    /// Creates a documentation markup for a given type with the given traits.
    static func docs(for name: String, bundle: OutputBundle, sections: [DocSection] = Array(DocSection.allCases), numSections: Int = 1) -> String {
        var result = "\n"
        if sections.contains(.abstract) {
            result += Text.asComment(Text.sentence())
            result += "\n\n"
        }
        
        if sections.contains(.discussion) {
            result += Text.asComment("## Overview")
            result += "\n"
            result += Text.asComment(text(bundle: bundle, numSections: numSections, formatting: RichText.allCases))
            result += "\n\n"
        }

        if sections.contains(.note) {
            result += Text.asComment(note())
            result += "\n"
        }
        return result
    }
}
