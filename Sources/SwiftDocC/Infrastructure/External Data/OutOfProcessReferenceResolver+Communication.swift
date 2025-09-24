/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension OutOfProcessReferenceResolver {
    // MARK: Capabilities
    
    /// A set of optional capabilities that either DocC or your external link resolver declares that it supports.
    ///
    /// ## Supported messages
    ///
    /// If your external link resolver declares none of the optional capabilities, then DocC will only send it the following messages:
    /// - ``RequestV2/link(_:)``
    /// - ``RequestV2/symbol(_:)``
    public struct Capabilities: OptionSet, Codable {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            rawValue = try container.decode(Int.self)
        }
    }
    
    // MARK: Request & Response
    
    /// Request messages that DocC sends to the external link resolver.
    ///
    /// ## Topics
    /// ### Base requests
    ///
    /// Your external link resolver always needs to handle the following requests regardless of its declared capabilities:
    ///
    /// - ``link(_:)``
    /// - ``symbol(_:)``
    public enum RequestV2: Codable {
        /// A request to resolve a link
        ///
        /// Your external resolver
        case link(String)
        /// A request to resolve a symbol based on its precise identifier.
        case symbol(String)
        
        // This empty-marker case is here because non-frozen enums are only available when Library Evolution is enabled,
        // which is not available to Swift Packages without unsafe flags (rdar://78773361).
        // This can be removed once that is available and applied to Swift-DocC (rdar://89033233).
        @available(*, deprecated, message: """
        This enum is non-frozen and may be expanded in the future; add a `default` case, and do nothing in it, instead of matching this one. 
        Your external link resolver won't be passed new messages that it hasn't declared the corresponding capability for.
        """)
        case _nonFrozenEnum_useDefaultCase
        
        private enum CodingKeys: CodingKey {
            case link, symbol // Default requests keys
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
                case .link(let link): try container.encode(link, forKey: .link)
                case .symbol(let id): try container.encode(id,   forKey: .symbol)
                    
                case ._nonFrozenEnum_useDefaultCase:
                    fatalError("Never use '_nonFrozenEnum_useDefaultCase' as a real case.")
            }
        }
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self = switch container.allKeys.first {
                case .link?:   .link(  try container.decode(String.self,         forKey: .link))
                case .symbol?: .symbol(try container.decode(String.self,         forKey: .symbol))
                case nil:      throw OutOfProcessReferenceResolver.Error.unknownTypeOfRequest
            }
        }
    }

    /// A response message from the external link resolver.
    ///
    /// If your external resolver sends a response that's associated with a capability that DocC hasn't declared support for, then DocC will fail to handle the response.
    public enum ResponseV2: Codable {
        /// The initial identifier and capabilities message.
        ///
        /// Your external link resolver should send this message, exactly once, after it has launched to signal that its ready to receive requests.
        ///
        /// The capabilities that your external link resolver declares in this message determines which optional request messages that DocC will send.
        /// If your resolver doesn't declare _any_ capabilities it only needs to handle the 3 default requests. See <doc:RequestV2#Base-requests>.
        case identifierAndCapabilities(DocumentationBundle.Identifier, Capabilities)
        /// The error message of the problem that the external link resolver encountered while resolving the requested topic or symbol.
        case failure(DiagnosticInformation)
        /// A response with the resolved information about the requested topic or symbol.
        case resolved(LinkDestinationSummary)
        
        // This empty-marker case is here because non-frozen enums are only available when Library Evolution is enabled,
        // which is not available to Swift Packages without unsafe flags (rdar://78773361).
        // This can be removed once that is available and applied to Swift-DocC (rdar://89033233).
        @available(*, deprecated, message: """
        This enum is non-frozen and may be expanded in the future; add a `default` case, and do nothing in it, instead of matching this one. 
        Your external link resolver won't be passed new messages that it hasn't declared the corresponding capability for.
        """)
        case _nonFrozenEnum_useDefaultCase
        
        private enum CodingKeys: String, CodingKey {
            // Default response keys
            case identifier, capabilities
            case failure
            case resolved
        }
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self = switch container.allKeys.first {
                case .identifier?, .capabilities?:
                    .identifierAndCapabilities(
                        try container.decode(DocumentationBundle.Identifier.self, forKey: .identifier),
                        try container.decode(Capabilities.self, forKey: .capabilities)
                    )
                case .failure?:
                    .failure(try container.decode(DiagnosticInformation.self, forKey: .failure))
                case .resolved?:
                    .resolved(try container.decode(LinkDestinationSummary.self, forKey: .resolved))
                case nil:
                    throw OutOfProcessReferenceResolver.Error.invalidResponseKindFromClient
            }
        }
        
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
                case .identifierAndCapabilities(let identifier, let capabilities):
                    try container.encode(identifier,   forKey: .identifier)
                    try container.encode(capabilities, forKey: .capabilities)
                    
                case .failure(errorMessage: let diagnosticInfo):
                    try container.encode(diagnosticInfo, forKey: .failure)
                    
                case .resolved(let summary):
                    try container.encode(summary, forKey: .resolved)
                    
                case ._nonFrozenEnum_useDefaultCase:
                    fatalError("Never use '_nonFrozenEnum_useDefaultCase' for anything.")
            }
        }
    }
}

extension OutOfProcessReferenceResolver.ResponseV2 {
    /// Information about why the external resolver failed to resolve the `link(_:)`, or `symbol(_:)` request.
    public struct DiagnosticInformation: Codable {
        /// A brief user-facing summary of the issue that caused the external resolver to fail.
        public var summary: String
        
        /// A list of possible suggested solutions that can address the failure.
        public var solutions: [Solution]?
        
        /// Creates a new value with information about why the external resolver failed to resolve the `link(_:)`, or `symbol(_:)` request.
        /// - Parameters:
        ///   - summary: A brief user-facing summary of the issue that caused the external resolver to fail.
        ///   - solutions: Possible possible suggested solutions that can address the failure.
        public init(
            summary: String,
            solutions: [Solution]?
        ) {
            self.summary = summary
            self.solutions = solutions
        }
        
        /// A possible solution to an external resolver issue.
        public struct Solution: Codable {
            /// A brief user-facing description of what the solution is.
            public var summary: String
            /// A full replacement of the link.
            public var replacement: String?
            
            /// Creates a new solution to an external resolver issue
            /// - Parameters:
            ///   - summary: A brief user-facing description of what the solution is.
            ///   - replacement: A full replacement of the link.
            public init(summary: String, replacement: String?) {
                self.summary = summary
                self.replacement = replacement
            }
        }
    }
}
