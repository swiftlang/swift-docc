/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocCUtilities

class SignalTests: XCTestCase {
    #if os(macOS) || os(Linux) || os(Android)
    /// The path to the built products directory.
    private var productDirectory: URL {
        #if !os(Linux) && !os(Android)
        guard let xcTestBundle = Bundle.allBundles.first(where: { bundle in
            bundle.bundleURL.pathExtension == "xctest"
        }) else {
            fatalError("Couldn't find the products directory.")
        }
        return xcTestBundle.bundleURL.deletingLastPathComponent()
        #else
        return Bundle.main.bundleURL
        #endif
    }
    
    /// Runs `signal-test-app` and confirms that it exits with code 99.
    ///
    /// `signal-test-app` sends a kill signal to itself and uses ``Signal`` to intercept that signal
    /// and set the exit code to 99.
    func testTrappingSignal() throws {
        let signalTestAppPath = productDirectory.appendingPathComponent("signal-test-app").path
        
        // This is a workaround (r69892261) to address situations where the `signal-test-app`
        // executable this test relies on has not been built.
        //
        // It will be built by default when building the entire DocC package but
        // if you have another scheme selected in Xcode (like the `docc` executable) it's possible
        // the `signal-test-app` executable won't exist when the tests are run and this test will
        // be skipped.
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: signalTestAppPath),
            """
            The executable ('signal-test-app') required for this test was not found.
            It is built as a part of the overall 'SwiftDocC-Package' scheme in Xcode."
            """)
        
        // Run signal test app.
        let runSignalTestApp = Process()
        runSignalTestApp.executableURL = URL(fileURLWithPath: "/bin/bash")
        runSignalTestApp.arguments = ["-c", signalTestAppPath]
        try runSignalTestApp.run()
        runSignalTestApp.waitUntilExit()
        guard runSignalTestApp.terminationStatus == 99 else {
            XCTFail("Unexpected termination status: \(runSignalTestApp.terminationStatus) \(runSignalTestApp.terminationReason)\n")
            return
        }
    }
    
    #endif
}
