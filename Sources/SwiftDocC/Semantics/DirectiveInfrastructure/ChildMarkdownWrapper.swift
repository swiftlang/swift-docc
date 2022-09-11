/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

protocol _ChildMarkupProtocol {
    var numberOfParagraphs: _ChildMarkupParagraphs { get }
    
    var index: Int? { get }
    
    var supportsStructuredMarkup: Bool { get }
    
    func setProperty<T>(
        on containingDirective: T,
        named propertyName: String,
        to any: Any
    ) where T: AutomaticDirectiveConvertible
}

enum _ChildMarkupParagraphs {
    case zeroOrMore
    case zeroOrOne
    case oneOrMore
    case custom(Int)
}

/// A property wrapper that represents general-purpose markup within a directive.
///
/// This property wrapper is used internally in Swift-DocC when declaring directives
/// that support child markup content.
///
///     class Column: Semantic, AutomaticDirectiveConvertible {
///         let originalMarkup: BlockDirective
///
///         @ChildMarkup(numberOfParagraphs: .oneOrMore)
///         public private(set) var content: MarkupContainer
///
///         static var keyPaths: [String : AnyKeyPath] = [
///             "content" : \Column._content,
///         ]
///
///         init(originalMarkup: BlockDirective) {
///             self.originalMarkup = originalMarkup
///         }
///     }
///
/// > Warning: This property wrapper is exposed as public API of SwiftDocC so that clients
/// > have access to its projected value, but it is unsupported to attach this property
/// > wrapper to new declarations outside of SwiftDocC.
@propertyWrapper
public struct ChildMarkup<Value>: _ChildMarkupProtocol {
    var parsedValue: Value?
    
    var index: Int?
    
    var numberOfParagraphs: _ChildMarkupParagraphs
    
    /// Returns true if the child markup can contain structured markup content like
    /// rows and columns.
    var supportsStructuredMarkup: Bool
    
    public var wrappedValue: Value {
        get {
            parsedValue!
        }
        set {
            parsedValue = newValue
        }
    }
    
    @available(*, unavailable,
        message: "The value type must be a 'MarkupContainer'."
    )
    public init() {
        fatalError()
    }
    
    func setProperty<T>(
        on containingDirective: T,
        named propertyName: String,
        to any: Any
    ) where T: AutomaticDirectiveConvertible {
        let path = T.keyPaths[propertyName] as! ReferenceWritableKeyPath<T, ChildMarkup<Value>>
        let wrappedValuePath = path.appending(path: \Self.parsedValue)
        containingDirective[keyPath: wrappedValuePath] = any as! Value?
    }
}

extension ChildMarkup where Value == MarkupContainer {
    init(
        numberOfParagraphs: _ChildMarkupParagraphs = .oneOrMore,
        index: Int? = nil,
        supportsStructure: Bool = false
    ) {
        self.parsedValue = MarkupContainer()
        self.numberOfParagraphs = numberOfParagraphs
        self.index = index
        self.supportsStructuredMarkup = supportsStructure
    }
}

extension ChildMarkup where Value == Optional<MarkupContainer> {
    init(
        value: Value,
        numberOfParagraphs: _ChildMarkupParagraphs = .zeroOrMore,
        index: Int? = nil,
        supportsStructure: Bool = false
    ) {
        self.parsedValue = value
        self.numberOfParagraphs = numberOfParagraphs
        self.index = index
        self.supportsStructuredMarkup = supportsStructure
    }
}
