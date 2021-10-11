/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An availability-change diff for a symbol, if that data is available.
public struct DiffAvailability: Codable {
    /// The change information for a symbol that was updated in a beta version of the current platform.
    public var beta: Info?

    /// The change information for a symbol that was updated in a minor increment of the current platform version.
    public var minor: Info?

    /// The change information for a symbol that was updated in a major increment of the current platform version.
    public var major: Info?

    /// The change information for a symbol that was updated in the current platform version.
    public var sdk: Info?

    /// Creates a new availability change diff.
    /// - Parameters:
    ///   - beta: Beta change information.
    ///   - minor: Minor version change information.
    ///   - major: Major version change information.
    ///   - sdk: Platform version change information.
    public init(beta: Info?, minor: Info?, major: Info?, sdk: Info?) {
        self.beta = beta
        self.minor = minor
        self.major = major
        self.sdk = sdk
    }

    /// An item describing an availability change.
    public struct Info: Codable, Equatable {
        /// The type of change, for example, "modified" or "added".
        public var change: String

        /// The platform where the change occurred.
        public var platform: String

        /// The target versions of the platform for this diff.
        public var versions: [String]
        
        /// Creates a new availability change.
        /// - Parameters:
        ///   - change: The type of change, for example, "modified" or "added".
        ///   - platform: The platform where the change occurred.
        ///   - versions: The target versions of the platform for this diff.
        public init(change: String, platform: String, versions: [String]) {
            self.change = change
            self.platform = platform
            self.versions = versions
        }
    }
}
