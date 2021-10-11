/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class String_HashingTests: XCTestCase {
    
    func testFNV1aHash() {
        // Test that the results are stable for the given inputs
        (0...100).forEach { _ in
            XCTAssertEqual("146ys", "".stableHashString)
            XCTAssertEqual("1if00", "Hello".stableHashString)
            XCTAssertEqual("3c6o6", "Lorem ipsum dolor sit amet, consectetur adipiscing elit.".stableHashString)
            XCTAssertEqual("4y7c", "/mykit/myclass/myfunc".stableHashString)
        }
    }
    
    func testUSRHash() {
        // Test that the results are stable for the given inputs
        (0...100).forEach { _ in
            XCTAssertEqual("ztntfp", ExternalIdentifier.usr("").hash)
            XCTAssertEqual("1kf2iw4", ExternalIdentifier.usr("s:5SideKit0A5ClassC10elementT").hash)
            XCTAssertEqual("n3jy95", ExternalIdentifier.usr("s:5SideKit0A5ClassC10value_int").hash)
            XCTAssertEqual("1m0yasz", ExternalIdentifier.usr(veryLongUSR).hash)
        }
    }
}

fileprivate let veryLongUSR = "s:So8CQDProcsV8textProc04lineC004rectC005rRectC004ovalC003arcC004polyC003rgnC004bitsC007commentC006txMeasC006getPicC003putpC006opcodeC08newProc106glyphsC0013printerStatusC00S5Proc40S5Proc50S5Proc6ABys5Int16V_SVSgSo5PointVA_tXCSg_yA_XCSgys4Int8V_SPySo0F0VGSgtXCSgyA3__A7_A2XtXCSgA8_A9_yA3__SpySpySo10MacPolygonVGSgGSgtXCSgyA3__s13OpaquePointerVSgtXCSgySPySo6BitMapVGSg_A7_A7_AXA19_tXCSgyAX_AXSpySpyA3_GSgGSgtXCSgA2X_AYSpyA_GSgA32_SpySo8FontInfoVGSgtXCSgySvSg_AXtXCSgyAY_AXtXCSgyA7__A7_s6UInt16VAXtXCSgSiyXCSgs5Int32VA38__SitXCSgA46_A46__A19_A38_tXCSgA44_A44_A44_tcfc"
