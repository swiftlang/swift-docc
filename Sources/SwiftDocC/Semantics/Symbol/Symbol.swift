/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import SymbolKit

/// A programming symbol semantic type.
public final class Symbol: Semantic, Abstracted, Redirected, AutomaticTaskGroupsProviding {
    /// The symbol kind, such as protocol or variable.
    public let kind: SymbolGraph.Symbol.Kind
    /// The title, usually a simplified version of the declaration.
    public let title: String
    /// The simplified version of the declaration to use inside groups that may contain multiple links.
    public let subHeading: [SymbolGraph.Symbol.DeclarationFragments.Fragment]?
    /// The simplified version of the declaration to use in navigation UI.
    public let navigator: [SymbolGraph.Symbol.DeclarationFragments.Fragment]?
    /// The presentation-friendly variant of the symbol's kind.
    public let roleHeading: String
    /// The symbol's platform, if available.
    public let platformName: PlatformName?
    /// The presentation-friendly name of the symbol's framework.
    public let moduleName: String
    /// The name of the module extension in which the symbol is defined, if applicable.
    public let extendedModule: String?
    /// Optional cross-import module names.
    public let bystanderModuleNames: [String]?
    /// If `true`, the symbol is required in its context.
    public var isRequired: Bool
    /// The symbol external identifier, if available.
    public var externalID: String?
    /// The symbol's access level, if available.
    public var accessLevel: String?
    /// The symbol's deprecation information, if deprecated.
    public var deprecatedSummary: DeprecatedSection?
    /// The symbol's declarations.
    public var declaration: [[PlatformName?]: SymbolGraph.Symbol.DeclarationFragments] = [:]
    /// The place where a symbol was originally declared in a source file.
    public var location: SymbolGraph.Symbol.Location?
    /// The symbol's availability or conformance constraints.
    public var constraints: [SymbolGraph.Symbol.Swift.GenericConstraint]?
    /// Inheritance information.
    public var origin: SymbolGraph.Relationship.SourceOrigin?
    /// The platforms on which the symbol is available.
    /// - note: Updating this property recalculates `isDeprecated`.
    public var availability: SymbolGraph.Symbol.Availability? {
        didSet {
            if let availability = availability {
                // When appending more platform availabilities to the symbol
                // update its deprecation status
                isDeprecated = AvailabilityParser(availability).isDeprecated()
            }
        }
    }

    /// The presentation-friendly relationships to other symbols.
    public var relationships = RelationshipsSection()
    /// An optional, abstract summary for the symbol.
    public var abstractSection: AbstractSection?
    /// An optional discussion for the symbol.
    public var discussion: DiscussionSection?
    /// Topics task groups for the symbol.
    public var topics: TopicsSection?
    /// Any default implementations, if the symbol is a protocol requirement.
    public var defaultImplementations = DefaultImplementationsSection()
    /// Any See Also groups for the symbol.
    public var seeAlso: SeeAlsoSection?
    /// Any return value information, if the symbol returns.
    public var returnsSection: ReturnsSection?
    /// Any parameters, if the symbol accepts parameters.
    public var parametersSection: ParametersSection?
    /// Any redirect information, if the symbol has been moved from another location.
    public var redirects: [Redirect]?
    
    // The abstract summary as a single paragraph.
    public var abstract: Paragraph? {
        return abstractSection?.paragraph
    }
    
    /// If `true`, the symbol is deprecated.
    public var isDeprecated = false
    
    /// If true, the symbols is an SPI.
    public var isSPI = false
    
    /// The mixins of the symbol
    var mixins: [String: Mixin]?
    
    /// Any automatically created task groups.
    var automaticTaskGroups: [AutomaticTaskGroupSection]

    /// Creates a new symbol with the given data.
    init(
        kind: SymbolGraph.Symbol.Kind,
        title: String,
        subHeading: [SymbolGraph.Symbol.DeclarationFragments.Fragment]?,
        navigator: [SymbolGraph.Symbol.DeclarationFragments.Fragment]?,
        roleHeading: String,
        platformName: PlatformName?,
        moduleName: String,
        extendedModule: String? = nil,
        required: Bool = false,
        externalID: String?,
        accessLevel: String?,
        availability: SymbolGraph.Symbol.Availability?,
        deprecatedSummary: DeprecatedSection?,
        mixins: [String: Mixin]?,
        declaration: [[PlatformName?]: SymbolGraph.Symbol.DeclarationFragments] = [:],
        defaultImplementations: DefaultImplementationsSection = DefaultImplementationsSection(),
        relationships: RelationshipsSection? = nil,
        abstractSection: AbstractSection?,
        discussion: DiscussionSection?,
        topics: TopicsSection?,
        seeAlso: SeeAlsoSection?,
        returnsSection: ReturnsSection?,
        parametersSection: ParametersSection?,
        redirects: [Redirect]?,
        bystanderModuleNames: [String]? = nil,
        origin: SymbolGraph.Relationship.SourceOrigin? = nil,
        automaticTaskGroups: [AutomaticTaskGroupSection]? = nil
    ) {
        self.kind = kind
        self.title = title
        self.subHeading = subHeading
        self.navigator = navigator
        self.roleHeading = roleHeading
        self.platformName = platformName
        self.moduleName = moduleName
        self.bystanderModuleNames = bystanderModuleNames
        self.isRequired = required
        self.externalID = externalID
        self.accessLevel = accessLevel
        self.availability = availability
        if let availability = availability {
            self.isDeprecated = AvailabilityParser(availability).isDeprecated()
        }
        self.deprecatedSummary = deprecatedSummary
        self.declaration = declaration
        
        if let mixins = mixins {
            self.mixins = mixins
        
            for item in mixins.values {
                switch item {
                case let declaration as SymbolGraph.Symbol.DeclarationFragments:
                    // If declaration wasn't set explicitly use the one from the mixins.
                    if self.declaration.isEmpty {
                        self.declaration[[platformName]] = declaration
                    }
                case let extensionConstraints as SymbolGraph.Symbol.Swift.Extension where !extensionConstraints.constraints.isEmpty:
                    self.constraints = extensionConstraints.constraints
                case let location as SymbolGraph.Symbol.Location:
                    self.location = location
                case let spi as SymbolGraph.Symbol.SPI:
                    self.isSPI = spi.isSPI
                default: break;
                }
            }
        }
        
        if let relationships = relationships {
            self.relationships = relationships
        }
        
        self.defaultImplementations = defaultImplementations
        
        self.abstractSection = abstractSection
        self.discussion = discussion
        self.topics = topics
        self.seeAlso = seeAlso
        self.returnsSection = returnsSection
        self.parametersSection = parametersSection
        self.redirects = redirects
        self.origin = origin
        self.automaticTaskGroups = automaticTaskGroups ?? []
        self.extendedModule = extendedModule
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitSymbol(self)
    }
}

extension Symbol {
    
    /// Merges a symbol declaration from another symbol graph into the current symbol.
    ///
    /// When building multi-platform documentation symbols might have more than one declaration
    /// depending on variances in their implementation across platforms (e.g. use ``NSPoint`` vs ``CGPoint`` parameter in a method).
    /// This method finds matching symbols between graphs and merges their declarations in case there are differences.
    func mergeDeclaration(mergingDeclaration: SymbolGraph.Symbol.DeclarationFragments, otherSymbol symbol: SymbolGraph.Symbol, otherSymbolGraph: SymbolGraph) throws {
        if let platformName = otherSymbolGraph.module.platform.name,
            let existingKey = declaration.first(where: { pair in
            return pair.value.declarationFragments == mergingDeclaration.declarationFragments
        })?.key {
            guard !existingKey.contains(nil) else {
                throw DocumentationContext.ContextError.unexpectedEmptyPlatformName(symbol.identifier.precise)
            }
            
            // Matches one of the existing declarations, append to the existing key.
            let currentDeclaration = declaration.removeValue(forKey: existingKey)!
            declaration[existingKey + [PlatformName(operatingSystemName: platformName)]] = currentDeclaration
        } else {
            // Add new declaration
            if let name = otherSymbolGraph.module.platform.name {
                declaration[[PlatformName.init(operatingSystemName: name)]] = mergingDeclaration
            } else {
                declaration[[nil]] = mergingDeclaration
            }
        }
        
        // Merge the new symbol with the existing availability. If a value already exist, only override if it's for this platform.
        if let symbolAvailability = symbol.mixins[SymbolGraph.Symbol.Availability.mixinKey] as? SymbolGraph.Symbol.Availability,
            symbolAvailability.availability.isEmpty == false || availability?.availability.isEmpty == false // Nothing to merge if both are empty
        {
            var items = availability?.availability ?? []
        
            // Add all the domains that don't already have availability information
            for availability in symbolAvailability.availability {
                guard !items.contains(where: { $0.domain?.rawValue == availability.domain?.rawValue }) else { continue }
                items.append(availability)
            }
            
            // Override the availability for all domains that apply to this platform
            if let modulePlatformName = otherSymbolGraph.module.platform.name.map(PlatformName.init) {
                let symbolAvailabilityForPlatform = symbolAvailability.filterItems(thatApplyTo: modulePlatformName)
                
                for availability in symbolAvailabilityForPlatform.availability {
                    items.removeAll(where: { $0.domain?.rawValue == availability.domain?.rawValue })
                    items.append(availability)
                }
            }
            
            availability = SymbolGraph.Symbol.Availability(availability: items)
        }
    }
}
