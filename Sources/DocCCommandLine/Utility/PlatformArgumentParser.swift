/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

enum PlatformArgumentParser {
    enum Error: DescribedError {
        case unexpectedFormat(String)
        case missingKey(String)
        
        var errorDescription: String {
            switch self {
            case .unexpectedFormat(let message), .missingKey(let message): return message
            }
        }
    }
    
    /// Parses a platform version command line argument list and returns a map of (platform, version) pairs.
    public static func parse(_ platforms: [String]) throws -> [String: PlatformVersion] {
        return try platforms.reduce(into: [:]) { (result, value) in
            let pairs = try value.components(separatedBy: ",")
                .reduce(into: [String: String]()) { (result, pair) in
                    let sides = pair.components(separatedBy: "=")
                    guard sides.count == 2 && sides.allSatisfy({ !$0.isEmpty }) else {
                        throw Error.unexpectedFormat("Unexpected value '\(pair)'. Expected format is name=value.")
                    }
                    result[sides[0]] = sides[1]
                }
            
            guard let name = pairs["name"] else {
                throw Error.missingKey("Argument '\(value)' does not contain 'name' key.")
            }
            guard let versionString = pairs["version"], let version = Version(versionString: versionString), (2...3).contains(version.count) else {
                throw Error.missingKey("Argument '\(value)' does not contain 'version' key in X.Y.Z format.")
            }
            
            let versionTriplet = VersionTriplet(version[0], version[1], version.count == 3 ? version[2] : 0)
            
            let beta: Bool
            switch pairs["beta"]?.lowercased() {
            case nil, "false", "no":
                beta = false
            case "true", "yes":
                beta = true
            default:
                throw Error.missingKey("Argument '\(value)' for 'beta' key can't be converted to boolean (true/false or yes/no).")
            }
            result[name] = PlatformVersion(versionTriplet, beta: beta)
        }
    }
}
