/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

struct DirectiveIndex {
    static let topLevelReferenceDirectives: [any AutomaticDirectiveConvertible.Type] = [
        Metadata.self,
        Redirect.self,
        Snippet.self,
        DeprecationSummary.self,
        Row.self,
        Options.self,
        Small.self,
        TabNavigator.self,
        Links.self,
        ImageMedia.self,
        VideoMedia.self,
    ]
    
    static let topLevelTutorialDirectives: [any AutomaticDirectiveConvertible.Type] = [
        Tutorial.self,
    ]
    
    /// Children of tutorial directives that have not yet been converted to be automatically
    /// convertible.
    ///
    /// This is a temporary workaround until the migration is complete and these child directives
    /// can be automatically reflected from their parent directives.
    private static let otherTutorialDirectives: [any AutomaticDirectiveConvertible.Type] = [
        Stack.self,
        Chapter.self,
        Choice.self,
    ]
    
    private static var allTopLevelDirectives = topLevelTutorialDirectives
        + topLevelReferenceDirectives
        + otherTutorialDirectives
    
    let indexedDirectives: [String : DirectiveMirror.ReflectedDirective]
    
    let renderableDirectives: [String : AnyRenderableDirectiveConvertibleType]
    
    static let shared = DirectiveIndex()
    
    private init() {
        // Pre-populate the directory index by iterating through the explicitly declared
        // top-level directives, finding their children and reflecting those as well.
        
        var indexedDirectives = [String : DirectiveMirror.ReflectedDirective]()
        
        for directive in Self.allTopLevelDirectives {
            let mirror = DirectiveMirror(reflecting: directive).reflectedDirective
            indexedDirectives[mirror.name] = mirror
        }
        
        var foundDirectives = indexedDirectives.values.flatMap(\.childDirectives).map(\.type)
        
        while !foundDirectives.isEmpty {
            let directive = foundDirectives.removeFirst()
            
            guard !indexedDirectives.keys.contains(directive.directiveName) else {
                continue
            }
            
            guard let automaticDirectiveConvertible = directive as? (any AutomaticDirectiveConvertible.Type) else {
                continue
            }
            
            let mirror = DirectiveMirror(reflecting: automaticDirectiveConvertible).reflectedDirective
            indexedDirectives[mirror.name] = mirror
            
            for childDirective in mirror.childDirectives.map(\.type) {
                guard !indexedDirectives.keys.contains(childDirective.directiveName) else {
                    continue
                }
                
                foundDirectives.append(childDirective)
            }
        }
        
        self.indexedDirectives = indexedDirectives
        
        self.renderableDirectives = indexedDirectives.compactMapValues { directive in
            guard let renderableDirective = directive.type as? (any RenderableDirectiveConvertible.Type) else {
                return nil
            }
            
            return AnyRenderableDirectiveConvertibleType(underlyingType: renderableDirective)
        }
    }
    
    func reflection(
        of directiveConvertible: any AutomaticDirectiveConvertible.Type
    ) -> DirectiveMirror.ReflectedDirective {
        // It's a programmer error if an automatic directive convertible
        // is not in the pre-populated index.
        return indexedDirectives[directiveConvertible.directiveName]!
    }
    
    func reflection(of implementationName: String) -> DirectiveMirror.ReflectedDirective? {
        return indexedDirectives.first(
            where: { (directiveName: String, reflectedDirective: DirectiveMirror.ReflectedDirective) in
                directiveName == implementationName || String(describing: reflectedDirective.type) == implementationName
            }
        )?.value
    }
    
    /// Returns the directive hierarchy as path components.
    ///
    /// The type that the directive's class is nested inside is part of the path when that type is an indexed directive.
    /// `SwiftDocC` in `SwiftDocC.TabNavigator.Tab`, however, would be skipped
    /// because the module name is not a directive.
    ///
    /// `TabNavigator.Tab` returns `["TabNavigator", "Tab"]`.
    /// `Metadata.Availability` returns `["Metadata", "Available"]`.
    /// `DisplayName` returns `["DisplayName"]`.
    ///
    /// - Parameter directive: The directive to build the hierarchy for.
    func pathComponents(of directive: DirectiveMirror.ReflectedDirective) -> [String] {
        let directivesByQualifiedTypeName = [String: DirectiveMirror.ReflectedDirective](
            indexedDirectives.values.map { (String(reflecting: $0.type), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        
        var enclosingTypeName = String(reflecting: directive.type)[...]
        var pathComponents = [directive.name]
        while let separatorIndex = enclosingTypeName.lastIndex(of: ".") {
            enclosingTypeName = enclosingTypeName[..<separatorIndex]
            if let enclosingDirective = directivesByQualifiedTypeName[String(enclosingTypeName)] {
                pathComponents.insert(enclosingDirective.name, at: 0)
            }
        }
        return pathComponents
    }
}
