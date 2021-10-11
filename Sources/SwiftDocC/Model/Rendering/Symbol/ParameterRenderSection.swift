/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A section that contains a list of parameters.
public struct ParametersRenderSection: RenderSection {
    public var kind: RenderSectionKind = .parameters
    /// The list of parameter sub-sections.
    public let parameters: [ParameterRenderSection]
    
    /// Creates a new parameters section with the given list.
    public init(parameters: [ParameterRenderSection]) {
        self.parameters = parameters
    }
}

/// A section that contains a single, named parameter.
public struct ParameterRenderSection: Codable {
    /// The parameter name.
    public let name: String
    /// Free-form content to provide information about the parameter.
    public var content: [RenderBlockContent]
}
