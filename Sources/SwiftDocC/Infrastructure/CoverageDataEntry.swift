/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// `CoverageDataEntry` represents coverage data for one symbol/USR.
public struct CoverageDataEntry: CustomStringConvertible, Codable {
    internal init(
        title: String,
        usr: String,
        sourceLanguage: SourceLanguage,
        availableSourceLanguages: Set<SourceLanguage>,
        kind: DocumentationNode.Kind,
        hasAbstract: Bool,
        isCurated: Bool,
        hasCodeListing: Bool,
        availability: SymbolGraph.Symbol.Availability?,
        kindSpecificData: KindSpecificData?
    ) {
        self.title = title
        self.usr = usr
        self.sourceLanguage = sourceLanguage
        self.kind = kind
        self.hasAbstract = hasAbstract
        self.isCurated = isCurated
        self.hasCodeListing = hasCodeListing
        self.availability = availability
        self.kindSpecificData = kindSpecificData
        self.availableSourceLanguages = availableSourceLanguages
    }

    internal var title: String
    internal var usr: String

    internal var hasAbstract: Bool
    internal var isCurated: Bool
    internal var hasCodeListing: Bool

    internal var sourceLanguage: SourceLanguage
    // Not currently printed in console output
    internal var availableSourceLanguages: Set<SourceLanguage>

    internal var kind: DocumentationNode.Kind
    // Not currently printed in console output
    internal var availability: SymbolGraph.Symbol.Availability?
    internal var kindSpecificData: KindSpecificData?

    typealias ColumnDescription = (
        header: String, columnWidth: Int, printer: (CoverageDataEntry) -> String
    )

    /// This property represents formatting for detailed console output. For each field that we surface in the detailed console output, store 3 values.
    /// 1. The name to display as the header for the column
    /// 2. How wide the column should be
    /// 3. How to extract the data to display from a given instance.
    internal static let columnDescriptions: [ColumnDescription] = {

        let it: (CoverageDataEntry) -> String = {
            $0.kindSpecificData?.formattedParameterStats ?? "-"
        }
        return [
            ("Symbol Name", 30, \.title),
            ("Kind", 30, \.kind.name),
            ("Abstract?", 12, \.hasAbstract.description),
            ("Curated?", 12, \.isCurated.description),
            ("Code Listing?", 15, \.hasCodeListing.description),
            ("Parameters", 12, it),
            ("Language", 15, \.sourceLanguage.name),
            ("USR", 0, \.usr),
        ]

    }()

    /// Prints the header for detailed console output.
    internal static let detailTableHeader: String = {
        createFormattedTableRow(
            content: columnDescriptions.map {
                ($0.header, $0.columnWidth)
            },
            separator: "   "
        )
    }()

    /// This method represents what category this entry contributes to in the distilled overview.
    internal var summaryCategory: SummaryCategory? {
        return SummaryCategory(documentationNodeKind: kind)
    }

    public var description: String {
        createFormattedTableRow(
            content: CoverageDataEntry.columnDescriptions.map {
                ($0.printer(self), $0.columnWidth)
            },
            separator: " | "
        )
    }

    /// Outputs a short table summarizing the coverage statistics for a list of data entries.
    /// - Parameter coverageInfo: An array of entries to summarize.
    public static func generateSummary(
        of coverageInfo: [CoverageDataEntry],
        shouldGenerateBrief: Bool,
        shouldGenerateDetailed: Bool) -> String {

        var output = ""
        if shouldGenerateBrief {
            let split = coverageInfo.createDictionary(
                pathToKey: \.summaryCategory
            )

            let rows = [
                SummaryRow.summaryTableHeader,
                SummaryRow(
                    rowHeader: "Types",
                    data: split[.types] ?? []).description,
                SummaryRow(
                    rowHeader: "Members",
                    data: split[.members] ?? []).description,
                SummaryRow(
                    rowHeader: "Globals",
                    data: split[.globals] ?? []).description
            ]

            output.append("\(rows.joined(separator: "\n"))\n")
        }

        if shouldGenerateDetailed {
            if shouldGenerateBrief {
                output.append("\n\n")
            }

            // Print the header no matter what to signify beginning
            // of detailed output
            output.append(CoverageDataEntry.detailTableHeader)
            output.append("\n")

            // Either display rows or a message clarifying that there are no rows.
            if (coverageInfo.isEmpty) {
                output.append("--No Symbols to display--")
            } else {
                output.append(coverageInfo.map({ $0.description }).joined(separator: "\n"))
            }

            output.append("\n")
        }

        return output
    }
}

extension RenderNode {
    fileprivate var hasCodeListing: Bool {
        primaryContentSections.contains(where: { (renderSection) -> Bool in
            if let contentRenderSection = renderSection as? ContentRenderSection {
                return contentRenderSection.content.contains(where: { contentItem in
                    switch contentItem {
                    case .codeListing:
                        return true
                    default:
                        return false
                    }
                })
            } else {
                return false
            }
        })
    }
}

extension CoverageDataEntry {

    /// Inspects the given node in the given context to extract all necessary fields.
    /// - Parameters:
    ///   - documentationNode: A node from the given context to generate an entry from
    ///   - renderNode: A render node generated from the documentation node using the given context.
    ///   - context: A documentation context used to look up related symbols.
    /// - Throws: `CoverageDataEntry.Error`
    internal init(
        documentationNode: DocumentationNode,
        renderNode: RenderNode,
        context: DocumentationContext
    ) throws {
        let title = documentationNode.name

        let semanticSymbol = documentationNode.semantic as? Symbol
        let kind = documentationNode.kind
        let hasAbstract = semanticSymbol?.abstractSection != nil  // How should we this handle 'possible' failure?
        let isCurated =
            context.manuallyCuratedReferences?.contains(documentationNode.reference) ?? false
        let usr = renderNode.identifier.description
        let sourceLanguage = documentationNode.sourceLanguage
        let availableSourceLanguages = documentationNode.availableSourceLanguages
        let availability = semanticSymbol?.availability
        let hasCodeListing = renderNode.hasCodeListing

        self = try CoverageDataEntry(
            title: title.description,
            usr: usr,
            sourceLanguage: sourceLanguage,
            availableSourceLanguages: availableSourceLanguages,
            kind: kind,
            hasAbstract: hasAbstract,
            isCurated: isCurated,
            hasCodeListing: hasCodeListing,
            availability: availability,
            kindSpecificData: KindSpecificData(
                documentationNode: documentationNode,
                renderNode: renderNode,
                context: context
            )
        )
    }

    /// Top level grouping to use when printing a condensed detailing of coverage statistics.
    enum SummaryCategory: CaseIterable {
        case types
        case members
        case globals
        case nonSymbol
        case deprecated
        static let allKnownNonSymbolKindNames: [String] = {
            let allNonSymbolNames = DocumentationNode.Kind.allKnownValues.compactMap { kind in
                kind.isSymbol ? nil : kind.name
            }
            return allNonSymbolNames
        }()

        /// Inspects the given node kind and creates a grouping for the condensed summary.
        /// - Parameter documentationNodeKind: The documentation node to inspect
        init?(documentationNodeKind: DocumentationNode.Kind) {
            switch documentationNodeKind {
            case .class,
                .structure,
                .enumeration,
                .protocol,
                .typeAlias,
                .associatedType,
                .typeDef,
                .extendedClass,
                .extendedStructure,
                .extendedEnumeration,
                .extendedProtocol,
                .unknownExtendedType:
                self = .types
            case .localVariable,
                .instanceProperty,
                .initializer,
                .instanceMethod,
                .instanceVariable,
                .enumerationCase,
                .typeProperty,
                .typeMethod,
                .typeSubscript,
                .instanceSubscript:
                self = .members
            case .function, .module, .globalVariable, .operator, .extendedModule:
                self = .globals
            case let kind where SummaryCategory.allKnownNonSymbolKindNames.contains(kind.name):
                self = .nonSymbol
            default:
                return nil
            }
        }
    }
}

extension CoverageDataEntry {
    /// Contains information that is unique to specific symbol types.
    enum KindSpecificData: Equatable, Codable {
        case `class`(memberStats: [InstanceMemberType: RatioStatistic])
        case structure(memberStats: [InstanceMemberType: RatioStatistic])
        case enumeration(memberStats: [InstanceMemberType: RatioStatistic])
        case `protocol`(memberStats: [InstanceMemberType: RatioStatistic])
        case typeAlias
        case instanceProperty
        case instanceMethod(parameterStats: RatioStatistic)
        case initializer(parameterStats: RatioStatistic)
        case enumerationCase(parameterStats: RatioStatistic)
        case variable
        case function(parameterStats: RatioStatistic)
        case `operator`(parameterStats: RatioStatistic)
        case framework
        case article

        /// Inspects the given node in the given context to extract fields unique to the kind of (documentation) node provided.
        /// - Parameters:
        ///   - documentationNode: A node from the given context to extract kind specific data  from.
        ///   - renderNode: A render node generated from the documentation node using the given context.
        ///   - context: A documentation context used to look up related symbols.
        /// - Throws: `CoverageDataEntry.Error`
        init?(
            documentationNode: DocumentationNode,
            renderNode: RenderNode,
            context: DocumentationContext
        ) throws {
            switch documentationNode.kind {
            case .class, .extendedClass:
                self = try .class(
                    memberStats: KindSpecificData.extractChildStats(
                        documentationNode: documentationNode,
                        context: context))
            case .enumeration, .extendedEnumeration:
                self = try .enumeration(
                    memberStats: KindSpecificData.extractChildStats(
                        documentationNode: documentationNode,
                        context: context))
            case .structure, .extendedStructure:
                self = try .structure(
                    memberStats:  KindSpecificData.extractChildStats(
                        documentationNode: documentationNode,
                        context: context))
            case .protocol, .extendedProtocol:
                self = try .protocol(
                    memberStats: KindSpecificData.extractChildStats(
                        documentationNode: documentationNode,
                        context: context))

            case .instanceMethod:
                self = try .instanceMethod(
                    parameterStats: CoverageDataEntry.KindSpecificData.extractFunctionSignatureStats(
                        documentationNode: documentationNode,
                        context: context
                        , fieldName: "method parameters"))
            case .operator:
                self = try .`operator`(
                    parameterStats: CoverageDataEntry.KindSpecificData.extractFunctionSignatureStats(
                        documentationNode: documentationNode,
                        context: context,
                        fieldName: "operator parameters"))
            case .function:
                self = try .`operator`(
                    parameterStats: CoverageDataEntry.KindSpecificData.extractFunctionSignatureStats(
                        documentationNode: documentationNode,
                        context: context,
                        fieldName: "function parameters"))
            case .initializer:
                self = try .`operator`(
                    parameterStats: CoverageDataEntry.KindSpecificData.extractFunctionSignatureStats(
                        documentationNode: documentationNode,
                        context: context,
                        fieldName: "initializer arguments"))
            default:
                return nil
            }
        }



        static func extractChildStats(
            documentationNode: DocumentationNode,
            context: DocumentationContext) throws -> [InstanceMemberType: RatioStatistic] {

            func _getStats(
                kind: DocumentationNode.Kind?
            ) throws -> RatioStatistic? {
                let children = context.children(
                    of: documentationNode.reference,
                    kind: kind
                )
                let total = children.count
                let documented = children.filter {
                    (context.symbolIndex[$0.reference.description]?.semantic as? Symbol)?
                        .abstractSection
                        != nil
                }.count

                if total == 0 {
                    return nil
                } else {
                    return try RatioStatistic(
                        documented: documented,
                        total: total)
                }
            }


            var dictionary: [InstanceMemberType: RatioStatistic] = [:]

            dictionary[.all] = try _getStats(kind: nil)
            dictionary[.enumCase] = try _getStats(kind: .enumerationCase)
            dictionary[.method] = try _getStats(kind: .instanceMethod)
            dictionary[.property] = try _getStats(kind: .instanceProperty)
            dictionary[.typeAlias] = try _getStats(kind: .typeAlias)

            return dictionary
        }

        static func extractFunctionSignatureStats(
            documentationNode: DocumentationNode,
            context: DocumentationContext,
            fieldName: String) throws -> RatioStatistic {
            guard let symbolGraphSymbol = documentationNode.symbol else {
                throw CoverageDataEntry.Error.failedConversion(
                    description:
                        "Failed to get backing SymbolGraph.Symbol for `\(documentationNode)`")
            }



            let funcSignatureMixinKey = SymbolGraph.Symbol.FunctionSignature.mixinKey
            guard
                let functionSignature = symbolGraphSymbol.mixins[funcSignatureMixinKey]
                    as? SymbolGraph.Symbol.FunctionSignature
            else {
                return .zeroOverZero
            }
            guard let semanticSymbol = documentationNode.semantic as? Symbol else {
                throw CoverageDataEntry.Error.failedConversion(
                    description:
                        "Failed to get backing SwiftDocC.Symbol for `\(documentationNode)`"
                )
            }
            let documentedParameterCount =
                semanticSymbol.parametersSection?.parameters.count ?? 0

            let totalCount = functionSignature.parameters.count
            let statistic = try RatioStatistic.create(
                documentationNode: documentationNode,
                field: fieldName,
                documented: documentedParameterCount,
                total: totalCount
            )

            return statistic
        }
    }
}

extension CoverageDataEntry.KindSpecificData {
    private enum CodingKeys: String, CodingKey {
        case discriminant
        case associatedValue
    }

    /// A type mirroring all cases in `KindSpecificData` without any associated values. Primarily used for Coding/Decoding.
    internal enum Discriminant: String, Codable {
        case `class`
        case structure
        case enumeration
        case `protocol`
        case `operator`
        case typeAlias
        case instanceProperty
        case instanceMethod
        case initializer
        case enumerationCase
        case variable
        case function
        case framework
        case article


        /// For cases that have an associated type `RatioStatistic`, the appropriate initializer for that case on `KindSpecificData`
        /// - Throws: If the instance does not represent a case with associated type `RatioStatistic`
        /// - Returns: An closure that accepts an instance of `RatioStatistic` and returns an instance of `KindSpecificData`
        func associatedRatioStatisticInitializer() throws -> (RatioStatistic) -> CoverageDataEntry
            .KindSpecificData
        {
            switch self {
            case .instanceMethod:
                return CoverageDataEntry.KindSpecificData.instanceMethod(parameterStats:)
            case .initializer:
                return CoverageDataEntry.KindSpecificData.initializer(parameterStats:)
            case .enumerationCase:
                return CoverageDataEntry.KindSpecificData.enumerationCase(parameterStats:)
            case .function:
                return CoverageDataEntry.KindSpecificData.function(parameterStats:)
            case .operator:
                return CoverageDataEntry.KindSpecificData.`operator`(parameterStats:)
            case .class,
                 .`structure`,
                 .enumeration,
                .protocol,
                .typeAlias,
                .instanceProperty,
                .variable,
                .framework,
                .article:
                // This genuinely signals maintainer error.
                throw CoverageDataEntry.Error.serializationError(
                    description:
                        "While deserializing KindSpecificData, Attempting to deserialize RatioStatistic for a kind without RatioStatistic associated value."
                )
            }
        }

        /// For cases that have an associated type `[InstanceMemberType: RatioStatistic]`, the appropriate initializer for that case on `KindSpecificData`
        /// - Throws: If the instance does not represent a case with associated type `RatioStatistic`
        /// - Returns: An closure that accepts an instance of `[InstanceMemberType: RatioStatistic]` and returns an instance of `KindSpecificData`
        func associatedMemberStatisticsInitializer() throws -> ([InstanceMemberType: RatioStatistic]) -> CoverageDataEntry
            .KindSpecificData
        {
            switch self {
            case .`structure`:
                return CoverageDataEntry.KindSpecificData.structure(memberStats:)
            case .enumeration:
                return CoverageDataEntry.KindSpecificData.enumeration(memberStats:)
            case .protocol:
                return CoverageDataEntry.KindSpecificData.protocol(memberStats:)
            case .class:
                return CoverageDataEntry.KindSpecificData.class(memberStats:)
            case .instanceMethod,
                 .initializer,
                .typeAlias,
                .instanceProperty,
                .enumerationCase,
                .variable,
                .function,
                .framework,
                .article,
                .operator:
                // This genuinely signals maintainer error.
                throw CoverageDataEntry.Error.serializationError(
                    description:
                        "While deserializing KindSpecificData, Attempting to deserialize [InstanceMemberStats: RatioStatistic] for a kind without a matching associated value."
                )
            }
        }
    }

    /// Indicates the case of this instance (without an associated value.)
    var discriminant: Discriminant {
        switch self {
        case .class:
            return .class
        case .structure:
            return .`structure`
        case .enumeration:
            return .enumeration
        case .protocol:
            return .protocol
        case .typeAlias:
            return .typeAlias
        case .instanceProperty:
            return .instanceProperty
        case .instanceMethod:
            return .instanceMethod
        case .initializer:
            return .initializer
        case .enumerationCase:
            return .enumerationCase
        case .variable:
            return .variable
        case .function:
            return .function
        case .framework:
            return .framework
        case .article:
            return .article
        case .`operator`:
            return .operator
        }
    }

    /// If the symbol represented is an enum, statistics about which cases are documented, formatted for display in the console. `"(0/0)"` when there are no cases. `"-"` for other symbols
    var formattedCaseStats: String {
        switch self {
        case .enumeration(let memberStats):
            return (memberStats[.enumCase] ?? .zeroOverZero).description
        default:
            return "-"
        }
    }

    /// If the symbol represented is of a kind that accepts arguments, statistics about which arguments are documented, formatted for display in the console. `"(0/0)"` when there are no parameters. `"-"` for other symbols
    var formattedParameterStats: String {
        switch self {
        case .instanceMethod(let stats),
             .function(let stats),
             .initializer(let stats),
             .enumerationCase(let stats),
             .`operator`(let stats):
            return stats.description
        default:
            return "-"
        }
    }

    /// If the symbol represented can have members, statistics about which members are documented, formatted for display in the console. `"(0/0)"` when there are no members. `"-"` for other symbols
    var formattedMemberStats: String {
        switch self {
        case .enumeration(let memberStats),
             .structure(let memberStats),
             .class(let memberStats),
             .protocol(let memberStats):
            return (memberStats[.all] ?? .zeroOverZero).description
        default:
            return "-"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let discriminant = try container.decode(
            Discriminant.self,
            forKey: .discriminant
        )

        switch discriminant {
        case .initializer,
            .instanceMethod,
            .enumerationCase,
            .function,
            .operator:
            let associatedValue = try container.decode(
                RatioStatistic.self,
                forKey: .associatedValue
            )
            self = try discriminant.associatedRatioStatisticInitializer()(associatedValue)
        case .class,
             .`structure`,
             .enumeration,
            .protocol:
            let associatedValue = try container.decode(
                [InstanceMemberType: RatioStatistic].self,
                forKey: .associatedValue
            )
            self = try discriminant.associatedMemberStatisticsInitializer()(associatedValue)

        case .typeAlias:
            self = .typeAlias
        case .instanceProperty:
            self = .instanceProperty
        case .variable:
            self = .variable
        case .framework:
            self = .framework
        case .article:
            self = .article
        }

    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(discriminant, forKey: .discriminant)

        switch self {
        case .enumeration(let dictionary),
            .class(let dictionary),
            .structure(let dictionary),
            .protocol(let dictionary):
            try container.encode(dictionary, forKey: .associatedValue)
        case .instanceMethod(let stats),
            .function(let stats),
            .initializer(let stats),
            .enumerationCase(let stats),
            .`operator`(let stats):
            try container.encode(stats, forKey: .associatedValue)

        case .typeAlias,
             .instanceProperty,
             .variable,
             .framework,
             .article:
            break
        }
    }


    /// Represents the various kinds of instance members that types can have. Keys  used to retrieve statistics about the associated member kind.
    public enum InstanceMemberType: String, Hashable, Codable, CaseIterable {
        case enumCase
        case property
        case method
        case typeAlias
        case initializer
        case all
    }
}

/// Creates a string suitable for printing in console to present a table from the given data.
/// - Parameters:
///   - content: An array of 'cells' to present along with their column width.
///   - separator: The string to use as a separator between the given cells
/// - Returns: A single row of a table to print.
private func createFormattedTableRow(
    content: [(string: String, columnWidth: Int)],
    separator: String
) -> String {

    return content.map { stringAndColumnWidth in
        if stringAndColumnWidth.columnWidth <= 0 {
            return stringAndColumnWidth.string
        } else {
            return stringAndColumnWidth.string.padding(
                toLength: stringAndColumnWidth.columnWidth,
                withPad: " ",
                startingAt: 0
            )
        }
    }.joined(
        separator: separator
    )
}

/// A type representing a count of how many items are documented and the total number of items that could have been documented. There is, currently, no check to ensure that the number documented is less than or equal to the total.
internal struct RatioStatistic: Equatable, CustomStringConvertible, Codable {

    private enum CodingKeys: String, CodingKey {
        case documented
        case total
    }

    /// Verifies that the given values are greater  than or equal to 0.
    /// - Parameters:
    ///   - documented: Number of documented items
    ///   - total: Number of item eligible for documentation.
    /// - Throws: Throws when either total or documented count are less than 0
    internal init(documented: Int, total: Int) throws {
        guard total >= 0,
            documented >= 0
        else {
            throw CoverageDataEntry.Error.inconsistentCoverageStatistic(
                description: "{`documented`: \(documented), `total`: \(total)}")
        }

        self.documented = documented
        self.total = total
    }

    /// Convenience method that injects useful contextual information in to thrown errors if initialization of a RatioStatistic fails.
    /// - Parameters:
    ///   - documentationNode: Node for which the statistic is being created
    ///   - field: Field for which the statistic is being created
    ///   - documented: Number of documented items
    ///   - total: Number of item eligible for documentation.
    /// - Throws: Throws when either total or documented count are less than 0
    /// - Returns: A RatioStatistic initialized with the given counts.
    internal static func create(
        documentationNode: DocumentationNode,
        field: String,
        documented: Int,
        total: Int

    ) throws -> RatioStatistic {
        do {
            return try RatioStatistic(
                documented: documented,
                total: total)
        } catch (let error) {
            switch error as? CoverageDataEntry.Error {
            case .some(.inconsistentCoverageStatistic(let text)):
                // RatioStatistic's initializer doesn't know what object or field it represents. Fill in that data here.
                throw CoverageDataEntry.Error.inconsistentCoverageStatistic(
                    description:
                        "{entity: '\(documentationNode.name)}', statistic: 'method parameters', \(text)"
                )
            case .none, .some:
                // If it wasn't `inconsistentCoverageStatistic` then leave the error alone.
                throw error

            }
        }
    }

    ///  Number of documented items
    let documented: Int
    /// Number of item eligible for documentation.
    let total: Int

    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumSignificantDigits = 2
        formatter.maximumSignificantDigits = 2
        return formatter
    }()

    /// Generates a string suitable for printing in the console as a table cell representing the given fraction as both a percentage and a ratio.
    /// - Parameters:
    ///   - numerator: The top portion of the fraction to represent.
    ///   - denominator: The bottom portion of fraction to represent,
    /// - Returns: String formatted for display in console.
    static func percentageString(
        numerator: Int,
        denominator: Int
    ) -> String {
        if denominator == 0 {
            return "(\(numerator)/0)"
        }

        let fraction = "\(numerator)/\(denominator)"
        guard
            let percentage = numberFormatter.string(
                from: NSNumber(value: Double(numerator) / Double(denominator))
            )
        else {
            return fraction
        }
        return "\(percentage) (\(fraction))"

    }

    var description: String {
        RatioStatistic.percentageString(
            numerator: documented,
            denominator: total
        )
    }

    /// Represents the absence of elements to document when the given field could have them.  `"0/0"`
    static var zeroOverZero: RatioStatistic {
        return try! RatioStatistic(
            documented: 0,
            total: 0
        )
    }
}

/// A type representing a row in the condensed description of coverage data.
internal struct SummaryRow: CustomStringConvertible {

    /// The row header
    internal var rowHeader: String

    /// Cell data for this row
    internal var data: [CoverageDataEntry]

    /// The number of cells in this row.
    internal var count: Int {
        data.count
    }

    private func countMatching(
        predicate: (CoverageDataEntry) -> Bool
    ) -> Int {
        data.filter(predicate).count
    }

    private static var briefSummaryColumnWidth: Int = 15
    private static func paddingAllExceptLast(in list: [String],
                              to length: Int,
                              joiningWith separator: String) -> String {

        guard let lastColumn = list.last else {
            // list is empty
            return ""
        }

        guard list.count > 1 else {
            // list only has 1 item (already checked for 0 above)
            return lastColumn
        }


        let allButLastColumn = list.dropLast().map {
            $0.padding(
                toLength: briefSummaryColumnWidth,
                withPad: " ",
                startingAt: 0)
        }
        .joined(separator: " | ")

        // This avoids padding the end of each line which makes testing the output easier.
        return "\(allButLastColumn)\(separator)\(lastColumn)"


    }

    internal var description: String {
        let paddedHeader = rowHeader
        let hasAbstract = RatioStatistic.percentageString(
            numerator: countMatching(predicate: \.hasAbstract),
            denominator: count
        )

        let isCurated = RatioStatistic.percentageString(
            numerator: countMatching(predicate: \.isCurated),
            denominator: count
        )

        let hasCodeListing = RatioStatistic.percentageString(
            numerator: countMatching(predicate: \.hasCodeListing),
            denominator: count
        )

        return SummaryRow.paddingAllExceptLast(
            in: [
                paddedHeader,
                hasAbstract,
                isCurated,
                hasCodeListing],
            to: SummaryRow.briefSummaryColumnWidth,
            joiningWith: " | ")
    }

    internal static let summaryTableHeader: String = {
        let leftHeaderPadding = ""

        return paddingAllExceptLast(
            in: [
                leftHeaderPadding,
                "Abstract",
                "Curated",
                "Code Listing"],
            to: 30,
            joiningWith: " | ")

    }()
}

extension Array {

    /// Creates a dictionary from a provided list of items. The values of the returned array are arrays of the same type as the one provided. The keys are extracted using a keypath. Elements that result in the same key are collected in the corresponding Value.
    /// - Parameter keyPath: KeyPath used to extract dictionary Keys
    /// - Returns: A dictionary of grouped elements.
    fileprivate func createDictionary<Key>(
        pathToKey keyPath: KeyPath<Element, Key>
    )
        -> [Key: [Element]]
    where
        Key: Hashable
    {
        var back: [Key: [Element]] = [:]

        for item in self {
            let key = item[keyPath: keyPath]

            if var valueToUpdate = back[key] {
                valueToUpdate.append(item)
                back[key] = valueToUpdate
            } else {
                // If this is the first of this category found
                // create a new array
                back[key] = [item]
            }
        }

        return back
    }

    /// Creates a dictionary from a provided list of items. The values of the returned array are arrays of the same type as the one provided. The keys are extracted using a closure. Elements that result in the same key are collected in the corresponding Value.
    /// - Parameter keyPath: KeyPath used to extract dictionary Keys
    /// - Returns: A dictionary of grouped elements.
    fileprivate func createDictionary<Key>(
        closure: (Element) throws -> (Key)
    )
        rethrows -> [Key: [Element]]
    where
        Key: Hashable
    {
        var back: [Key: [Element]] = [:]

        for item in self {
            let key = try closure(item)

            if var valueToUpdate = back[key] {
                valueToUpdate.append(item)
                back[key] = valueToUpdate
            } else {
                // If this is the first of this category found
                // create a new array
                back[key] = [item]
            }
        }

        return back
    }
}

extension CoverageDataEntry {
    public enum Error: DescribedError {
        case unexpectedRoleHeader(roleHeader: DocumentationNode.Kind)
        case failedConversion(description: String)
        case inconsistentCoverageStatistic(description: String)
        case serializationError(description: String)

        public var errorDescription: String {
            switch self {
            case .unexpectedRoleHeader(let header):
                return
                    "The role header encountered while processing documentation coverage was unexpected. Kind containing role header: \(header)"
            case .failedConversion(let text):
                return text
            case .inconsistentCoverageStatistic(let text):
                return "Inconsistent coverage statistics: \(text)"
            case .serializationError(let text):
                return text
            }
        }
    }
}
