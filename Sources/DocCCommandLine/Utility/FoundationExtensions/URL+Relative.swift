/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension URL {
    /// Returns a copy of the URL with a path component that's relative to the path in the other URL.
    ///
    /// - Parameter other: The other URL to compute the relative path from.
    /// - Returns: A URL with the path of `self` relative to `other`.
    func relative(to other: URL) -> URL? {
        var urlComponents = URLComponents()
        guard self != other else { return urlComponents.url }

        // To be able to compare the components of the two URLs they both need to be absolute and standardized.
        let components = absoluteURL.standardizedFileURL.pathComponents
        let otherComponents = other.absoluteURL.standardizedFileURL.pathComponents

        let commonPrefixLength = Array(zip(components, otherComponents).prefix { lhs, rhs in lhs == rhs }).count

        let relativeComponents = repeatElement("..", count: otherComponents.count - commonPrefixLength) + components.dropFirst(commonPrefixLength)
       
        urlComponents.path = relativeComponents.joined(separator: "/")
        return urlComponents.url
    }
}
