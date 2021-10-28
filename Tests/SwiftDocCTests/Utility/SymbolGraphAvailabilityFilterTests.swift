/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SymbolKit
@testable import SwiftDocC

class SymbolGraphAvailabilityFilterTests: XCTestCase {
    
    func testFilterAvailabilityThatApplyToPlatforms() {
        let unfiltered = SymbolGraph.Symbol.Availability(availability: [
            // Availability without a domain applies to all platforms
            .init(domain: nil, introducedVersion: nil, deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: false, willEventuallyBeDeprecated: false),
            // A few domain specific availabilities to filter
            .init(domain: .init(rawValue: SymbolGraph.Symbol.Availability.Domain.macOS),introducedVersion: nil, deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: false, willEventuallyBeDeprecated: false),
            .init(domain: .init(rawValue: SymbolGraph.Symbol.Availability.Domain.iOS), introducedVersion: nil, deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: false, willEventuallyBeDeprecated: false),
            .init(domain: .init(rawValue: SymbolGraph.Symbol.Availability.Domain.tvOS), introducedVersion: nil, deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: false, willEventuallyBeDeprecated: false),
            .init(domain: .init(rawValue: SymbolGraph.Symbol.Availability.Domain.watchOS), introducedVersion: nil, deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: false, willEventuallyBeDeprecated: false),
            // This will always be filtered out
            .init(domain: .init(rawValue: "unknownDomain"), introducedVersion: .init(major: 5, minor: 5, patch: 5), deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: false, willEventuallyBeDeprecated: false),
        ])
        
        var filtered = unfiltered.filterItems(thatApplyTo: .macOS).availability
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered.map { $0.domain?.rawValue }, [nil, "macOS"])
        for alias in PlatformName.macOS.aliases {
            let filteredForAlias = unfiltered.filterItems(thatApplyTo: PlatformName(operatingSystemName: alias)).availability
            XCTAssertEqual(filteredForAlias.count, 2)
            XCTAssertEqual(filteredForAlias.map { $0.domain?.rawValue }, [nil, "macOS"])
        }
        
        filtered = unfiltered.filterItems(thatApplyTo: .iOS).availability
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered.map { $0.domain?.rawValue }, [nil, "iOS"])
        
        filtered = unfiltered.filterItems(thatApplyTo: .watchOS).availability
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered.map { $0.domain?.rawValue }, [nil, "watchOS"])
        
        filtered = unfiltered.filterItems(thatApplyTo: .tvOS).availability
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered.map { $0.domain?.rawValue }, [nil, "tvOS"])
    }
}
