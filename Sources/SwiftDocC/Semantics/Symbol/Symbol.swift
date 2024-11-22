/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
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
/// - ``extendedModuleVariants``
/// - ``isRequiredVariants``
/// - ``externalIDVariants``
/// - ``accessLevelVariants``
/// - ``deprecatedSummaryVariants``
/// - ``declarationVariants``
/// - ``attributesVariants``
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
/// - ``dictionaryKeysSectionVariants``
/// - ``possibleValuesSectionVariants``
/// - ``httpEndpointSectionVariants``
/// - ``httpParametersSectionVariants``
/// - ``httpResponsesSectionVariants``
/// - ``httpBodySectionVariants``
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

    /// The name of the module extension in which the symbol is defined, in each language variant the symbol is available in
    public var extendedModuleVariants: DocumentationDataVariants<String> {
        var variants = DocumentationDataVariants<String>()
        for (trait, swiftExtension) in swiftExtensionVariants() {
            variants[trait] = swiftExtension.extendedModule
        }
        return variants
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

    /// The symbol's alternate declarations in each language variant the symbol is available in.
    public var alternateDeclarationVariants = DocumentationDataVariants<[[PlatformName?]: [SymbolGraph.Symbol.DeclarationFragments]]>()

    /// The symbol's alternate function signature in each language variant the symbol is available in.
    public var alternateSignatureVariants = DocumentationDataVariants<[[PlatformName?]: [SymbolGraph.Symbol.FunctionSignature]]>()

    /// The symbol's set of attributes in each language variant the symbol is available in.
    public var attributesVariants = DocumentationDataVariants<[RenderAttribute.Kind: Any]>()
    
    public var locationVariants = DocumentationDataVariants<SymbolGraph.Symbol.Location>()

    /// The symbol's availability or conformance constraints, in each language variant the symbol is available in.
    public var constraintsVariants: DocumentationDataVariants<[SymbolGraph.Symbol.Swift.GenericConstraint]> {
        var variants = DocumentationDataVariants<[SymbolGraph.Symbol.Swift.GenericConstraint]>()
        for (trait, swiftExtension) in swiftExtensionVariants() {
            variants[trait] = swiftExtension.constraints
        }
        return variants
    }

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
    
    /// Any dictionary keys of the symbol, if the symbol accepts keys.
    public var dictionaryKeysSection: DictionaryKeysSection?
    @available(*, deprecated, renamed: "dictionaryKeysSection", message: "Use 'dictionaryKeysSection' instead. This deprecated API will be removed after 6.2 is released")
    public var dictionaryKeysSectionVariants: DocumentationDataVariants<DictionaryKeysSection> {
        get { .init(defaultVariantValue: dictionaryKeysSection) }
        set { dictionaryKeysSection = newValue.firstValue }
    }
    
    /// The symbol's possible values, if the symbol is a property list element with possible values.
    public var possibleValuesSection: PropertyListPossibleValuesSection?
    @available(*, deprecated, renamed: "possibleValuesSection", message: "Use 'possibleValuesSection' instead. This deprecated API will be removed after 6.2 is released")
    public var possibleValuesSectionVariants: DocumentationDataVariants<PropertyListPossibleValuesSection> {
        get { .init(defaultVariantValue: possibleValuesSection) }
        set { possibleValuesSection = newValue.firstValue }
    }

    /// The HTTP endpoint of an HTTP request.
    public var httpEndpointSection: HTTPEndpointSection?
    @available(*, deprecated, renamed: "httpEndpointSection", message: "Use 'httpEndpointSection' instead. This deprecated API will be removed after 6.2 is released")
    public var httpEndpointSectionVariants: DocumentationDataVariants<HTTPEndpointSection> {
        get { .init(defaultVariantValue: httpEndpointSection) }
        set { httpEndpointSection = newValue.firstValue }
    }

    /// The upload body of an HTTP request.
    public var httpBodySection: HTTPBodySection?
    @available(*, deprecated, renamed: "httpBodySection", message: "Use 'httpBodySection' instead. This deprecated API will be removed after 6.2 is released")
    public var httpBodySectionVariants: DocumentationDataVariants<HTTPBodySection> {
        get { .init(defaultVariantValue: httpBodySection) }
        set { httpBodySection = newValue.firstValue }
    }

    /// The parameters of an HTTP request.
    public var httpParametersSection: HTTPParametersSection?
    @available(*, deprecated, renamed: "httpParametersSection", message: "Use 'httpParametersSection' instead. This deprecated API will be removed after 6.2 is released")
    public var httpParametersSectionVariants: DocumentationDataVariants<HTTPParametersSection> {
        get { .init(defaultVariantValue: httpParametersSection) }
        set { httpParametersSection = newValue.firstValue }
    }

    /// The responses of an HTTP request.
    public var httpResponsesSection: HTTPResponsesSection?
    @available(*, deprecated, renamed: "httpResponsesSection", message: "Use 'httpResponsesSection' instead. This deprecated API will be removed after 6.2 is released")
    public var httpResponsesSectionVariants: DocumentationDataVariants<HTTPResponsesSection> {
        get { .init(defaultVariantValue: httpResponsesSection) }
        set { httpResponsesSection = newValue.firstValue }
    }
    
    /// Any redirect information of the symbol, if the symbol has been moved from another location.
    public var redirects: [Redirect]?
    @available(*, deprecated, renamed: "redirects", message: "Use 'redirects' instead. This deprecated API will be removed after 6.2 is released")
    public var redirectsVariants: DocumentationDataVariants<[Redirect]> {
        get { .init(defaultVariantValue: redirects) }
        set { redirects = newValue.firstValue }
    }
    
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
    
    struct Overloads {
         /// References to other symbols that overload this one.
         let references: [ResolvedTopicReference]
         /// The index where this symbol's should be displayed (inserted) among the overloads declarations.
         let displayIndex: Int
    }
    
    /// References to other symbols that overload this one.
    var overloadsVariants: DocumentationDataVariants<Overloads>

    /// Creates a new symbol with the given data.
    init(
        kindVariants: DocumentationDataVariants<SymbolGraph.Symbol.Kind>,
        titleVariants: DocumentationDataVariants<String>,
        subHeadingVariants: DocumentationDataVariants<[SymbolGraph.Symbol.DeclarationFragments.Fragment]>,
        navigatorVariants: DocumentationDataVariants<[SymbolGraph.Symbol.DeclarationFragments.Fragment]>,
        roleHeadingVariants: DocumentationDataVariants<String>,
        platformNameVariants: DocumentationDataVariants<PlatformName>,
        moduleReference: ResolvedTopicReference,
        requiredVariants: DocumentationDataVariants<Bool> = .init(defaultVariantValue: false),
        externalIDVariants: DocumentationDataVariants<String>,
        accessLevelVariants: DocumentationDataVariants<String>,
        availabilityVariants: DocumentationDataVariants<SymbolGraph.Symbol.Availability>,
        deprecatedSummaryVariants: DocumentationDataVariants<DeprecatedSection>,
        mixinsVariants: DocumentationDataVariants<[String: Mixin]>,
        declarationVariants: DocumentationDataVariants<[[PlatformName?]: SymbolGraph.Symbol.DeclarationFragments]> = .init(defaultVariantValue: [:]),
        alternateDeclarationVariants: DocumentationDataVariants<[[PlatformName?]: [SymbolGraph.Symbol.DeclarationFragments]]> = .init(defaultVariantValue: [:]),
        alternateSignatureVariants: DocumentationDataVariants<[[PlatformName?]: [SymbolGraph.Symbol.FunctionSignature]]> = .init(defaultVariantValue: [:]),
        defaultImplementationsVariants: DocumentationDataVariants<DefaultImplementationsSection> = .init(defaultVariantValue: .init()),
        relationshipsVariants: DocumentationDataVariants<RelationshipsSection> = .init(),
        abstractSectionVariants: DocumentationDataVariants<AbstractSection>,
        discussionVariants: DocumentationDataVariants<DiscussionSection>,
        topicsVariants: DocumentationDataVariants<TopicsSection>,
        seeAlsoVariants: DocumentationDataVariants<SeeAlsoSection>,
        returnsSectionVariants: DocumentationDataVariants<ReturnsSection>,
        parametersSectionVariants: DocumentationDataVariants<ParametersSection>,
        dictionaryKeysSection: DictionaryKeysSection?,
        possibleValuesSection: PropertyListPossibleValuesSection?,
        httpEndpointSection: HTTPEndpointSection?,
        httpBodySection: HTTPBodySection?,
        httpParametersSection: HTTPParametersSection?,
        httpResponsesSection: HTTPResponsesSection?,
        redirects: [Redirect]?,
        crossImportOverlayModule: (declaringModule: String, bystanderModules: [String])? = nil,
        originVariants: DocumentationDataVariants<SymbolGraph.Relationship.SourceOrigin> = .init(),
        automaticTaskGroupsVariants: DocumentationDataVariants<[AutomaticTaskGroupSection]> = .init(defaultVariantValue: []),
        overloadsVariants: DocumentationDataVariants<Overloads> = .init(defaultVariantValue: nil)
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
        self.possibleValuesSection = possibleValuesSection
        self.alternateDeclarationVariants = alternateDeclarationVariants
        self.alternateSignatureVariants = alternateSignatureVariants
        
        self.mixinsVariants = mixinsVariants
        
        for (trait, variant) in mixinsVariants.allValues {
            var attributes: [RenderAttribute.Kind: Any] = [:]
            for item in variant.values {
                switch item {
                case let declaration as SymbolGraph.Symbol.DeclarationFragments:
                    // If declaration wasn't set explicitly use the one from the mixins.
                    if !self.declarationVariants.hasVariant(for: trait) {
                        self.declarationVariants[trait] = [[platformNameVariants[trait]]: declaration]
                    }
                case let location as SymbolGraph.Symbol.Location:
                    self.locationVariants[trait] = location
                case let spi as SymbolGraph.Symbol.SPI:
                    self.isSPIVariants[trait] = spi.isSPI
                case let alternateSymbols as SymbolGraph.Symbol.AlternateSymbols:
                    // If alternate declarations weren't set explicitly use the ones from the mixins.
                    if !self.alternateDeclarationVariants.hasVariant(for: trait) {
                        let alternateDeclarations = alternateSymbols.alternateSymbols.compactMap(\.declarationFragments)
                        self.alternateDeclarationVariants[trait] = [[platformNameVariants[trait]]: alternateDeclarations]
                    }
                    if !self.alternateSignatureVariants.hasVariant(for: trait) {
                        let alternateSignatures = alternateSymbols.alternateSymbols.compactMap(\.functionSignature)
                        self.alternateSignatureVariants[trait] = [[platformNameVariants[trait]]: alternateSignatures]
                    }
                case let attribute as SymbolGraph.Symbol.Minimum:
                    attributes[.minimum] = attribute.value
                case let attribute as SymbolGraph.Symbol.Maximum:
                    attributes[.maximum] = attribute.value
                case let attribute as SymbolGraph.Symbol.MinimumExclusive:
                    attributes[.minimumExclusive] = attribute.value
                case let attribute as SymbolGraph.Symbol.MaximumExclusive:
                    attributes[.maximumExclusive] = attribute.value
                case let attribute as SymbolGraph.Symbol.MinimumLength:
                    attributes[.minimumLength] = attribute.value
                case let attribute as SymbolGraph.Symbol.MaximumLength:
                    attributes[.maximumLength] = attribute.value
                case let attribute as SymbolGraph.Symbol.DefaultValue:
                    attributes[.default] = attribute.value
                
                case let attribute as SymbolGraph.Symbol.TypeDetails:
                    attributes[.allowedTypes] = attribute.value
                default: break;
                }
            }
            if !attributes.isEmpty {
                self.attributesVariants[trait] = attributes
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
        self.dictionaryKeysSection = dictionaryKeysSection
        self.httpEndpointSection = httpEndpointSection
        self.httpBodySection = httpBodySection
        self.httpParametersSection = httpParametersSection
        self.httpResponsesSection = httpResponsesSection
        self.redirects = redirects
        self.originVariants = originVariants
        self.automaticTaskGroupsVariants = automaticTaskGroupsVariants
        self.overloadsVariants = overloadsVariants
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitSymbol(self)
    }

    /// Append a new generic constraint for the given extended module
    /// - Parameters:
    ///    - extendedModule: The name of the extended module.
    ///    - extendedSymbolKind: The kind of the extended symbol.
    ///    - newConstraint: The new generic constraints to add.
    public func addSwiftExtensionConstraint(
        extendedModule: String,
        extendedSymbolKind: SymbolGraph.Symbol.KindIdentifier? = nil,
        constraint newConstraint: SymbolGraph.Symbol.Swift.GenericConstraint
    ) {

        var swiftExtension: SymbolGraph.Symbol.Swift.Extension

        // Does this symbol already have a swift extension variant for the swift trait?

        // Yes: Create a new copy of the existing extension with
        // the new constraint appended to the existing list
        let trait = DocumentationDataVariantsTrait.swift
        if let existing = swiftExtensionVariants()[trait] {
            // Double check the existing extension uses the same module and type. If it does not,
            // we must have a tooling or data consistency problem.
            assert(
                existing.extendedModule == extendedModule && existing.typeKind == extendedSymbolKind,
                "New constraint's module and type kind do not match symbol's existing constraints."
            )
            swiftExtension = existing
            swiftExtension.constraints = swiftExtension.constraints + [newConstraint]

        // No: Create a new extension with the specified module, type and
        // new constraint
        } else {
            swiftExtension = SymbolGraph.Symbol.Swift.Extension(
                                extendedModule: extendedModule,
                                typeKind: extendedSymbolKind,
                                constraints: [newConstraint]
                             )
        }

        // Save the new or updated extension
        self.mixinsVariants[
                trait,
                default: [:]
            ][SymbolGraph.Symbol.Swift.Extension.mixinKey] = swiftExtension
    }

    // MARK: - Private helpers

    /// Return all of this symbol's Swift extension variants.
    private func swiftExtensionVariants() -> [DocumentationDataVariantsTrait : SymbolGraph.Symbol.Swift.Extension] {
        var variants: [DocumentationDataVariantsTrait : SymbolGraph.Symbol.Swift.Extension] = [:]
        for (trait, mixins) in mixinsVariants.allValues {
            if let swiftExtension = mixins[SymbolGraph.Symbol.Swift.Extension.mixinKey] as? SymbolGraph.Symbol.Swift.Extension {
                variants[trait] = swiftExtension
            }
        }
        return variants
    }
}

extension Symbol {
    
    /// Merges a symbol declaration from another symbol graph into the current symbol.
    ///
    /// When building multi-platform documentation symbols might have more than one declaration
    /// depending on variances in their implementation across platforms (e.g. use `NSPoint` vs `CGPoint` parameter in a method).
    /// This method finds matching symbols between graphs and merges their declarations in case there are differences.
    func mergeDeclaration(mergingDeclaration: SymbolGraph.Symbol.DeclarationFragments, identifier: String, symbolAvailability: SymbolGraph.Symbol.Availability?, alternateSymbols: SymbolGraph.Symbol.AlternateSymbols?, selector: UnifiedSymbolGraph.Selector) throws {
        let trait = DocumentationDataVariantsTrait(for: selector)
        let platformName = selector.platform

        func merge<Value: Equatable>(
            _ mergingValue: Value,
            into variants: inout DocumentationDataVariants<[[PlatformName?] : Value]>
        ) throws {
            guard let platformName else {
                variants[trait]?[[nil]] = mergingValue
                return
            }
            let platform = PlatformName(operatingSystemName: platformName)
            
            guard let (existingKey, currentValue) = variants[trait]?.first(where: { _, value in value == mergingValue }) else {
                variants[trait]?[[platform]] = mergingValue
                return
            }
            
            guard !existingKey.contains(nil) else {
                throw DocumentationContext.ContextError.unexpectedEmptyPlatformName(identifier)
            }
            
            guard !existingKey.contains(platform) else {
                // No need to update the existing value
                return
            }
            
            let newKey = existingKey + [platform]
            guard variants[trait]?.keys.contains(newKey) == false else {
                // Don't override the existing value
                return
            }
            
            // Add the new platform to the existing value
            _ = variants[trait]?.removeValue(forKey: existingKey)
            variants[trait]?[newKey] = currentValue
        }
        
        try merge(mergingDeclaration, into: &declarationVariants)
        
        if let alternateSymbols {
            let mergingAlternateDeclarations = alternateSymbols.alternateSymbols.compactMap(\.declarationFragments)
            if !mergingAlternateDeclarations.isEmpty {
                try merge(mergingAlternateDeclarations, into: &alternateDeclarationVariants)
            }
            
            let mergingAlternateSignatures = alternateSymbols.alternateSymbols.compactMap(\.functionSignature)
            if !mergingAlternateSignatures.isEmpty {
                try merge(mergingAlternateSignatures, into: &alternateSignatureVariants)
            }
        }

        // Merge the new symbol with the existing availability. If a value already exist, only override if it's for this platform.
        if let symbolAvailability,
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
                let alternateSymbols = mixins[SymbolGraph.Symbol.AlternateSymbols.mixinKey] as? SymbolGraph.Symbol.AlternateSymbols

                try mergeDeclaration(mergingDeclaration: mergingDeclaration, identifier: unifiedSymbol.uniqueIdentifier, symbolAvailability: availability, alternateSymbols: alternateSymbols, selector: selector)
            }
        }
    }
    
    /// Merge the different availability variants defined in the unified symbol,
    /// and update the availability of the canonical symbol to consider all the different availability mixins instead of only the first one.
    func mergeAvailabilities(unifiedSymbol: UnifiedSymbolGraph.Symbol) {
        for (selector, mixins) in unifiedSymbol.mixins {
            let trait = DocumentationDataVariantsTrait(for: selector)
            if let unifiedSymbolAvailability = mixins[SymbolGraph.Symbol.Availability.mixinKey] as? SymbolGraph.Symbol.Availability {
                unifiedSymbolAvailability.availability.forEach { availabilityItem in
                    guard let availabilityVariantTrait = availabilityVariants[trait] else { return }
                    if (availabilityVariantTrait.availability.contains(where: { $0.domain?.rawValue == availabilityItem.domain?.rawValue })) {
                        return
                    }
                    availabilityVariants[trait]?.availability.append(availabilityItem)
                }
            }
        }
    }
}

extension [String: Mixin] {
    func getValueIfPresent<T>(for mixinType: T.Type) -> T? where T: Mixin {
        return self[mixinType.mixinKey] as? T
    }
}

// MARK: Accessors for the first variant of symbol properties.

// Extend the Symbol class to account for legacy code that didn't account for symbols having multiple
// language representations. New code should be written to work with the variants so that it supports
// language specific content.

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
    public var constraints: [SymbolGraph.Symbol.Swift.GenericConstraint]? { constraintsVariants.firstValue }
    
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

    // Don't add additional functions here. See the comment above about legacy code.
}

// Use fully-qualified types below to silence a warning about retroactively conforming a type from another module to a new protocol (SE-0364).
// The `@retroactive` attribute is new in the Swift 6 compiler. The backwards compatible syntax for a retroactive conformance is fully-qualified types.
//
// If SymbolKit adds Equatable conformance it's reasonable to expect that its behavior would be compatible.
extension SymbolKit.SymbolGraph.Symbol.DeclarationFragments: Swift.Equatable {
    // Extension outside of declaring module can't synthesize equatable implementation
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.declarationFragments == rhs.declarationFragments
    }
}

extension SymbolKit.SymbolGraph.Symbol.FunctionSignature: Swift.Equatable {
    // Extension outside of declaring module can't synthesize equatable implementation
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.parameters == rhs.parameters &&
        lhs.returns    == rhs.returns
    }
}

extension SymbolKit.SymbolGraph.Symbol.FunctionSignature.FunctionParameter: Swift.Equatable {
    // Extension outside of declaring module can't synthesize equatable implementation
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name                 == rhs.name                 &&
        lhs.externalName         == rhs.externalName         &&
        lhs.declarationFragments == rhs.declarationFragments &&
        lhs.children             == rhs.children
    }
}
