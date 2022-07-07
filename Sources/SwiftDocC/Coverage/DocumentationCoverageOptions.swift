/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Resolves and validates the arguments needed to enable the documentation coverage feature.
///
/// These options are used by the `Convert` subcommand.
public struct DocumentationCoverageOptions {
    public init(
        level: DocumentationCoverageLevel,
        kindFilterOptions: KindFilterOptions = []) {
        self.level = level

        if case .none = level {
            self.kindFilterOptions = []
        } else {
            self.kindFilterOptions = kindFilterOptions
        }
    }

    /// An instance configured to represent the choice not to produce any documentation coverage artifacts or output.
    public static var noCoverage: DocumentationCoverageOptions = DocumentationCoverageOptions(
        level: .none,
        kindFilterOptions: [])

    // The desired level of documentation coverage as specified during invocation.
    public var level: DocumentationCoverageLevel

    // Value representing which kinds to produce documentation coverage output for.
    public var kindFilterOptions: KindFilterOptions
}

extension DocumentationCoverageOptions {

    /// Creates a predicate closure based on the current configuration of the receiving instance
    /// - Returns: which will return `true` for ``CoverageDataEntry``s which should accepted according to current configuration of the instance generating the closure.
    public func generateFilterClosure() -> (CoverageDataEntry) -> Bool {
        let kindsToAccept = kindFilterOptions.kinds

        return { entry in
            if kindsToAccept.isEmpty {
                return true
            } else {
                return kindsToAccept.contains(entry.kind)
            }
        }
    }
}

/// Specifies whether the documentation coverage feature is enabled and, if it is, what amount of specificity is selected.
public enum DocumentationCoverageLevel: String, Codable, CaseIterable {
    /// No documentation coverage data should be emitted and no documentation coverage information should be displayed in console
    case none
    /// Documentation coverage data should be emitted and a high-level summary should be displayed in console
    case brief
    /// Documentation coverage data should be emitted and a per-symbol summary should be displayed in console
    case detailed
}

extension DocumentationCoverageOptions {

    /// Represents kinds to select and display documentation coverage statistics for.
    /// Note: This enum is not meant to be persisted between runs
    public struct KindFilterOptions: OptionSet, Hashable, CustomDebugStringConvertible {

        public typealias RawValue = Int
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue & BitFlagRepresentation.validBitsMask
        }

        public static let none: KindFilterOptions =     []
        internal static let module =                      KindFilterOptions(rawValue: BitFlagRepresentation.module.bitMask)
        internal static let `class` =                     KindFilterOptions(rawValue: BitFlagRepresentation.class.bitMask)
        internal static let structure =                   KindFilterOptions(rawValue: BitFlagRepresentation.structure.bitMask)
        internal static let enumeration =                 KindFilterOptions(rawValue: BitFlagRepresentation.enumeration.bitMask)
        internal static let `protocol` =                  KindFilterOptions(rawValue: BitFlagRepresentation.protocol.bitMask)
        internal static let typeAlias =                   KindFilterOptions(rawValue: BitFlagRepresentation.typeAlias.bitMask)
        internal static let typeDef =                     KindFilterOptions(rawValue: BitFlagRepresentation.typeDef.bitMask)
        internal static let associatedType =              KindFilterOptions(rawValue: BitFlagRepresentation.associatedType.bitMask)
        internal static let function =                    KindFilterOptions(rawValue: BitFlagRepresentation.function.bitMask)
        internal static let `operator` =                  KindFilterOptions(rawValue: BitFlagRepresentation.operator.bitMask)
        internal static let enumerationCase =             KindFilterOptions(rawValue: BitFlagRepresentation.enumerationCase.bitMask)
        internal static let initializer =                 KindFilterOptions(rawValue: BitFlagRepresentation.initializer.bitMask)
        internal static let instanceMethod =              KindFilterOptions(rawValue: BitFlagRepresentation.instanceMethod.bitMask)
        internal static let instanceProperty =            KindFilterOptions(rawValue: BitFlagRepresentation.instanceProperty.bitMask)
        internal static let instanceSubscript =           KindFilterOptions(rawValue: BitFlagRepresentation.instanceSubscript.bitMask)
        internal static let instanceVariable =            KindFilterOptions(rawValue: BitFlagRepresentation.instanceVariable.bitMask)
        internal static let typeMethod =                  KindFilterOptions(rawValue: BitFlagRepresentation.typeMethod.bitMask)
        internal static let typeProperty =                KindFilterOptions(rawValue: BitFlagRepresentation.typeProperty.bitMask)
        internal static let typeSubscript =               KindFilterOptions(rawValue: BitFlagRepresentation.typeSubscript.bitMask)
        internal static let globalVariable =              KindFilterOptions(rawValue: BitFlagRepresentation.globalVariable.bitMask)

        /// Mask with all valid/used bit flags set to 1.
        internal static let allSingleBitOptions: [KindFilterOptions] = {
            BitFlagRepresentation.allCases
                .map(\.bitMask)
                .map(KindFilterOptions.init(rawValue:))
        }()

        public init(commandLineStringArray: [String]) {
            let bitFlags = commandLineStringArray.compactMap { (string) in
                BitFlagRepresentation.acceptedArgumentMap[string]
            }

            self.init(bitFlags: bitFlags)
        }

        /// All valid 'single bit' values represented by the instance.
        fileprivate var individualOptions: Set<BitFlagRepresentation> {
            BitFlagRepresentation.allCases.reduce(into: []) { (optionsSplitByBit, element) in
                guard element != .none else { return }
                if self.contains(KindFilterOptions(rawValue: element.bitMask)) {
                    optionsSplitByBit.insert(element)
                }
            }
        }

        /// Individual ``DocumentationNode.Kind` `s represented by the instance.
        var kinds: Set<DocumentationNode.Kind> {
            Set(individualOptions.compactMap(\.documentationNodeKind))
        }

        public var debugDescription: String {
            return "[\(individualOptions.map(\.canonicalArgumentString).joined(separator: ", "))]"
        }
    }
}

extension DocumentationCoverageOptions.KindFilterOptions {
    public init<List>(bitFlags: List) where
        List: Collection,
        List.Element == BitFlagRepresentation {
        let mask = bitFlags.reduce(0) {
            $0 | $1.bitMask
        }

        self.init(rawValue: mask)
    }

    /// Represents a single kind option. ``DocumentationCoverageOptions/KindFilterOptions-swift.struct``
    /// cannot enforce the restriction that it only represents one
    /// option when necessary so this type is preferred in when representing individual kinds that can be represented.
    public enum BitFlagRepresentation: CaseIterable {
        case none
        case module
        case `class`
        case structure
        case enumeration
        case `protocol`
        case typeAlias
        case typeDef
        case associatedType
        case function
        case `operator`
        case enumerationCase
        case initializer
        case instanceMethod
        case instanceProperty
        case instanceSubscript
        case instanceVariable
        case typeMethod
        case typeProperty
        case typeSubscript
        case globalVariable

        /// Parses given `String` to corresponding `BitFlagRepresentation` if possible. Returns `nil` if the given string does not specify a representable value.
        public init?(string: String) {
            if let value = BitFlagRepresentation.acceptedArgumentMap[string] {
                self = value
            } else {
                return nil
            }
        }

        /// Converts given ``DocumentationNode.Kind`` to corresponding `BitFlagRepresentation` if possible. Returns `nil` if the given Kind is not representable.
        fileprivate init?(kind: DocumentationNode.Kind) {
            switch kind {
            case .module, .extendedModule: // 1
                self = .module
            case .class, .extendedClass: // 2
                self = .class
            case .structure, .extendedStructure: // 3
                self = .structure
            case .enumeration, .extendedEnumeration: // 4
                self = .enumeration
            case .protocol, .extendedProtocol: // 5
                self = .protocol
            case .typeAlias: // 6
                self = .typeAlias
            case .typeDef: // 7
                self = .typeDef
            case .associatedType: // 8
                self = .associatedType
            case .function: // 9
                self = .function
            case .operator: // 10
                self = .operator
            case .enumerationCase: // 11
                self = .enumerationCase
            case .initializer: // 12
                self = .initializer
            case .instanceMethod: // 13
                self = .instanceMethod
            case .instanceProperty: // 14
                self = .instanceProperty
            case .instanceSubscript: // 15
                self = .instanceSubscript
            case .instanceVariable: // 16
                self = .instanceVariable
            case .typeMethod: // 17
                self = .typeMethod
            case .typeProperty: // 18
                self = .typeProperty
            case .typeSubscript: // 19
                self = .typeSubscript
            case .globalVariable: // 20
                self = .globalVariable
            default:
                return nil
            }
        }

        /// Raw bit mask value for use in bitwise operations.
        fileprivate var bitMask: Int {
            switch self {
            case .none:
            return 0
            case .module:
            return 1 << 1
            case .`class`:
            return 1 << 2
            case .structure:
            return 1 << 3
            case .enumeration:
            return 1 << 4
            case .protocol:
            return 1 << 5
            case .typeAlias:
            return 1 << 6
            case .typeDef:
            return 1 << 7
            case .associatedType:
            return 1 << 8
            case .function:
            return 1 << 9
            case .operator:
            return 1 << 10
            case .enumerationCase:
            return 1 << 11
            case .initializer:
            return 1 << 12
            case .instanceMethod:
            return 1 << 13
            case .instanceProperty:
            return 1 << 14
            case .instanceSubscript:
            return 1 << 15
            case .instanceVariable:
            return 1 << 16
            case .typeMethod:
            return 1 << 17
            case .typeProperty:
            return 1 << 18
            case .typeSubscript:
            return 1 << 19
            case .globalVariable:
                return 1 << 20
            }
        }

        fileprivate static let validBitsMask: Int = {
            allCases.reduce(0) {
                $0 | $1.bitMask
            }
        }()

        /// A ``DocumentationNode.Kind`` instance value corresponding the value of the receiver. Returns `nil` for `BitFlagRepresentation.none`.
        fileprivate var documentationNodeKind: DocumentationNode.Kind? {
            switch self {
            case .none: // 0
                return .none
            case .module: // 1
                return .module
            case .class: // 2
                return .class
            case .structure: // 3
                return .structure
            case .enumeration: // 4
                return .enumeration
            case .protocol: // 5
                return .protocol
            case .typeAlias: // 6
                return .typeAlias
            case .typeDef: // 7
                return .typeDef
            case .associatedType: // 8
                return .associatedType
            case .function: // 9
                return .function
            case .operator: // 10
                return .operator
            case .enumerationCase: // 11
                return .enumerationCase
            case .initializer: // 12
                return .initializer
            case .instanceMethod: // 13
                return .instanceMethod
            case .instanceProperty: // 14
                return .instanceProperty
            case .instanceSubscript: // 15
                return .instanceSubscript
            case .instanceVariable: // 16
                return .instanceVariable
            case .typeMethod: // 17
                return .typeMethod
            case .typeProperty: // 18
                return .typeProperty
            case .typeSubscript: // 19
                return .typeSubscript
            case .globalVariable:
                return .globalVariable
            }
        }

        fileprivate var canonicalArgumentString: String {
            switch self {
            case .none: // 0
                return "none"
            case .module: // 1
                return "module"
            case .class: // 2
                return "class"
            case .structure: // 3
                return "structure"
            case .enumeration: // 4
                return "enumeration"
            case .protocol: // 5
                return "protocol"
            case .typeAlias: // 6
            return "type-alias"
            case .typeDef: // 7
                return "typedef"
            case .associatedType: // 8
                return "associated-type"
            case .function: // 9
                return "function"
            case .operator: // 10
                return "operator"
            case .enumerationCase: // 11
                return "enumeration-case"
            case .initializer: // 12
                return "initializer"
            case .instanceMethod: // 13
                return "instance-method"
            case .instanceProperty: // 14
                return "instance-property"
            case .instanceSubscript: // 15
                return "instance-subscript"
            case .instanceVariable: // 16
                return "instance-variable"
            case .typeMethod: // 17
                return "type-method"
            case .typeProperty: // 18
                return "type-property"
            case .typeSubscript: // 19
                return "type-subscript"
            case .globalVariable: // 20
                return "global-variable"
            }
        }
        /// A  dictionary where keys are all valid argument strings and values are corresponding instances of ``BitFlagRepresentation``.
        fileprivate static var acceptedArgumentMap: [String: BitFlagRepresentation] {
            [
                // 1
                "module": .module,
                // 2
                "class": .class,
                // 3
                "structure": .structure,
                // 4
                "enumeration": .enumeration,
                // 5
                "protocol": .protocol,
                // 6
                "type-alias": .typeAlias,
                // 7
                "typedef": .typeDef,
                // 8
                "associated-type": .associatedType,
                // 9
                "function": .function,
                // 10
                "operator": .operator,
                // 11
                "enumeration-case": .enumerationCase,
                // 12
                "initializer": .initializer,
                // 13
                "instance-method": .instanceMethod,
                // 14
                "instance-property": .instanceProperty,
                // 15
                "instance-subcript": .instanceSubscript,
                // 16
                "instance-variable": .instanceVariable,
                // 17
                "type-method": .typeMethod,
                // 18
                "type-property": .typeProperty,
                // 19
                "type-subscript": .typeSubscript,
                // 20
                "global-variable": .globalVariable,
            ]

        }
    }
}

extension DocumentationCoverageOptions.KindFilterOptions.BitFlagRepresentation /* ExpressibleByArgument */ {
    /// Parses given argument `String` to corresponding `BitFlagRepresentation` if possible. Returns `nil` if the given string does not specify a representable value.
    public init?(argument: String) {

        if let value = DocumentationCoverageOptions.KindFilterOptions.BitFlagRepresentation.acceptedArgumentMap[argument] {
            self = value
        } else {
            return nil
        }
    }

    public static var allValueStrings: [String] {
        Array(acceptedArgumentMap.keys)
    }

    public var defaultValueDescription: String {
        "none"
    }
}
