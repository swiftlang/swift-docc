/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

struct DirectiveMirror {
    let reflectedDirective: ReflectedDirective
    
    init(reflecting directive: AutomaticDirectiveConvertible.Type) {
        let mirror = Mirror(
            reflecting: directive.init(
                originalMarkup: BlockDirective(
                    name: "temporary",
                    children: []
                )
            )
        )
        
        let reflectedArguments = mirror.children.compactMap { child -> ReflectedArgument? in
            guard let argument = child.value as? _DirectiveArgumentProtocol else {
                return nil
            }
            
            guard var label = child.label else {
                return nil
            }
            
            // Property wrappers have underscore-prefixed names
            if label.first == "_" {
                label.removeFirst()
            }
            
            let unnamed: Bool
            let argumentName: String
            switch argument.name {
            case .unnamed:
                unnamed = true
                argumentName = ""
            case .custom(let value):
                unnamed = false
                argumentName = value
            case .inferredFromPropertyName:
                unnamed = false
                argumentName = label
            }
            
            return ReflectedArgument(
                storedAsOptional: argument.storedAsOptional,
                required: argument.required,
                typeDisplayName: argument.typeDisplayName,
                name: argumentName,
                unnamed: unnamed,
                allowedValues: argument.allowedValues,
                expectedFormat: argument.expectedFormat,
                propertyLabel: label,
                argument: argument,
                parseArgument: argument.parseArgument
            )
        }
        
        let reflectedChildDirectives = mirror.children.compactMap { child -> ReflectedChildDirective? in
            guard let childDirective = child.value as? _ChildDirectiveProtocol else {
                return nil
            }
            
            guard var label = child.label else {
                return nil
            }
            
            // Property wrappers have underscore-prefixed names
            if label.first == "_" {
                label.removeFirst()
            }
            
            let requirements: ReflectedChildDirective.Requirements
            switch childDirective.requirements {
            case .zeroOrMore:
                requirements = .zeroOrMore
            case .one:
                requirements = .one
            case .zeroOrOne:
                requirements = .zeroOrOne
            case .oneOrMore:
                requirements = .oneOrMore
            }
            
            return ReflectedChildDirective(
                type: childDirective.directiveConvertible,
                requirements: requirements,
                storedAsArray: childDirective.storedAsArray,
                storedAsOptional: childDirective.storedAsOptional,
                propertyLabel: label,
                childDirective: childDirective
            )
        }
        
        
        
        let reflectedMarkupContainerRequirements = mirror.children.compactMap { child -> ReflectedChildMarkup? in
            guard let childMarkup = child.value as? _ChildMarkupProtocol else {
                return nil
            }
            
            guard var label = child.label else {
                return nil
            }
            
            // Property wrappers have underscore-prefixed names
            if label.first == "_" {
                label.removeFirst()
            }
            
            return ReflectedChildMarkup(
                propertyLabel: label,
                markup: childMarkup
            )
        }
        
        let childMarkupSupport: ReflectedDirective.ChildMarkupSupport
        if !reflectedMarkupContainerRequirements.isEmpty {
            childMarkupSupport = .supportsMarkup(reflectedMarkupContainerRequirements)
        } else {
            childMarkupSupport = .disallowsMarkup
        }
        
        self.reflectedDirective = ReflectedDirective(
            arguments: reflectedArguments,
            childDirectives: reflectedChildDirectives,
            childMarkupSupport: childMarkupSupport,
            type: directive
        )
    }
}

extension DirectiveMirror {
    struct ReflectedArgument {
        let storedAsOptional: Bool
        
        /// Whether or not this argument is required.
        let required: Bool
        
        /// The name of this argument's type for use in diagnostics and documentation.
        let typeDisplayName: String
        
        var labelDisplayName: String {
            if unnamed {
                return "_ \(propertyLabel)"
            } else {
                return name
            }
        }
        
        var hiddenFromDocumentation: Bool {
            return argument.hiddenFromDocumentation
        }
        
        let name: String
        
        let unnamed: Bool
        
        let allowedValues: [String]?
        let expectedFormat: String?
        
        let propertyLabel: String
        let argument: _DirectiveArgumentProtocol
        
        let parseArgument: (_ bundle: DocumentationBundle, _ argumentValue: String) -> (Any?)
        
        func setValue(
            on containingDirective: some AutomaticDirectiveConvertible,
            to any: Any
        ) {
            argument.setProperty(
                on: containingDirective,
                named: propertyLabel,
                to: any
            )
        }
    }
    
    struct ReflectedChildDirective {
        enum Requirements {
            case zeroOrOne
            case one
            
            case zeroOrMore
            case oneOrMore
        }
        
        let type: DirectiveConvertible.Type
        
        let requirements: Requirements
        
        var storedAsArray: Bool
        var storedAsOptional: Bool
        
        var name: String {
            return type.directiveName
        }
        
        var required: Bool {
            return requirements == .one || requirements == .oneOrMore
        }
        
        let propertyLabel: String
        let childDirective: _ChildDirectiveProtocol
        
        func setValue(
            on containingDirective: some AutomaticDirectiveConvertible,
            to any: Any
        ) {
            childDirective.setProperty(
                on: containingDirective,
                named: propertyLabel,
                to: any
            )
        }
    }
    
    struct ReflectedDirective {
        var name: String {
            return type.directiveName
        }
        var introducedVersion: String {
            return type.introducedVersion
        }
        
        let arguments: [ReflectedArgument]
        
        let childDirectives: [ReflectedChildDirective]
        
        enum ChildMarkupSupport {
            case supportsMarkup([ReflectedChildMarkup])
            case disallowsMarkup
        }
        
        let childMarkupSupport: ChildMarkupSupport
        
        var allowsMarkup: Bool {
            switch childMarkupSupport {
            case .supportsMarkup:
                return true
            case .disallowsMarkup:
                return false
            }
        }
        
        var allowsStructuredMarkup: Bool {
            switch childMarkupSupport {
            case .supportsMarkup(let markupRequirements):
                return markupRequirements.first?.markup.supportsStructuredMarkup ?? false
            case .disallowsMarkup:
                return false
            }
        }
        
        var requiresMarkup: Bool {
            switch childMarkupSupport {
            case .supportsMarkup(let markupRequirements):
                return markupRequirements.contains(where: \.required)
            case .disallowsMarkup:
                return false
            }
        }
        
        var hiddenFromDocumentation: Bool {
            (type as? AutomaticDirectiveConvertible.Type)?.hiddenFromDocumentation ?? false
        }
        
        let type: DirectiveConvertible.Type
    }
    
    struct ReflectedChildMarkup {
        let propertyLabel: String
        var required: Bool {
            switch markup.numberOfParagraphs {
            case .oneOrMore:
                return true
            case .zeroOrMore:
                return false
            case .zeroOrOne:
                return false
            case .custom(let value):
                return value > 0
            }
        }
        
        let markup: _ChildMarkupProtocol
        
        func setValue(
            on containingDirective: some AutomaticDirectiveConvertible,
            to any: Any
        ) {
            markup.setProperty(
                on: containingDirective,
                named: propertyLabel,
                to: any
            )
        }
    }
}
