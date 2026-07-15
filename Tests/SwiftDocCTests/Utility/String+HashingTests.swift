/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import SwiftDocC

struct String_HashingTests {
    
    @Test(arguments: [
        ("", "146ys"),
        ("Hello", "1if00"),
        ("Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "3c6o6"),
        ("/mykit/myclass/myfunc", "4y7c"),
    ])
    func stableHashStringIsDeterministicAcrossInvocations(input: String, expected: String) {
        // Repeat the call to verify the result is stable for the given input.
        for _ in (0...100) {
            #expect(input.stableHashString == expected)
        }
    }
    
    @Test(arguments: [
        ("", "ztntfp"),
        ("s:5SideKit0A5ClassC10elementT", "1kf2iw4"),
        ("s:5SideKit0A5ClassC10value_int", "n3jy95"),
        (veryLongUSR, "1m0yasz"),
    ])
    func usrHashIsDeterministicAcrossInvocations(usr: String, expected: String) {
        // Repeat the call to verify the result is stable for the given input.
        for _ in (0...100) {
            #expect(ExternalIdentifier.usr(usr).hash == expected)
        }
    }
}

fileprivate let veryLongUSR = "s:So8CQDProcsV8textProc04lineC004rectC005rRectC004ovalC003arcC004polyC003rgnC004bitsC007commentC006txMeasC006getPicC003putpC006opcodeC08newProc106glyphsC0013printerStatusC00S5Proc40S5Proc50S5Proc6ABys5Int16V_SVSgSo5PointVA_tXCSg_yA_XCSgys4Int8V_SPySo0F0VGSgtXCSgyA3__A7_A2XtXCSgA8_A9_yA3__SpySpySo10MacPolygonVGSgGSgtXCSgyA3__s13OpaquePointerVSgtXCSgySPySo6BitMapVGSg_A7_A7_AXA19_tXCSgyAX_AXSpySpyA3_GSgGSgtXCSgA2X_AYSpyA_GSgA32_SpySo8FontInfoVGSgtXCSgySvSg_AXtXCSgyAY_AXtXCSgyA7__A7_s6UInt16VAXtXCSgSiyXCSgs5Int32VA38__SitXCSgA46_A46__A19_A38_tXCSgA44_A44_A44_tcfc"
