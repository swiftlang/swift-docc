/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A kind of a REST request parameter.
///
/// Parameter sections might describe parameters used in
/// the URL query, the URL path, HTTP headers, or a multi-part HTTP body.
public enum RESTParameterSource: String, Codable {
    /// A named URL query parameter, for example, `?category=90s`.
    case query
    /// A named URL path parameter, for example, `/artists/MyArtist`.
    case path
    /// An HTTP header sent with the request, for example, `Authorization: MyCredentials`.
    case header
    /// An HTTP cookie sent with the request.
    case cookie
}

/// A section that contains a list of REST parameters.
public struct RESTParametersRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .restParameters
    /// The title for the section.
    public let title: String
    /// The list of REST parameters.
    public let parameters: [RenderProperty]
    /// The kind of listed parameters.
    public let source: RESTParameterSource

    enum CodingKeys: String, CodingKey {
        case kind
        case title
        case parameters = "items"
        case source
    }

    /// Creates a new REST parameters section.
    /// - Parameters:
    ///   - title: The title for the section.
    ///   - parameters: The list of REST parameters.
    ///   - source: The kind of listed parameters.
    public init(title: String, parameters: [RenderProperty], source: RESTParameterSource) {
        self.title = title
        self.parameters = parameters
        self.source = source
    }
}

// Diffable conformance
extension RESTParametersRenderSection: RenderJSONDiffable {
    /// Returns the differences between this RESTParametersRenderSection and the given one.
    func difference(from other: RESTParametersRenderSection, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.title, forKey: CodingKeys.title)
        diffBuilder.addDifferences(atKeyPath: \.parameters, forKey: CodingKeys.parameters)
        diffBuilder.addDifferences(atKeyPath: \.source, forKey: CodingKeys.source)

        return diffBuilder.differences
    }
    
    /// Returns if this RESTParametersRenderSection is similar enough to the given one.
    func isSimilar(to other: RESTParametersRenderSection) -> Bool {
        return self.title == other.title
    }
}
