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
    
    /// Whether or not experimental support for device frames on images and video is enabled.
    public var isExperimentalDeviceFrameSupportEnabled = false

    /// Whether or not experimental support for emitting a serialized version of the local link resolution information is enabled.
    public var isExperimentalLinkHierarchySerializationEnabled = false
    
    /// Whether or not experimental support for combining overloaded symbol pages is enabled.
    public var isExperimentalOverloadedSymbolPresentationEnabled = false
    
    /// Whether experimental support for automatically rendering links on symbol documentation to articles
    /// that mention that symbol.
    public var isExperimentalMentionedInEnabled = false
    
    /// Whether or not support for validating parameters and return value documentation is enabled.
    public var isParametersAndReturnsValidationEnabled = true
    
    @available(*, deprecated, renamed: "isParametersAndReturnsValidationEnabled", message: "Use 'isParametersAndReturnsValidationEnabled' instead. This deprecated API will be removed after 6.1 is released")
    public var isExperimentalParametersAndReturnsValidationEnabled: Bool {
        get { isParametersAndReturnsValidationEnabled }
        set { isParametersAndReturnsValidationEnabled = newValue }
    }
    
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

    /// Set feature flags that were loaded from a bundle's Info.plist.
    internal mutating func loadFlagsFromBundle(_ bundleFlags: DocumentationBundle.Info.BundleFeatureFlags) {
        if let overloadsPresentation = bundleFlags.experimentalOverloadedSymbolPresentation {
            self.isExperimentalOverloadedSymbolPresentationEnabled = overloadsPresentation
        }
    }
}
