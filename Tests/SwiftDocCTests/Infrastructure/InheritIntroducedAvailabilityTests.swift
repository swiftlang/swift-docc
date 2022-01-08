/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import SymbolKit

fileprivate extension SymbolGraph.Symbol {
    var availability: SymbolGraph.Symbol.Availability? {
        return self.mixins[SymbolGraph.Symbol.Availability.mixinKey] as? SymbolGraph.Symbol.Availability
    }
}

/// Tests inheritability of `introduced` availability versions
/// when symbols don't have that annotation from source.
///
/// This information should come from a documentation bundle's
/// Info.plist `CDAppleDefaultAvailability` dictionary: the
/// platform version is assumed to a be a symbols `introduced`
/// availability version for that platform.
///
/// This test makes use of the `FillIntroduced.symbols.json`
/// symbol graph file in `TestBundle.docc`, along with its `Info.plist`
/// with the aforementioned `CDAppleDefaultAvailability` dictionary
/// added for macOS, iOS, tvOS, and watchOS.
class InheritIntroducedAvailabilityTests: XCTestCase {
    typealias Domain = SymbolGraph.Symbol.Availability.Domain
    typealias Version = SymbolGraph.SemanticVersion
    
    var testBundle: DocumentationBundle!
    var context: DocumentationContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        (testBundle, context) = try testBundleAndContext(named: "TestBundle")
    }
    
    override func tearDown() {
        testBundle = nil
        context = nil
        super.tearDown()
    }

    /// Tests that the `introduced` availability version comes from
    /// the macOS version in the Info.plist
    func testMacOSOnlyDeprecated() {
        let macOSOnlyDeprecated =
            context.symbolIndex["s:14FillIntroduced19macOSOnlyDeprecatedyyF"]!
                .symbol!.availability!.availability.first {
            $0.domain?.rawValue == PlatformName.macOS.rawValue
        }!

        // From Info.plist, filled
        XCTAssertEqual(Version(major: 10, minor: 9, patch: 0), macOSOnlyDeprecated.introducedVersion)

        // From symbol graph, untouched
        XCTAssertEqual(Version(major: 10, minor: 10, patch: 0), macOSOnlyDeprecated.deprecatedVersion)
    }

    /// Tests that existing `introduced` availability isn't overwritten for
    /// macOS.
    func testMacOSOnlyIntroduced() {
        // Don't overwrite existing `macOS, introduced: 10.15`
        let macOSOnlyIntroduced =
            context.symbolIndex["s:14FillIntroduced09macOSOnlyB0yyF"]!
                .symbol!.availability!.availability.first {
            $0.domain?.rawValue == PlatformName.macOS.rawValue
        }!

        // From symbol graph, don't overwrite
        XCTAssertEqual(Version(major: 10, minor: 10, patch: 0), macOSOnlyIntroduced.introducedVersion)
    }

    /// Tests that the `introduced` availability version comes from
    /// the iOS version in the Info.plist
    func testiOSOnlyDeprecated() {
        let iOSOnlyDeprecated =
            context.symbolIndex["s:14FillIntroduced17iOSOnlyDeprecatedyyF"]!
                .symbol!.availability!.availability.first {
            $0.domain?.rawValue == PlatformName.iOS.rawValue
        }!

        // From Info.plist, filled
        XCTAssertEqual(Version(major: 11, minor: 1, patch: 0), iOSOnlyDeprecated.introducedVersion)

        // From symbol graph, untouched
        XCTAssertEqual(Version(major: 13, minor: 0, patch: 0), iOSOnlyDeprecated.deprecatedVersion)
    }

    /// Tests that existing `introduced` availability isn't overwritten for
    /// iOS.
    func testiOSOnlyIntroduced() {
        // Don't overwrite existing `macOS, introduced: 10.15`
        let iOSOnlyIntroduced =
            context.symbolIndex["s:14FillIntroduced07iOSOnlyB0yyF"]!
                .symbol!.availability!.availability.first {
            $0.domain?.rawValue == PlatformName.iOS.rawValue
        }!

        // From symbol graph, don't overwrite
        XCTAssertEqual(Version(major: 13, minor: 0, patch: 0), iOSOnlyIntroduced.introducedVersion)
    }

    /// Tests that the `introduced` availability version comes from
    /// the iOS version in the Info.plist via a fallback mechanism.
    func testCatalystOnlyDeprecated() {
        let catalystOnlyDeprecated =
            context.symbolIndex["s:14FillIntroduced25macCatalystOnlyDeprecatedyyF"]!
                .symbol!.availability!.availability.first {
            $0.domain?.rawValue == PlatformName.catalyst.rawValue
        }!

        // From Info.plist, filled from iOS
        XCTAssertEqual(Version(major: 11, minor: 1, patch: 0), catalystOnlyDeprecated.introducedVersion)

        // From symbol graph, untouched
        XCTAssertEqual(Version(major: 13, minor: 0, patch: 0), catalystOnlyDeprecated.deprecatedVersion)
    }

    /// Tests that existing `introduced` availability isn't overwritten for
    /// macCatalyst.
    func testCatalystOnlyIntroduced() {
        // Don't overwrite existing `macOS, introduced: 10.15`
        let catalystOnlyIntroduced =
            context.symbolIndex["s:14FillIntroduced015macCatalystOnlyB0yyF"]!
                .symbol!.availability!.availability.first {
            $0.domain?.rawValue == PlatformName.catalyst.rawValue
        }!

        // From symbol graph, don't overwrite
        XCTAssertEqual(Version(major: 13, minor: 0, patch: 0), catalystOnlyIntroduced.introducedVersion)
    }

    /// Tests that a default `introduced` availability isn't added for platforms
    /// that were marked as "unconditionally available".
    ///
    /// Example
    /// ```swift
    /// // Don't add `introduced` to this.
    /// @available(watchOS, unavailable)
    /// ```
    func testIntroducedNotAddedToUnavailable() {
        /// A symbol that is only available for macOS and iOS, explicitly
        /// unavailable for tvOS and watchOS.
        ///
        /// ```swift
        /// @available(iOS 14.0, *)
        /// @available(macOS 10.16, *)
        /// @available(tvOS, unavailable)
        /// @available(watchOS, unavailable)
        /// ```
        let iOSMacOSOnly = context.symbolIndex["s:14FillIntroduced12iOSMacOSOnlyyyF"]!

        /// These domains should not have had an `introduced` version added.
        let domainsThatShouldntHaveIntroduced = Set([
            Domain.tvOS,
            Domain.watchOS,
        ])

        for item in iOSMacOSOnly.symbol!.availability!.availability {
            if domainsThatShouldntHaveIntroduced.contains(item.domain!.rawValue) {
                XCTAssertNil(item.introducedVersion)
            }
        }
    }
}
