/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An RFC 3986 compliant URL.
///
/// Use this wrapper type to make sure your stored URLs comply
/// to RFC 3986 that `URLComponents` implements, rather than the less-
/// strict implementation of `URL`.
///
/// For example, due to older RFC compliance, `URL` fails to parse relative topic
/// references with a fragment like this:
///  - `URL(string: "doc:tutorial#test")?.fragment` -> `nil`
///  - `URLComponents(string: "doc:tutorial#test")?.fragment` -> `"test"`
/// ## See Also
///  - [RFC 3986](http://www.ietf.org/rfc/rfc3986.txt)
public struct ValidatedURL: Hashable, Equatable {
    /// The raw components that make up the validated URL.
    public private(set) var components: URLComponents
    
    /// Creates a new RFC 3986 valid URL by using the given string URL.
    ///
    /// Will return `nil` when the given `string` is not a valid URL.
    /// - Parameter string: Source URL address as string
    ///
    /// > Note:
    /// > Attempting to parse a symbol destination as a URL may result in unexpected URL components depending on the source language.
    /// > For example; an Objective-C instance method named `someMethodWithFirstValue:secondValue:` would be parsed as a
    /// > URL with the "someMethodWithFirstValue" scheme which is a valid link but which won't resolve to the intended symbol.
    /// >
    /// > When working with symbol destinations use ``init(symbolDestination:)`` instead.
    init?(_ string: String) {
        guard let components = URLComponents(string: string) else {
            return nil
        }
        self.components = components
    }
    
    /// Creates a new RFC 3986 valid URL from the given URL.
    ///
    /// Will return `nil` when the given URL doesn't comply with RFC 3986.
    /// - Parameter url: Source URL
    init?(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        self.components = components
    }
    
    /// Creates a new RFC 3986 valid URL by using the given symbol destination.
    ///
    /// - Parameter symbolDestination: Source URL address as string
    init(symbolDestination: String) {
        // Symbol links are assumed to be written as the path only, without a scheme or host component.
        var components = URLComponents()
        components.path = symbolDestination
        self.components = components
    }
    
    /// Creates a new RFC 3986 valid URL.
    init(components: URLComponents) {
        self.components = components
    }
    
    /// Returns the unmodified value in case the URL matches the required scheme or nil otherwise.
    /// - Parameter scheme: A URL scheme to match.
    /// - Returns: A valid URL if the scheme matches, `nil` otherwise.
    func requiring(scheme: String) -> ValidatedURL? {
        guard scheme == components.scheme else { return nil }
        return self
    }
    
    /// The URL as an absolute string.
    var absoluteString: String {
        return components.string!
    }
    
    /// The URL as an RFC 3986 compliant `URL` value.
    var url: URL {
        return components.url!
    }
}
