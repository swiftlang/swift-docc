/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A section that contains a list of parameters.
public struct ParametersRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .parameters
    /// The list of parameter sub-sections.
    public let parameters: [ParameterRenderSection]
    
    /// Creates a new parameters section with the given list.
    public init(parameters: [ParameterRenderSection]) {
        self.parameters = parameters
    }
}

// Diffable conformance
extension ParametersRenderSection: RenderJSONDiffable {
    /// Returns the differences between this ParametersRenderSection and the given one.
    func difference(from other: ParametersRenderSection, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.parameters, forKey: CodingKeys.parameters)

        return diffBuilder.differences
    }

    /// Returns if this ParametersRenderSection is similar enough to the given one.
    func isSimilar(to other: ParametersRenderSection) -> Bool {
        return self.parameters == other.parameters
    }
}

/// A section that contains a single, named parameter.
public struct ParameterRenderSection: Codable, Equatable {
    /// The parameter name.
    public let name: String
    /// Free-form content to provide information about the parameter.
    public var content: [RenderBlockContent]
}

// Diffable conformance
extension ParameterRenderSection: RenderJSONDiffable {
    /// Returns the differences between this ParameterRenderSection and the given one.
    func difference(from other: ParameterRenderSection, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.name, forKey: CodingKeys.name)
        diffBuilder.addDifferences(atKeyPath: \.content, forKey: CodingKeys.content)

        return diffBuilder.differences
    }

    /// Returns if this ParameterRenderSection is similar enough to the given one.
    func isSimilar(to other: ParameterRenderSection) -> Bool {
        return self.name == other.name || self.content == other.content
    }
}
