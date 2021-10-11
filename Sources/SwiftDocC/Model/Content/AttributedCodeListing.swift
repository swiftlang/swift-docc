/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A code block represented as lines of lexical tokens.
///
/// Use attributed code listings to represent code written in a specific programming language.
public struct AttributedCodeListing: Hashable {
    /// The source-code language for this code listing.
    public let sourceLanguage: SourceLanguage?

    /// The lines of code in the listing.
    public let codeLines: [Line]

    /// An identifiable title for this code listing.
    public let title: String?

    /// Indicates whether the code listing is empty or contains exclusively empty code.
    public var isEmpty: Bool {
        for codeLine in codeLines where !codeLine.isEmpty {
            return false
        }
        return true
    }
}

extension AttributedCodeListing {
    /// A single line of tokenized code in an attributed code listing.
    public struct Line: Hashable {
        /// The code elements in this line.
        ///
        /// Tokens form a line's contents. A code line can be empty, to allow for line breaks between blocks of code.
        /// An empty code line is indicated by a ``AttributedCodeListing/Line`` with an empty `tokens` array.
        public var tokens: [Token]

        /// Creates a new empty line.
        ///
        /// Empty lines have no tokens.
        public init() { self.tokens = [] }

        /// Creates a line consisting of the given tokens.
        public init(_ tokens: [Token]) { self.tokens = tokens }

        /// Indicates whether the code line is empty, which means it contains no code elements.
        public var isEmpty: Bool { return tokens.isEmpty }
    }
    
    /// Creates an attributed code listing from plain text.
    ///
    /// This initializer splits the given plain text by newline characters and represents each line in a plain-text lexical token. Use this API
    /// if you don't have a tokenized version of your code block.
    ///
    /// - Parameters:
    ///   - sourceLanguage: The source-code language in which the code is written in.
    ///   - plainText: The code as plain text.
    ///   - title: The title of the code listing.
    public init(sourceLanguage: SourceLanguage?, plainText: String, title: String?) {
        let codeLines = plainText.split(separator: "\n").map { Line([.plain(String($0))]) }
        self.init(sourceLanguage: sourceLanguage, codeLines: codeLines, title: title)
    }
}

extension AttributedCodeListing.Line {
    /// An element in a line of code.
    public enum Token: Hashable, CustomStringConvertible {
        /// Text in a code line with no indicated semantic meaning.
        case plain(String)
        
        /// A keyword reserved by the language.
        ///
        /// Example keywords in the Swift programming language are `func` and `typealias`.
        case keyword(String)
        
        /// An identifier name, such as the name of a symbol.
        case identifier(String)
        
        /// A number literal as written in code.
        case numberLiteral(String)
        
        /// A string literal as written in code.
        case stringLiteral(String)
        
        /// The name of a parameter in a function-like construct.
        case parameterName(String)
        
        /// The name of a generic type parameter.
        case genericTypeParameterName(String)
        
        /// An attribute, typically associated with the declaration of a symbol.
        ///
        /// An attribute consists of a name and a content. The name of the attribute includes syntactic markers, such as the `@` in
        /// Swift. The contents of an attribute are the text that follows the name in the attribute's declaration.
        case attribute(name: String, contents: String?)
        
        /// An annotation in code that indicates the type name of an identifier.
        ///
        /// A type annotation has a name and a unique identifier for the type, if known.
        case typeAnnotation(name: String, usr: String?)
        
        public var description: String {
            switch self {
            case .plain(let string):
                return string
            case .keyword(let string):
                return string
            case .identifier(let string):
                return string
            case .numberLiteral(let string):
                return string
            case .stringLiteral(let string):
                return string
            case .parameterName(let string):
                return string
            case .genericTypeParameterName(let string):
                return string
            case .attribute(let name, let contents):
                if let contents = contents {
                    return "@\(name)(\(contents))"
                } else {
                    return "@\(name)"
                }
            case .typeAnnotation(let name, _):
                return name
            }
        }
    }
}


/// A reference to a code listing that hasn't been resolved yet.
public struct UnresolvedCodeListingReference {
    /// The name identifier of the code listing.
    public var identifier: String
    
    /// Creates an unresolved code listing reference given its name identifier.
    public init(identifier: String) {
        self.identifier = identifier
    }
}

