/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation

/// Resolves and validates the arguments needed to start a documentation preview server.
///
/// These options are used by the ``Docc/Preview`` subcommand.
public struct PreviewOptions: ParsableArguments {
    public init() { }

    /// The host name to use for the preview web server.
    ///
    /// Defaults to `localhost`.
    @Option(
        name: .long,
        help: ArgumentHelp(
            "Host name to use for the preview web server.",
            valueName: "host-name"))
    public var host: String = "localhost"

    /// The port number to use for the preview web server.
    ///
    /// Defaults to `8080`.
    @Option(
        name: .shortAndLong,
        help: ArgumentHelp(
            "Port number to use for the preview web server.",
            valueName: "port-number"))
    public var port: Int = 8080
    
    /// Converts a documentation bundle.
    ///
    /// ``PreviewAction`` makes use of ``ConvertAction`` so we import all the options
    /// that ``Docc/Convert`` provides.
    @OptionGroup()
    public var convertCommand: Docc.Convert

    public mutating func validate() throws {
        // Check that a valid port has been provided
        guard port > 1023 else {
            throw ValidationError("Ports [0...1023] are reserved, use a higher port number.")
        }
    }
}

