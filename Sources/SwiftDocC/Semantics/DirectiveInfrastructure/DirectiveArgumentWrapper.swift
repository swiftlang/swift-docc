/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

protocol _DirectiveArgumentProtocol {
    var typeDisplayName: String { get }
    var storedAsOptional: Bool { get }
    var required: Bool { get }
    var name: _DirectiveArgumentName { get }
    var allowedValues: [String]? { get }
    var hiddenFromDocumentation: Bool { get }
    
    var parseArgument: (_ bundle: DocumentationBundle, _ argumentValue: String) -> (Any?) { get }
    
    func setProperty<T>(
        on containingDirective: T,
        named propertyName: String,
        to any: Any
    ) where T: AutomaticDirectiveConvertible
}

enum _DirectiveArgumentName {
    case unnamed
    case custom(String)
    case inferredFromPropertyName
}

/// A property wrapper that represents a directive argument.
///
/// This property wrapper is used internally in Swift-DocC when declaring directives
/// that accept arguments.
///
/// For example, this code snippet declares a `@CustomDisplayName` directive that accepts
/// a `name` argument with a `String` type.
///
///     class CustomDisplayName: Semantic, AutomaticDirectiveConvertible {
///         let originalMarkup: BlockDirective
///
///         @DirectiveArgumentWrapper(name: .unnamed)
///         private(set) var name: String
///
///         static var keyPaths: [String : AnyKeyPath] = [
///             "name" : \CustomDisplayName._name,
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
public struct DirectiveArgumentWrapped<Value>: _DirectiveArgumentProtocol {
    let name: _DirectiveArgumentName
    let typeDisplayName: String
    let allowedValues: [String]?
    let hiddenFromDocumentation: Bool
    
    let parseArgument: (_ bundle: DocumentationBundle, _ argumentValue: String) -> (Any?)
    
    let defaultValue: Value?
    var storedAsOptional: Bool {
        return defaultValue != nil
    }
    
    let required: Bool
    
    var parsedValue: Value?
    public var wrappedValue: Value {
        get {
            parsedValue ?? defaultValue!
        } set {
            parsedValue = newValue
        }
    }
    
    @available(*, unavailable,
        message: "The value type must conform to 'DirectiveArgumentValueConvertible'."
    )
    public init() {
        fatalError()
    }
    
    // Expected argument configurations
    
    @_disfavoredOverload
    init(
        wrappedValue: Value,
        name: _DirectiveArgumentName = .inferredFromPropertyName,
        parseArgument: @escaping (_ bundle: DocumentationBundle, _ argumentValue: String) -> (Value?),
        allowedValues: [String]? = nil,
        hiddenFromDocumentation: Bool = false
    ) {
        self.init(
            value: wrappedValue,
            name: name,
            transform: parseArgument,
            allowedValues: allowedValues,
            required: nil,
            hiddenFromDocumentation: hiddenFromDocumentation
        )
    }
    
    @_disfavoredOverload
    init(
        name: _DirectiveArgumentName = .inferredFromPropertyName,
        parseArgument: @escaping (_ bundle: DocumentationBundle, _ argumentValue: String) -> (Value?),
        allowedValues: [String]? = nil,
        hiddenFromDocumentation: Bool = false
    ) {
        self.init(
            value: nil,
            name: name,
            transform: parseArgument,
            allowedValues: allowedValues,
            required: nil,
            hiddenFromDocumentation: hiddenFromDocumentation
        )
    }
    
    private init(
        value: Value?,
        name: _DirectiveArgumentName,
        transform: @escaping (_ bundle: DocumentationBundle, _ argumentValue: String) -> (Value?),
        allowedValues: [String]?,
        required: Bool?,
        hiddenFromDocumentation: Bool
    ) {
        let required = required ?? (value == nil)
        
        self.name = name
        self.defaultValue = value
        self.typeDisplayName = typeDisplayNameDescription(defaultValue: value, required: required)
        self.parseArgument = transform
        self.allowedValues = allowedValues
        self.required = required
        self.hiddenFromDocumentation = hiddenFromDocumentation
    }
    
    func setProperty<T>(
        on containingDirective: T,
        named propertyName: String,
        to any: Any
    ) where T: AutomaticDirectiveConvertible {
        let path = T.keyPaths[propertyName] as! ReferenceWritableKeyPath<T, DirectiveArgumentWrapped<Value>>
        let wrappedValuePath = path.appending(path: \Self.parsedValue)
        containingDirective[keyPath: wrappedValuePath] = any as! Value?
    }
    
    // Warnings and errors for unexpected argument configurations
    
    @_disfavoredOverload
    @available(*, deprecated, message: "Use an optional type or a default value to control whether or not a directive argument is required.")
    init(
        wrappedValue: Value,
        name: _DirectiveArgumentName = .inferredFromPropertyName,
        parseArgument: @escaping (_ bundle: DocumentationBundle, _ argumentValue: String) -> (Value?),
        allowedValues: [String]? = nil,
        required: Bool,
        hiddenFromDocumentation: Bool = false
    ) {
        self.init(
            value: wrappedValue,
            name: name,
            transform: parseArgument,
            allowedValues: allowedValues,
            required: required,
            hiddenFromDocumentation: hiddenFromDocumentation
        )
    }
    
    @_disfavoredOverload
    @available(*, deprecated, message: "Use an optional type or a default value to control whether or not a directive argument is required.")
    init(
        name: _DirectiveArgumentName = .inferredFromPropertyName,
        parseArgument: @escaping (_ bundle: DocumentationBundle, _ argumentValue: String) -> (Value?),
        allowedValues: [String]? = nil,
        required: Bool,
        hiddenFromDocumentation: Bool = false
    ) {
        self.init(
            value: nil,
            name: name,
            transform: parseArgument,
            allowedValues: allowedValues,
            required: required,
            hiddenFromDocumentation: hiddenFromDocumentation
        )
    }
}

extension DirectiveArgumentWrapped where Value: DirectiveArgumentValueConvertible {
    // Expected argument configurations
    
    @_disfavoredOverload
    init(
        name: _DirectiveArgumentName = .inferredFromPropertyName,
        hiddenFromDocumentation: Bool = false
    ) {
        self.init(value: nil, name: name, hiddenFromDocumentation: hiddenFromDocumentation)
    }
    
    @_disfavoredOverload
    init(
        wrappedValue: Value,
        name: _DirectiveArgumentName = .inferredFromPropertyName,
        hiddenFromDocumentation: Bool = false
    ) {
        self.init(value: wrappedValue, name: name, hiddenFromDocumentation: hiddenFromDocumentation)
    }
    
    private init(value: Value?, name: _DirectiveArgumentName, hiddenFromDocumentation: Bool) {
        self.name = name
        self.defaultValue = value
        
        let required = value == nil
        self.typeDisplayName = typeDisplayNameDescription(defaultValue: value, required: required)
        self.parseArgument = { _, argument in
            Value.init(rawDirectiveArgumentValue: argument)
        }
        self.allowedValues = Value.allowedValues()
        self.required = required
        self.hiddenFromDocumentation = hiddenFromDocumentation
    }
    
    // Warnings and errors for unexpected argument configurations
    
    @_disfavoredOverload
    @available(*, unavailable, message: "Directive argument of non-optional types without default value need to be required. Use an optional type or provide a default value to make this argument non-required.")
    init(name: _DirectiveArgumentName = .inferredFromPropertyName, required: Bool) {
        fatalError()
    }
}

protocol _OptionalDirectiveArgument {
    associatedtype WrappedArgument
    var wrapped: WrappedArgument? { get }
    init(wrapping: WrappedArgument?)
}
extension Optional: _OptionalDirectiveArgument  {
    typealias WrappedArgument = Wrapped
    var wrapped: WrappedArgument? {
        switch self {
        case .some(let value):
            return value
        case .none: return
            nil
        }
    }
    init(wrapping: WrappedArgument?) {
        if let wrapped = wrapping {
            self = .some(wrapped)
        } else {
            self = .none
        }
    }
}

extension DirectiveArgumentWrapped where Value: _OptionalDirectiveArgument, Value.WrappedArgument: DirectiveArgumentValueConvertible {
    
    // When the wrapped value is DirectiveArgumentValueConvertible, additional arguments may be omitted
    
    init(
        name: _DirectiveArgumentName = .inferredFromPropertyName,
        hiddenFromDocumentation: Bool = false
    ) {
        self = .init(value: nil, name: name, hiddenFromDocumentation: hiddenFromDocumentation)
    }
    
    @_disfavoredOverload
    init(
        wrappedValue: Value,
        name: _DirectiveArgumentName = .inferredFromPropertyName,
        hiddenFromDocumentation: Bool = false
    ) {
        self = .init(value: wrappedValue, name: name, hiddenFromDocumentation: hiddenFromDocumentation)
    }
    
    private init(
        value: Value?,
        name: _DirectiveArgumentName,
        hiddenFromDocumentation: Bool
    ) {
        let argumentValueType = Value.WrappedArgument.self
        
        self = .init(
            value: value,
            name: name,
            parseArgument: { _, argument in
                Value(wrapping: argumentValueType.init(rawDirectiveArgumentValue: argument))
            },
            allowedValues: argumentValueType.allowedValues(),
            hiddenFromDocumentation: hiddenFromDocumentation
        )
    }
}

extension DirectiveArgumentWrapped where Value: _OptionalDirectiveArgument {
    
    // Expected argument configurations
    
    @_disfavoredOverload
    init(
        name: _DirectiveArgumentName = .inferredFromPropertyName,
        parseArgument: @escaping (_ bundle: DocumentationBundle, _ argumentValue: String) -> (Value?),
        allowedValues: [String]? = nil,
        hiddenFromDocumentation: Bool = false
    ) {
        self = .init(value: nil, name: name, parseArgument: parseArgument, allowedValues: allowedValues, hiddenFromDocumentation: hiddenFromDocumentation)
    }
    
    @_disfavoredOverload
    init(
        wrappedValue: Value,
        name: _DirectiveArgumentName = .inferredFromPropertyName,
        parseArgument: @escaping (_ bundle: DocumentationBundle, _ argumentValue: String) -> (Value?),
        allowedValues: [String]? = nil,
        hiddenFromDocumentation: Bool = false
    ) {
        self = .init(value: wrappedValue, name: name, parseArgument: parseArgument, allowedValues: allowedValues, hiddenFromDocumentation: hiddenFromDocumentation)
    }
    
    private init(
        value: Value?,
        name: _DirectiveArgumentName,
        parseArgument: @escaping (_ bundle: DocumentationBundle, _ argumentValue: String) -> (Value?),
        allowedValues: [String]? = nil,
        hiddenFromDocumentation: Bool = false
    ) {
        self.name = name
        self.defaultValue = value
        self.typeDisplayName = typeDisplayNameDescription(optionalDefaultValue: value, required: false)
        self.parseArgument = parseArgument
        self.allowedValues = allowedValues
        self.required = false
        self.hiddenFromDocumentation = hiddenFromDocumentation
    }
    
    // Warnings and errors for unexpected argument configurations
    
    @_disfavoredOverload
    @available(*, unavailable, message: "Directive arguments with an Optional type shouldn't be required.")
    init(
        name: _DirectiveArgumentName = .inferredFromPropertyName,
        required: Bool,
        hiddenFromDocumentation: Bool = false
    ) {
        fatalError()
    }
    
    @_disfavoredOverload
    @available(*, unavailable, message: "Directive arguments with an Optional type shouldn't be required.")
    init(
        wrappedValue: Value,
        name: _DirectiveArgumentName = .inferredFromPropertyName,
        required: Bool,
        hiddenFromDocumentation: Bool = false
    ) {
        fatalError()
    }
}

private func typeDisplayNameDescription<Value>(defaultValue: Value?, required: Bool) -> String {
    var name = "\(Value.self)"
    
    if let defaultValue = defaultValue {
        name += " = \(defaultValue)"
    } else if !required {
        name += "?"
    }
    
    return name
}

private func typeDisplayNameDescription<Value: _OptionalDirectiveArgument>(optionalDefaultValue: Value?, required: Bool) -> String {
    return typeDisplayNameDescription(defaultValue: optionalDefaultValue?.wrapped, required: required)
}
