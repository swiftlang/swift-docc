/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation

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
    /// > Attempting to parse a symbol path as a URL may result in unexpected URL components depending on the source language.
    /// > For example; an Objective-C instance method named `someMethodWithFirstValue:secondValue:` would be parsed as a
    /// > URL with the "someMethodWithFirstValue" scheme which is a valid link but which won't resolve to the intended symbol.
    /// >
    /// > When working with symbol destinations use ``init(symbolPath:)`` instead.
    /// >
    /// > When working with authored documentation links use ``init(parsingAuthoredLink:)`` instead.
    init?(parsingExact string: String) {
        guard let components = URLComponents(string: string) else {
            return nil
        }
        self.components = components
    }
    
    /// Creates a new RFC 3986 valid URL by using the given string URL and percent escaping the fragment component if necessary.
    ///
    /// Will return `nil` when the given `string` is not a valid URL.
    /// - Parameter string: Source URL address as string.
    ///
    /// If the parsed fragment component contains characters not allowed in the fragment of a URL, those characters will be percent encoded.
    ///
    /// Use this to parse author provided documentation links that may contain links to on-page subsections. Escaping the fragment allows authors
    /// to write links to subsections using characters that wouldn't otherwise be allowed in a fragment of a URL.
    ///
    /// - Important: Documentation links don't include query items but "?" may appear in the link's path.
    init?(parsingAuthoredLink string: String) {
        // Try to parse the string without escaping anything
        if var parsedComponents = ValidatedURL(parsingExact: string)?.components {
            // Documentation links don't include query items but "?" may appear in the link's path.
            // If `URLComponents` decoded a `query`, that's correct from a general URL standpoint but incorrect from a documentation link standpoint.
            // To create a valid documentation link, we move the `query` component and its "?" separator into the `path` component.
            if let query = parsedComponents.query {
                parsedComponents.path += "?\(query)"
                parsedComponents.query = nil
            }
            
            assert(parsedComponents.string != nil, "Failed to parse authored link \(string.singleQuoted)")
            self.components = parsedComponents
            return
        }
        
        // If the `URLComponents(string:)` parsing in `init(parsingExact:)` failed try a fallback that attempts to individually
        // percent encode each component.
        //
        // This fallback parsing tries to determine the substrings of the authored link that correspond to the scheme, bundle
        // identifier, path, and fragment of a documentation link or symbol link. It is not meant to work with general links.
        //
        // By identifying the subranges they can each be individually percent encoded with the characters that are allowed for
        // that component. This allows authored links to contain characters that wouldn't otherwise be valid in a general URL.
        //
        // Assigning the percent encoded values to `URLComponents/percentEncodedHost`, URLComponents/percentEncodedPath`, and
        // URLComponents/percentEncodedFragment` allow for the creation of a `URLComponents` value with special characters.
        var components = URLComponents()
        var remainder = string[...]
        
        // See if the link is a documentation link and try to split out the scheme and bundle identifier. If the link isn't a
        // documentation link it's assumed that it's a symbol link that start with the path component.
        // Other general URLs should have been successfully parsed with `URLComponents(string:)` in `init(parsingExact:)` above.
        if remainder.hasPrefix("\(ResolvedTopicReference.urlScheme):") {
            // The authored link is a doc link
            components.scheme = ResolvedTopicReference.urlScheme
            remainder = remainder.dropFirst("\(ResolvedTopicReference.urlScheme):".count)
            
            if remainder.hasPrefix("//") {
                remainder = remainder.dropFirst(2) // Don't include the "//" prefix in the `host` component.
                // The authored link includes a bundle ID
                guard let startOfPath = remainder.firstIndex(of: "/") else {
                    // The link started with "doc://" but didn't contain another "/" to start of the path.
                    return nil
                }
                components.percentEncodedHost = String(remainder[..<startOfPath]).addingPercentEncodingIfNeeded(withAllowedCharacters: .urlHostAllowed)
                remainder = remainder[startOfPath...]
            }
        }
        
        // This either is the start of a symbol link or the remainder of a doc link after the scheme and bundle ID was parsed.
        // This means that the remainder of the string is a path with an optional fragment. No other URL components are supported
        // by documentation links and symbol links.
        if let fragmentSeparatorIndex = remainder.firstIndex(of: "#") {
            // Encode the path substring and fragment substring separately
            guard let path = String(remainder[..<fragmentSeparatorIndex]).addingPercentEncodingIfNeeded(withAllowedCharacters: .urlPathAllowed) else {
                return nil
            }
            components.percentEncodedPath = path
            components.percentEncodedFragment = remainder[fragmentSeparatorIndex...].dropFirst().addingPercentEncodingIfNeeded(withAllowedCharacters: .urlFragmentAllowed)
        } else {
            // Since the link didn't include a fragment, the rest of the string is the path.
            guard let path = remainder.addingPercentEncodingIfNeeded(withAllowedCharacters: .urlPathAllowed) else {
                return nil
            }
            components.percentEncodedPath = path
        }
        
        assert(components.string != nil, "Failed to parse authored link \(string.singleQuoted)")
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
    
    /// Creates a new RFC 3986 valid URL by using the given symbol path.
    ///
    /// - Parameter symbolDestination: A symbol path as a string, with path components separated by "/".
    init(symbolPath: String) {
        // Symbol links are assumed to be written as the path only, without a scheme or host component.
        var components = URLComponents()
        components.path = symbolPath
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

private extension StringProtocol {
    /// Returns a percent encoded version of the string or the original string if it is already percent encoded.
    func addingPercentEncodingIfNeeded(withAllowedCharacters allowedCharacters: CharacterSet) -> String? {
        var needsPercentEncoding: Bool {
            for (index, character) in unicodeScalars.indexed() where !allowedCharacters.contains(character) {
                // Check if the character "%" represents a percent encoded URL.
                // Any other disallowed character is an indication that this substring needs percent encoding.
                if character == "%" {
                    // % isn't allowed in a URL fragment but it is also the escape character for percent encoding.
                    guard self.distance(from: index, to: self.endIndex) >= 2 else {
                        // There's not two characters after the "%". This "%" can't represent a percent encoded character.
                        return true
                    }
                    let firstFollowingIndex  = self.index(after: index)
                    let secondFollowingIndex = self.index(after: firstFollowingIndex)
                    
                    // Check if the next two characthers represent a percent encoded
                    // URL.
                    // If either of the two following characters aren't hex digits,
                    // the "%" doesn't represent a percent encoded character.
                    if Character(unicodeScalars[firstFollowingIndex]).isHexDigit,
                       Character(unicodeScalars[secondFollowingIndex]).isHexDigit
                    {
                        // Later characters in the string might require percentage encoding.
                        continue
                    }
                }
                return true
            }
            return false
        }
        
        return if needsPercentEncoding {
            addingPercentEncoding(withAllowedCharacters: allowedCharacters)
        } else {
            String(self)
        }
    }
}
