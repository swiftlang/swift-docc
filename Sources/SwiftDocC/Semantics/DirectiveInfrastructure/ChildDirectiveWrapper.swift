/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

protocol _ChildDirectiveProtocol {
    var storedAsArray: Bool { get }
    var storedAsOptional: Bool { get }
    var requirements: ChildDirectiveRequirements { get }
    var directiveConvertible: DirectiveConvertible.Type { get }
    
    func setProperty<T>(
        on containingDirective: T,
        named propertyName: String,
        to any: Any
    ) where T: AutomaticDirectiveConvertible
}

enum ChildDirectiveRequirements {
    case zeroOrOne
    case one
    
    case zeroOrMore
    case oneOrMore
}

/// A property wrapper that represents a child directive.
///
/// This property wrapper is used internally in Swift-DocC when declaring directives
/// that support specific child directives.
///
///     class Row: Semantic, AutomaticDirectiveConvertible {
///         let originalMarkup: BlockDirective
///
///         @ChildDirective
///         private(set) var columns: [Column]
///
///         static var keyPaths: [String : AnyKeyPath] = [
///             "columns" : \Row._columns,
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
public struct ChildDirective<Value>: _ChildDirectiveProtocol {
    let storedAsArray: Bool
    let storedAsOptional: Bool
    
    var parsedValue: Value?
    let requirements: ChildDirectiveRequirements
    
    let directiveConvertible: DirectiveConvertible.Type
    
    public var wrappedValue: Value {
        get {
            parsedValue!
        }
        set {
            parsedValue = newValue
        }
    }
    
    @available(*, unavailable,
        message: "The value type must conform to 'DirectiveConvertible'."
    )
    public init() {
        fatalError()
    }
    
    func setProperty<T>(
        on containingDirective: T,
        named propertyName: String,
        to any: Any
    ) where T: AutomaticDirectiveConvertible {
        let path = T.keyPaths[propertyName] as! ReferenceWritableKeyPath<T, ChildDirective<Value>>
        let wrappedValuePath = path.appending(path: \Self.parsedValue)
        containingDirective[keyPath: wrappedValuePath] = any as! Value?
    }
}

extension ChildDirective where Value: DirectiveConvertible {
    init() {
        self.parsedValue = nil
        self.requirements = .one
        self.storedAsOptional = false
        self.storedAsArray = false
        self.directiveConvertible = Value.self
    }
}

protocol OptionallyWrappedDirectiveConvertible: OptionallyWrapped {}
extension Optional: OptionallyWrappedDirectiveConvertible where Wrapped: DirectiveConvertible {}
extension ChildDirective where Value: OptionallyWrappedDirectiveConvertible {
    init(wrappedValue: Value, requirements: ChildDirectiveRequirements = .zeroOrOne) {
        self.parsedValue = wrappedValue
        self.requirements = requirements
        self.storedAsOptional = true
        self.storedAsArray = false
        self.directiveConvertible = Value.baseType() as! DirectiveConvertible.Type
    }
}

protocol CollectionWrappedDirectiveConvertible: CollectionWrapped {}
extension Array: CollectionWrappedDirectiveConvertible where Element: DirectiveConvertible {}
extension ChildDirective where Value: CollectionWrappedDirectiveConvertible {
    init(requirements: ChildDirectiveRequirements = .zeroOrMore) {
        self.parsedValue = nil
        self.requirements = requirements
        self.storedAsOptional = false
        self.storedAsArray = true
        self.directiveConvertible = Value.baseType() as! DirectiveConvertible.Type
    }
}

protocol OptionallyWrappedCollectionWrappedDirectiveConvertible: OptionallyWrapped {}
extension Optional: OptionallyWrappedCollectionWrappedDirectiveConvertible where Wrapped: CollectionWrapped {}
extension ChildDirective where Value: OptionallyWrappedCollectionWrappedDirectiveConvertible {
    init(wrappedValue: Value) {
        self.parsedValue = wrappedValue
        self.requirements = .zeroOrMore
        self.storedAsOptional = true
        self.storedAsArray = true
        self.directiveConvertible = (Value.baseType() as! CollectionWrapped.Type).baseType() as! DirectiveConvertible.Type
    }
}
