/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import SymbolKit

/// A programming symbol semantic type.
///
/// This class's properties are represented using ``DocumentationDataVariants`` values which encode the different variants for each piece of information
/// about the symbol. For example, if a symbol is available in multiple programming languages, the ``titleVariants`` property represents the title of the symbol
/// for each programming language it's available in. Use a ``DocumentationDataVariantsTrait`` to access a specific variant.
///
/// ## Topics
///
/// ### Properties
///
/// - ``titleVariants``
/// - ``subHeadingVariants``
/// - ``navigatorVariants``
/// - ``roleHeadingVariants``
/// - ``kindVariants``
/// - ``platformNameVariants``
/// - ``moduleReference``
/// - ``extendedModule``
/// - ``bystanderModuleNames``
/// - ``isRequiredVariants``
/// - ``externalIDVariants``
/// - ``accessLevelVariants``
/// - ``deprecatedSummaryVariants``
/// - ``declarationVariants``
/// - ``locationVariants``
/// - ``constraintsVariants``
/// - ``originVariants``
/// - ``availabilityVariants``
/// - ``relationshipsVariants``
/// - ``abstractSectionVariants``
/// - ``discussionVariants``
/// - ``topicsVariants``
/// - ``defaultImplementationsVariants``
/// - ``seeAlsoVariants``
/// - ``returnsSectionVariants``
/// - ``parametersSectionVariants``
/// - ``redirectsVariants``
/// - ``abstractVariants``
/// - ``isDeprecatedVariants``
/// - ``isSPIVariants``
///
/// ### First Variant Accessors
///
/// Convenience APIs for accessing the first variant of the symbol's properties.
///
/// - ``kind``
/// - ``title``
/// - ``subHeading``
/// - ``navigator``
/// - ``roleHeading``
/// - ``platformName``
/// - ``isRequired``
/// - ``externalID``
/// - ``deprecatedSummary``
/// - ``declaration``
/// - ``location``
/// - ``constraints``
/// - ``origin``
/// - ``availability``
/// - ``relationships``
/// - ``accessLevel``
/// - ``discussion``
/// - ``abstractSection``
/// - ``topics``
/// - ``defaultImplementations``
/// - ``seeAlso``
/// - ``redirects``
/// - ``returnsSection``
/// - ``parametersSection``
/// - ``abstract``
/// - ``isDeprecated``
/// - ``isSPI``
///
/// ### Variants
///
/// - ``DocumentationDataVariants``
/// - ``DocumentationDataVariantsTrait``
public final class Symbol: Semantic, Abstracted, Redirected, AutomaticTaskGroupsProviding {
    /// The title of the symbol in each language variant the symbol is available in.
    internal(set) public var titleVariants: DocumentationDataVariants<String>
    
    /// The simplified version of the symbol's declaration in each language variant the symbol is available in.
    internal(set) public var subHeadingVariants: DocumentationDataVariants<[SymbolGraph.Symbol.DeclarationFragments.Fragment]>
    
    /// The simplified version of this symbol's declaration in each language variant the symbol is available in.
    internal(set) public var navigatorVariants: DocumentationDataVariants<[SymbolGraph.Symbol.DeclarationFragments.Fragment]>
    
    /// The presentation-friendly version of the symbol's kind in each language variant the symbol is available in.
    internal(set) public var roleHeadingVariants: DocumentationDataVariants<String>
    
    /// The kind of the symbol in each language variant the symbol is available in.
    internal(set) public var kindVariants: DocumentationDataVariants<SymbolGraph.Symbol.Kind>
    
    /// The symbol's platform in each language variant the symbol is available in.
    internal(set) public var platformNameVariants: DocumentationDataVariants<PlatformName>
    
    /// The reference to the documentation node that represents this symbol's module symbol.
    internal(set) public var moduleReference: ResolvedTopicReference
    
    /// The name of the module extension in which the symbol is defined, if applicable.
    internal(set) public var extendedModule: String?

    /// The names of any "bystander" modules required for this symbol, if it came from a cross-import overlay.
    @available(*, deprecated, message: "Use crossImportOverlayModule instead")
    public var bystanderModuleNames: [String]? {
        self.crossImportOverlayModule?.bystanderModules
    }
    
    /// Optional cross-import module names of the symbol.
    internal(set) public var crossImportOverlayModule: (declaringModule: String, bystanderModules: [String])?
    
    /// Whether the symbol is required in its context, in each language variant the symbol is available in.
    public var isRequiredVariants: DocumentationDataVariants<Bool>
    
    /// The symbol's external identifier, if available, in each language variant the symbol is available in.
    public var externalIDVariants: DocumentationDataVariants<String>
    
    /// The symbol's access level, if available, in each language variant the symbol is available in.
    public var accessLevelVariants: DocumentationDataVariants<String>
    
    /// The symbol's deprecation information, if deprecated, in each language variant the symbol is available in.
    public var deprecatedSummaryVariants: DocumentationDataVariants<DeprecatedSection>
    
    /// The symbol's declarations in each language variant the symbol is available in.
    public var declarationVariants = DocumentationDataVariants<[[PlatformName?]: SymbolGraph.Symbol.DeclarationFragments]>(
        defaultVariantValue: [:]
    )
    
    public var locationVariants = DocumentationDataVariants<SymbolGraph.Symbol.Location>()
    
    /// The symbol's availability or conformance constraints, in each language variant the symbol is available in.
    public var constraintsVariants = DocumentationDataVariants<[SymbolGraph.Symbol.Swift.GenericConstraint]>()
    
    /// The inheritance information for the symbol in each language variant the symbol is available in.
    public var originVariants: DocumentationDataVariants<SymbolGraph.Relationship.SourceOrigin>
    
    /// The platforms on which the symbol is available in each language variant the symbol is available in.
    ///
    /// - Note: Updating this property recalculates ``isDeprecatedVariants``.
    public var availabilityVariants: DocumentationDataVariants<SymbolGraph.Symbol.Availability> {
        didSet {
            for (trait, variant) in availabilityVariants.allValues {
                // When appending more platform availabilities to the symbol
                // update its deprecation status
                isDeprecatedVariants[trait] = AvailabilityParser(variant).isDeprecated()
            }
        }
    }
    
    /// The presentation-friendly relationships of this symbol to other symbols, in each language variant the symbol is available in.
    public var relationshipsVariants = DocumentationDataVariants<RelationshipsSection>(defaultVariantValue: .init())
    
    /// An optional, abstract summary for the symbol, in each language variant the symbol is available in.
    public var abstractSectionVariants: DocumentationDataVariants<AbstractSection>
    
    /// An optional discussion for the symbol, in each language variant the symbol is available in.
    public var discussionVariants: DocumentationDataVariants<DiscussionSection>
    
    /// The topics task groups for the symbol, in each language variant the symbol is available in.
    public var topicsVariants: DocumentationDataVariants<TopicsSection>
    
    /// Any default implementations of the symbol, if the symbol is a protocol requirement, in each language variant the symbol is available in.
    public var defaultImplementationsVariants = DocumentationDataVariants<DefaultImplementationsSection>(defaultVariantValue: .init())
    
    /// Any See Also groups of the symbol, in each language variant the symbol is available in.
    public var seeAlsoVariants: DocumentationDataVariants<SeeAlsoSection>
    
    /// Any return value information of the symbol, if the symbol returns, in each language variant the symbol is available in.
    public var returnsSectionVariants: DocumentationDataVariants<ReturnsSection>
    
    /// Any parameters of the symbol, if the symbol accepts parameters, in each language variant the symbol is available in.
    public var parametersSectionVariants: DocumentationDataVariants<ParametersSection>
    
    /// Any redirect information of the symbol, if the symbol has been moved from another location, in each language variant the symbol is available in.
    public var redirectsVariants: DocumentationDataVariants<[Redirect]>
    
    /// The symbol's abstract summary as a single paragraph, in each language variant the symbol is available in.
    public var abstractVariants: DocumentationDataVariants<Paragraph> {
        DocumentationDataVariants(
            values: Dictionary(uniqueKeysWithValues: abstractSectionVariants.allValues.map { ($0, $1.paragraph) })
        )
    }
    
    /// Whether the symbol is deprecated, in each language variant the symbol is available in.
    public var isDeprecatedVariants = DocumentationDataVariants<Bool>(defaultVariantValue: false)
    
    /// Whether the symbol is declared as an SPI, in each language variant the symbol is available in.
    public var isSPIVariants = DocumentationDataVariants<Bool>(defaultVariantValue: false)
    
    /// The mixins of the symbol, in each language variant the symbol is available in.
    var mixinsVariants: DocumentationDataVariants<[String: Mixin]>
    
    /// Any automatically created task groups of the symbol, in each language variant the symbol is available in.
    var automaticTaskGroupsVariants: DocumentationDataVariants<[AutomaticTaskGroupSection]>

    /// Creates a new symbol with the given data.
    init(
        kindVariants: DocumentationDataVariants<SymbolGraph.Symbol.Kind>,
        titleVariants: DocumentationDataVariants<String>,
        subHeadingVariants: DocumentationDataVariants<[SymbolGraph.Symbol.DeclarationFragments.Fragment]>,
        navigatorVariants: DocumentationDataVariants<[SymbolGraph.Symbol.DeclarationFragments.Fragment]>,
        roleHeadingVariants: DocumentationDataVariants<String>,
        platformNameVariants: DocumentationDataVariants<PlatformName>,
        moduleReference: ResolvedTopicReference,
        extendedModule: String? = nil,
        requiredVariants: DocumentationDataVariants<Bool> = .init(defaultVariantValue: false),
        externalIDVariants: DocumentationDataVariants<String>,
        accessLevelVariants: DocumentationDataVariants<String>,
        availabilityVariants: DocumentationDataVariants<SymbolGraph.Symbol.Availability>,
        deprecatedSummaryVariants: DocumentationDataVariants<DeprecatedSection>,
        mixinsVariants: DocumentationDataVariants<[String: Mixin]>,
        declarationVariants: DocumentationDataVariants<[[PlatformName?]: SymbolGraph.Symbol.DeclarationFragments]> = .init(defaultVariantValue: [:]),
        defaultImplementationsVariants: DocumentationDataVariants<DefaultImplementationsSection> = .init(defaultVariantValue: .init()),
        relationshipsVariants: DocumentationDataVariants<RelationshipsSection> = .init(),
        abstractSectionVariants: DocumentationDataVariants<AbstractSection>,
        discussionVariants: DocumentationDataVariants<DiscussionSection>,
        topicsVariants: DocumentationDataVariants<TopicsSection>,
        seeAlsoVariants: DocumentationDataVariants<SeeAlsoSection>,
        returnsSectionVariants: DocumentationDataVariants<ReturnsSection>,
        parametersSectionVariants: DocumentationDataVariants<ParametersSection>,
        redirectsVariants: DocumentationDataVariants<[Redirect]>,
        crossImportOverlayModule: (declaringModule: String, bystanderModules: [String])? = nil,
        originVariants: DocumentationDataVariants<SymbolGraph.Relationship.SourceOrigin> = .init(),
        automaticTaskGroupsVariants: DocumentationDataVariants<[AutomaticTaskGroupSection]> = .init(defaultVariantValue: [])
    ) {
        self.kindVariants = kindVariants
        self.titleVariants = titleVariants
        self.subHeadingVariants = subHeadingVariants
        self.navigatorVariants = navigatorVariants
        self.roleHeadingVariants = roleHeadingVariants
        self.platformNameVariants = platformNameVariants
        self.moduleReference = moduleReference
        self.crossImportOverlayModule = crossImportOverlayModule
        self.isRequiredVariants = requiredVariants
        self.externalIDVariants = externalIDVariants
        self.accessLevelVariants = accessLevelVariants
        self.availabilityVariants = availabilityVariants
        
        for (trait, variant) in availabilityVariants.allValues {
            self.isDeprecatedVariants[trait] = AvailabilityParser(variant).isDeprecated()
        }
        
        self.deprecatedSummaryVariants = deprecatedSummaryVariants
        self.declarationVariants = declarationVariants
        
        self.mixinsVariants = mixinsVariants
        
        for (trait, variant) in mixinsVariants.allValues {
            for item in variant.values {
                switch item {
                case let declaration as SymbolGraph.Symbol.DeclarationFragments:
                    // If declaration wasn't set explicitly use the one from the mixins.
                    if !self.declarationVariants.hasVariant(for: trait) {
                        self.declarationVariants[trait] = [[platformNameVariants[trait]]: declaration]
                    }
                case let extensionConstraints as SymbolGraph.Symbol.Swift.Extension where !extensionConstraints.constraints.isEmpty:
                    self.constraintsVariants[trait] = extensionConstraints.constraints
                case let location as SymbolGraph.Symbol.Location:
                    self.locationVariants[trait] = location
                case let spi as SymbolGraph.Symbol.SPI:
                    self.isSPIVariants[trait] = spi.isSPI
                default: break;
                }
            }
        }
        
        if !relationshipsVariants.isEmpty {
            self.relationshipsVariants = relationshipsVariants
        }
        
        self.defaultImplementationsVariants = defaultImplementationsVariants
        
        self.abstractSectionVariants = abstractSectionVariants
        self.discussionVariants = discussionVariants
        self.topicsVariants = topicsVariants
        self.seeAlsoVariants = seeAlsoVariants
        self.returnsSectionVariants = returnsSectionVariants
        self.parametersSectionVariants = parametersSectionVariants
        self.redirectsVariants = redirectsVariants
        self.originVariants = originVariants
        self.automaticTaskGroupsVariants = automaticTaskGroupsVariants
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
    /// depending on variances in their implementation across platforms (e.g. use `NSPoint` vs `CGPoint` parameter in a method).
    /// This method finds matching symbols between graphs and merges their declarations in case there are differences.
    func mergeDeclaration(mergingDeclaration: SymbolGraph.Symbol.DeclarationFragments, identifier: String, symbolAvailability: SymbolGraph.Symbol.Availability?, selector: UnifiedSymbolGraph.Selector) throws {
        let trait = DocumentationDataVariantsTrait(for: selector)
        let platformName = selector.platform

        if let platformName = platformName,
            let existingKey = declarationVariants[trait]?.first(
                where: { pair in
                    return pair.value.declarationFragments == mergingDeclaration.declarationFragments
                }
            )?.key
        {
            guard !existingKey.contains(nil) else {
                throw DocumentationContext.ContextError.unexpectedEmptyPlatformName(identifier)
            }

            let platform = PlatformName(operatingSystemName: platformName)
            if !existingKey.contains(platform) {
                // Matches one of the existing declarations, append to the existing key.
                let currentDeclaration = declarationVariants[trait]?.removeValue(forKey: existingKey)!
                declarationVariants[trait]?[existingKey + [platform]] = currentDeclaration
            }
        } else {
            // Add new declaration
            if let name = platformName {
                declarationVariants[trait]?[[PlatformName.init(operatingSystemName: name)]] = mergingDeclaration
            } else {
                declarationVariants[trait]?[[nil]] = mergingDeclaration
            }
        }

        // Merge the new symbol with the existing availability. If a value already exist, only override if it's for this platform.
        if let symbolAvailability = symbolAvailability,
            symbolAvailability.availability.isEmpty == false || availabilityVariants[trait]?.availability.isEmpty == false // Nothing to merge if both are empty
        {
            var items = availabilityVariants[trait]?.availability ?? []

            // Add all the domains that don't already have availability information
            for availability in symbolAvailability.availability {
                guard !items.contains(where: { $0.domain?.rawValue == availability.domain?.rawValue }) else { continue }
                items.append(availability)
            }

            // Override the availability for all domains that apply to this platform
            if let modulePlatformName = platformName.map(PlatformName.init) {
                let symbolAvailabilityForPlatform = symbolAvailability.filterItems(thatApplyTo: modulePlatformName)

                for availability in symbolAvailabilityForPlatform.availability {
                    items.removeAll(where: { $0.domain?.rawValue == availability.domain?.rawValue })
                    items.append(availability)
                }
            }

            availabilityVariants[trait] = SymbolGraph.Symbol.Availability(availability: items)
        }
    }

    func mergeDeclarations(unifiedSymbol: UnifiedSymbolGraph.Symbol) throws {
        for (selector, mixins) in unifiedSymbol.mixins {
            if let mergingDeclaration = mixins[SymbolGraph.Symbol.DeclarationFragments.mixinKey] as? SymbolGraph.Symbol.DeclarationFragments {
                let availability = mixins[SymbolGraph.Symbol.Availability.mixinKey] as? SymbolGraph.Symbol.Availability

                try mergeDeclaration(mergingDeclaration: mergingDeclaration, identifier: unifiedSymbol.uniqueIdentifier, symbolAvailability: availability, selector: selector)
            }
        }
    }
}

extension Dictionary where Key == String, Value == Mixin {
    func getValueIfPresent<T>(for mixinType: T.Type) -> T? where T: Mixin {
        return self[mixinType.mixinKey] as? T
    }
}

// MARK: Accessors for the first variant of symbol properties.

extension Symbol {
    /// The kind of the first variant of this symbol, such as protocol or variable.
    public var kind: SymbolGraph.Symbol.Kind { kindVariants.firstValue! }
    
    /// The title of the first variant of this symbol, usually a simplified version of the declaration.
    public var title: String { titleVariants.firstValue! }
    
    /// The simplified version of the first variant of this symbol's declaration to use inside groups that may contain multiple links.
    public var subHeading: [SymbolGraph.Symbol.DeclarationFragments.Fragment]? { subHeadingVariants.firstValue }
    
    /// The simplified version of the first variant of this symbol's declaration to use in navigation UI.
    public var navigator: [SymbolGraph.Symbol.DeclarationFragments.Fragment]? { navigatorVariants.firstValue }
    
    /// The presentation-friendly version of the first variant of the symbol's kind.
    public var roleHeading: String { roleHeadingVariants.firstValue! }
    
    /// The first variant of the symbol's platform, if available.
    public var platformName: PlatformName? { platformNameVariants.firstValue }
    
    /// Whether the first variant of the symbol is required in its context.
    public var isRequired: Bool {
        get { isRequiredVariants.firstValue! }
        set { isRequiredVariants.firstValue = newValue }
    }
    /// The first variant of the symbol's external identifier, if available.
    public var externalID: String? {
        get { externalIDVariants.firstValue }
        set { externalIDVariants.firstValue = nil }
    }
    
    /// The first variant of the symbol's deprecation information, if deprecated.
    public var deprecatedSummary: DeprecatedSection? {
        get { deprecatedSummaryVariants.firstValue }
        set { deprecatedSummaryVariants.firstValue = newValue }
    }
    
    /// The first variant of the symbol's declarations.
    public var declaration: [[PlatformName?]: SymbolGraph.Symbol.DeclarationFragments] {
        get { declarationVariants.firstValue! }
        set { declarationVariants.firstValue = newValue }
    }
    
    /// The place where the first variant of the symbol was originally declared in a source file.
    public var location: SymbolGraph.Symbol.Location? {
        get { locationVariants.firstValue }
        set { locationVariants.firstValue = newValue }
    }
    
    /// The first variant of the symbol's availability or conformance constraints.
    public var constraints: [SymbolGraph.Symbol.Swift.GenericConstraint]? {
        get { constraintsVariants.firstValue }
        set { constraintsVariants.firstValue = newValue }
    }
    
    /// The inheritance information for the first variant of the symbol.
    public var origin: SymbolGraph.Relationship.SourceOrigin? {
        get { originVariants.firstValue }
        set { originVariants.firstValue = newValue }
    }
    
    /// The platforms on which the first variant of the symbol is available.
    /// - note: Updating this property recalculates `isDeprecated`.
    public var availability: SymbolGraph.Symbol.Availability? {
        get { availabilityVariants.firstValue }
        set { availabilityVariants.firstValue = newValue }
    }

    /// The presentation-friendly relationships of the first variant of this symbol to other symbols.
    public var relationships: RelationshipsSection {
        get { relationshipsVariants.firstValue! }
        set { relationshipsVariants.firstValue = newValue }
    }
    
    /// The first variant of the symbol's access level, if available.
    public var accessLevel: String? {
        get { accessLevelVariants.firstValue }
        set { accessLevelVariants.firstValue = newValue }
    }
    
    /// An optional discussion for the first variant of the symbol.
    public var discussion: DiscussionSection? {
        get { discussionVariants.firstValue }
        set { discussionVariants.firstValue = newValue }
    }
    
    /// An optional, abstract summary for the first variant of the symbol.
    public var abstractSection: AbstractSection? {
        get { abstractSectionVariants.firstValue }
        set { abstractSectionVariants.firstValue = newValue }
    }
    
    /// The topics task groups for the first variant of the symbol.
    public var topics: TopicsSection? {
        get { topicsVariants.firstValue }
        set { topicsVariants.firstValue = newValue }
    }
    
    /// Any default implementations of the first variant of the symbol, if the symbol is a protocol requirement.
    public var defaultImplementations: DefaultImplementationsSection {
        get { defaultImplementationsVariants.firstValue! }
        set { defaultImplementationsVariants.firstValue = newValue }
    }
    
    /// Any See Also groups of the first variant of the symbol.
    public var seeAlso: SeeAlsoSection? {
        get { seeAlsoVariants.firstValue }
        set { seeAlsoVariants.firstValue = newValue }
    }
    
    /// Any redirect information of the first variant of the symbol, if the symbol has been moved from another location.
    public var redirects: [Redirect]? {
        get { redirectsVariants.firstValue }
        set { redirectsVariants.firstValue = newValue }
    }
    
    /// Any return value information of the first variant of the symbol, if the symbol returns.
    public var returnsSection: ReturnsSection? {
        get { returnsSectionVariants.firstValue }
        set { returnsSectionVariants.firstValue = newValue }
    }
    
    /// Any parameters of the first variant of the symbol, if the symbol accepts parameters.
    public var parametersSection: ParametersSection? {
        get { parametersSectionVariants.firstValue }
        set { parametersSectionVariants.firstValue = newValue }
    }
    
    /// The first variant of the symbol's abstract summary as a single paragraph.
    public var abstract: Paragraph? {
        abstractVariants.firstValue
    }
    
    /// Whether the first variant of the symbol is deprecated.
    public var isDeprecated: Bool {
        get { isDeprecatedVariants.firstValue! }
        set { isDeprecatedVariants.firstValue = newValue }
    }
    
    /// Whether the first variant of the symbol is declared as an SPI.
    public var isSPI: Bool {
        get { isSPIVariants.firstValue! }
        set { isSPIVariants.firstValue = newValue }
    }
    
    /// The mixins of the first variant of the symbol.
    var mixins: [String: Mixin]? {
        get { mixinsVariants.firstValue }
        set { mixinsVariants.firstValue = newValue }
    }
    
    /// Any automatically created task groups of the first variant of the symbol.
    var automaticTaskGroups: [AutomaticTaskGroupSection] {
        get { automaticTaskGroupsVariants.firstValue! }
        set { automaticTaskGroupsVariants.firstValue = newValue }
    }
}
