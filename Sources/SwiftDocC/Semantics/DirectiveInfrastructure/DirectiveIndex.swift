/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

struct DirectiveIndex {
    private static let topLevelReferenceDirectives: [AutomaticDirectiveConvertible.Type] = [
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
    
    private static let topLevelTutorialDirectives: [AutomaticDirectiveConvertible.Type] = [
        Tutorial.self,
    ]
    
    /// Children of tutorial directives that have not yet been converted to be automatically
    /// convertible.
    ///
    /// This is a temporary workaround until the migration is complete and these child directives
    /// can be automatically reflected from their parent directives.
    private static let otherTutorialDirectives: [AutomaticDirectiveConvertible.Type] = [
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
            
            guard let automaticDirectiveConvertible = directive as? AutomaticDirectiveConvertible.Type else {
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
            guard let renderableDirective = directive.type as? RenderableDirectiveConvertible.Type else {
                return nil
            }
            
            return AnyRenderableDirectiveConvertibleType(underlyingType: renderableDirective)
        }
    }
    
    func reflection(
        of directiveConvertible: AutomaticDirectiveConvertible.Type
    ) -> DirectiveMirror.ReflectedDirective {
        // It's a programmer error if an automatic directive convertible
        // is not in the pre-populated index.
        return indexedDirectives[directiveConvertible.directiveName]!
    }
}
