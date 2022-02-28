/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A set of feature flags that conditionally enable (usually experimental) behavior in Swift-DocC.
public struct FeatureFlags: Codable {
    /// The current feature flags that Swift-DocC uses to conditionally enable
    /// (usually experimental) behavior in Swift-DocC.
    public static var current = FeatureFlags()
    
    /// Whether or not experimental language support for Objective-C is enabled.
    ///
    /// > Note: Objective-C support is now enabled by default. Setting this property has no effect.
    @available(
        *, deprecated,
        message: "Objective-C support is enabled by default. Setting this property has no effect."
    )
    public var isExperimentalObjectiveCSupportEnabled = false
    
    /// Whether or not experimental support for emitting a JSON representation of the converted
    /// documentation's navigator index is enabled.
    @available(*, deprecated, message: "Render Index JSON is now emitted by default.")
    public var isExperimentalJSONIndexEnabled = true
    
    /// Creates a set of feature flags with the given values.
    ///
    /// - Parameters:
    ///   - additionalFlags: Any additional flags to set.
    ///
    ///     This field allows clients to set feature flags without adding new API.
    public init(
        additionalFlags: [String : Bool] = [:]
    ) {
    }
}
