/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SymbolKit
@testable import SwiftDocC

class SymbolPathTreeTests: XCTestCase {
    
    override func setUpWithError() throws {
        let (_, context) = try testBundleAndContext(named: "MixedFramework")
        tree = context.symbolPathTree
    }
    override func tearDown() {
        tree = nil
    }
    var tree: SymbolPathTree!
    
    func testFindingUnambiguousAbsolutePaths() throws {
        try assertFindsPath("/MixedFramework", in: tree, asSymbolID: "MixedFramework")
        
        // @objc public enum MyEnum: Int {
        //     case firstCase
        //     case secondCase
        //     public func myEnumFunction() { }
        //     public typealias MyEnumTypeAlias = Int
        //     public var myEnumProperty: MyEnumTypeAlias { 0 }
        // }
        try assertFindsPath("/MixedFramework/MyEnum", in: tree, asSymbolID: "c:@M@MixedFramework@E@MyEnum")
        try assertFindsPath("/MixedFramework/MyEnum/firstCase", in: tree, asSymbolID: "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        try assertFindsPath("/MixedFramework/MyEnum/secondCase", in: tree, asSymbolID: "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        try assertFindsPath("/MixedFramework/MyEnum/myEnumFunction()", in: tree, asSymbolID: "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        try assertFindsPath("/MixedFramework/MyEnum/MyEnumTypeAlias", in: tree, asSymbolID: "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        try assertFindsPath("/MixedFramework/MyEnum/myEnumProperty", in: tree, asSymbolID: "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        // public struct MyStruct {
        //     public func myStructFunction() { }
        //     public typealias MyStructTypeAlias = Int
        //     public var myStructProperty: MyStructTypeAlias { 0 }
        //     public static var myStructTypeProperty: MyStructTypeAlias { 0 }
        // }
        try assertFindsPath("/MixedFramework/MyStruct", in: tree, asSymbolID: "s:14MixedFramework8MyStructV")
        try assertFindsPath("/MixedFramework/MyStruct/myStructFunction()", in: tree, asSymbolID: "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        try assertFindsPath("/MixedFramework/MyStruct/MyStructTypeAlias", in: tree, asSymbolID: "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        try assertFindsPath("/MixedFramework/MyStruct/myStructProperty", in: tree, asSymbolID: "s:14MixedFramework8MyStructV02myD8PropertySivp")
        try assertFindsPath("/MixedFramework/MyStruct/myStructTypeProperty", in: tree, asSymbolID: "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        // @objc public class MyClass: NSObject {
        //     @objc public func myInstanceMethod() { }
        //     @nonobjc public func mySwiftOnlyInstanceMethod() { }
        //     public typealias MyClassTypeAlias = Int
        //     public var myInstanceProperty: MyClassTypeAlias { 0 }
        //     public static var myClassTypeProperty: MyClassTypeAlias { 0 }
        // }
        try assertFindsPath("/MixedFramework/MyClass", in: tree, asSymbolID: "c:@M@MixedFramework@objc(cs)MyClass")
        try assertFindsPath("/MixedFramework/MyClass/myInstanceMethod", in: tree, asSymbolID: "c:@M@MixedFramework@objc(cs)MyClass(im)myInstanceMethod")
        try assertFindsPath("/MixedFramework/MyClass/myInstanceMethod()", in: tree, asSymbolID: "c:@M@MixedFramework@objc(cs)MyClass(im)myInstanceMethod")
        try assertFindsPath("/MixedFramework/MyClass/mySwiftOnlyInstanceMethod()", in: tree, asSymbolID: "s:14MixedFramework7MyClassC25mySwiftOnlyInstanceMethodyyF")
        try assertPathNotFound("/MixedFramework/MyClass/mySwiftOnlyInstanceMethod", in: tree)
        try assertFindsPath("/MixedFramework/MyClass/MyClassTypeAlias", in: tree, asSymbolID: "s:14MixedFramework7MyClassC0cD9TypeAliasa")
        try assertFindsPath("/MixedFramework/MyClass/myInstanceProperty", in: tree, asSymbolID: "s:14MixedFramework7MyClassC18myInstancePropertySivp")
        try assertFindsPath("/MixedFramework/MyClass/myClassTypeProperty", in: tree, asSymbolID: "s:14MixedFramework7MyClassC02myD12TypePropertySivpZ")
        
        // @objc public protocol MyObjectiveCCompatibleProtocol {
        //     func myProtocolMethod()
        //     typealias MyProtocolTypeAlias = MyClass
        //     var myProtocolProperty: MyProtocolTypeAlias { get }
        //     static var myProtocolTypeProperty: MyProtocolTypeAlias { get }
        //     @objc optional func myPropertyOptionalMethod()
        // }
        try assertFindsPath("/MixedFramework/MyObjectiveCCompatibleProtocol", in: tree, asSymbolID: "c:@M@MixedFramework@objc(pl)MyObjectiveCCompatibleProtocol")
        try assertFindsPath("/MixedFramework/MyObjectiveCCompatibleProtocol/myProtocolMethod", in: tree, asSymbolID: "c:@M@MixedFramework@objc(pl)MyObjectiveCCompatibleProtocol(im)myProtocolMethod")
        try assertFindsPath("/MixedFramework/MyObjectiveCCompatibleProtocol/myProtocolMethod()", in: tree, asSymbolID: "c:@M@MixedFramework@objc(pl)MyObjectiveCCompatibleProtocol(im)myProtocolMethod")
        try assertFindsPath("/MixedFramework/MyObjectiveCCompatibleProtocol/myProtocolProperty", in: tree, asSymbolID: "c:@M@MixedFramework@objc(pl)MyObjectiveCCompatibleProtocol(py)myProtocolProperty")
        // Objective-C class properties have a "property" kind instead of a "type.property" kind (rdar://92927788)
        try assertFindsPath("/MixedFramework/MyObjectiveCCompatibleProtocol/myProtocolTypeProperty-type.property", in: tree, asSymbolID: "c:@M@MixedFramework@objc(pl)MyObjectiveCCompatibleProtocol(cpy)myProtocolTypeProperty")
        try assertFindsPath("/MixedFramework/MyObjectiveCCompatibleProtocol/myPropertyOptionalMethod", in: tree, asSymbolID: "c:@M@MixedFramework@objc(pl)MyObjectiveCCompatibleProtocol(im)myPropertyOptionalMethod")
        try assertFindsPath("/MixedFramework/MyObjectiveCCompatibleProtocol/myPropertyOptionalMethod()", in: tree, asSymbolID: "c:@M@MixedFramework@objc(pl)MyObjectiveCCompatibleProtocol(im)myPropertyOptionalMethod")
        
        // public protocol MySwiftProtocol {
        //     func myProtocolMethod()
        //     associatedtype MyProtocolAssociatedType
        //     typealias MyProtocolTypeAlias = MyStruct
        //     var myProtocolProperty: MyProtocolAssociatedType { get }
        //     static var myProtocolTypeProperty: MyProtocolAssociatedType { get }
        // }
        try assertFindsPath("/MixedFramework/MySwiftProtocol", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP")
        try assertFindsPath("/MixedFramework/MySwiftProtocol/myProtocolMethod()", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP02myE6MethodyyF")
        try assertFindsPath("/MixedFramework/MySwiftProtocol/MyProtocolAssociatedType", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP0cE14AssociatedTypeQa")
        try assertFindsPath("/MixedFramework/MySwiftProtocol/MyProtocolTypeAlias", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP0cE9TypeAliasa")
        try assertFindsPath("/MixedFramework/MySwiftProtocol/myProtocolProperty", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP02myE8Property0cE14AssociatedTypeQzvp")
        try assertFindsPath("/MixedFramework/MySwiftProtocol/myProtocolTypeProperty", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP02myE12TypeProperty0ce10AssociatedG0QzvpZ")
        
        // public typealias MyTypeAlias = MyStruct
        try assertFindsPath("/MixedFramework/MyTypeAlias", in: tree, asSymbolID: "s:14MixedFramework11MyTypeAliasa")
        
        // public func myTopLevelFunction() { }
        // public var myTopLevelVariable = true
        try assertFindsPath("/MixedFramework/myTopLevelFunction()", in: tree, asSymbolID: "s:14MixedFramework18myTopLevelFunctionyyF")
        try assertFindsPath("/MixedFramework/myTopLevelVariable", in: tree, asSymbolID: "s:14MixedFramework18myTopLevelVariableSbvp")
        
        // public protocol MyOtherProtocolThatConformToMySwiftProtocol: MySwiftProtocol {
        //     func myOtherProtocolMethod()
        // }
        try assertFindsPath("/MixedFramework/MyOtherProtocolThatConformToMySwiftProtocol", in: tree, asSymbolID: "s:14MixedFramework028MyOtherProtocolThatConformToc5SwiftE0P")
        try assertFindsPath("/MixedFramework/MyOtherProtocolThatConformToMySwiftProtocol/myOtherProtocolMethod()", in: tree, asSymbolID: "s:14MixedFramework028MyOtherProtocolThatConformToc5SwiftE0P02mydE6MethodyyF")
        
        // @objcMembers public class MyClassThatConformToMyOtherProtocol: NSObject, MyOtherProtocolThatConformToMySwiftProtocol {
        //     public func myOtherProtocolMethod() { }
        //     public func myProtocolMethod() { }
        //     public typealias MyProtocolAssociatedType = MyStruct
        //     public var myProtocolProperty: MyStruct { .init() }
        //     public class var myProtocolTypeProperty: MyStruct { .init() }
        // }
        try assertFindsPath("/MixedFramework/MyClassThatConformToMyOtherProtocol", in: tree, asSymbolID: "c:@M@MixedFramework@objc(cs)MyClassThatConformToMyOtherProtocol")
        try assertFindsPath("/MixedFramework/MyClassThatConformToMyOtherProtocol/myOtherProtocolMethod()", in: tree, asSymbolID: "c:@M@MixedFramework@objc(cs)MyClassThatConformToMyOtherProtocol(im)myOtherProtocolMethod")
        try assertFindsPath("/MixedFramework/MyClassThatConformToMyOtherProtocol/myOtherProtocolMethod", in: tree, asSymbolID: "c:@M@MixedFramework@objc(cs)MyClassThatConformToMyOtherProtocol(im)myOtherProtocolMethod")
        try assertFindsPath("/MixedFramework/MyClassThatConformToMyOtherProtocol/myProtocolMethod()", in: tree, asSymbolID: "c:@M@MixedFramework@objc(cs)MyClassThatConformToMyOtherProtocol(im)myProtocolMethod")
        try assertFindsPath("/MixedFramework/MyClassThatConformToMyOtherProtocol/myProtocolMethod", in: tree, asSymbolID: "c:@M@MixedFramework@objc(cs)MyClassThatConformToMyOtherProtocol(im)myProtocolMethod")
        try assertFindsPath("/MixedFramework/MyClassThatConformToMyOtherProtocol/MyProtocolAssociatedType", in: tree, asSymbolID: "s:14MixedFramework020MyClassThatConformToC13OtherProtocolC0cI14AssociatedTypea")
        try assertFindsPath("/MixedFramework/MyClassThatConformToMyOtherProtocol/myProtocolProperty", in: tree, asSymbolID: "s:14MixedFramework020MyClassThatConformToC13OtherProtocolC02myI8PropertyAA0C6StructVvp")
        try assertFindsPath("/MixedFramework/MyClassThatConformToMyOtherProtocol/myProtocolTypeProperty", in: tree, asSymbolID: "s:14MixedFramework020MyClassThatConformToC13OtherProtocolC02myI12TypePropertyAA0C6StructVvpZ")
        
        // public final class CollisionsWithDifferentCapitalization {
        //     public var something: Int = 0
        //     public var someThing: Int = 0
        // }
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentCapitalization", in: tree, asSymbolID: "s:14MixedFramework37CollisionsWithDifferentCapitalizationC")
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentCapitalization/something", in: tree, asSymbolID: "s:14MixedFramework37CollisionsWithDifferentCapitalizationC9somethingSivp")
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentCapitalization/someThing", in: tree, asSymbolID: "s:14MixedFramework37CollisionsWithDifferentCapitalizationC9someThingSivp")
        
        // public enum CollisionsWithDifferentKinds {
        //     case something
        //     public var something: String { "" }
        //     public typealias Something = Int
        // }
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentKinds", in: tree, asSymbolID: "s:14MixedFramework28CollisionsWithDifferentKindsO")
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentKinds/something-enum.case", in: tree, asSymbolID: "s:14MixedFramework28CollisionsWithDifferentKindsO9somethingyA2CmF")
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentKinds/something-property", in: tree, asSymbolID: "s:14MixedFramework28CollisionsWithDifferentKindsO9somethingSSvp")
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentKinds/Something", in: tree, asSymbolID: "s:14MixedFramework28CollisionsWithDifferentKindsO9Somethinga")
        
        // public final class CollisionsWithEscapedKeywords {
        //     public subscript() -> Int { 0 }
        //     public func `subscript`() { }
        //     public static func `subscript`() { }
        //
        //     public init() { }
        //     public func `init`() { }
        //     public static func `init`() { }
        // }
        try assertFindsPath("/MixedFramework/CollisionsWithEscapedKeywords", in: tree, asSymbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsC")
        try assertFindsPath("/MixedFramework/CollisionsWithEscapedKeywords/init()-init", in: tree, asSymbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsCACycfc")
        try assertFindsPath("/MixedFramework/CollisionsWithEscapedKeywords/init()-method", in: tree, asSymbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsC4inityyF")
        try assertFindsPath("/MixedFramework/CollisionsWithEscapedKeywords/init()-type.method", in: tree, asSymbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsC4inityyFZ")
        try assertFindsPath("/MixedFramework/CollisionsWithEscapedKeywords/subscript()-subscript", in: tree, asSymbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsCSiycip")
        try assertFindsPath("/MixedFramework/CollisionsWithEscapedKeywords/subscript()-method", in: tree, asSymbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsC9subscriptyyF")
        try assertFindsPath("/MixedFramework/CollisionsWithEscapedKeywords/subscript()-type.method", in: tree, asSymbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsC9subscriptyyFZ")
        
        // public enum CollisionsWithDifferentFunctionArguments {
        //     public func something(argument: Int) -> Int { 0 }
        //     public func something(argument: String) -> Int { 0 }
        // }
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentFunctionArguments", in: tree, asSymbolID: "s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO")
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)-1cyvp", in: tree, asSymbolID: "s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentS2i_tF")
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)-2vke2", in: tree, asSymbolID: "s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentSiSS_tF")
        
        // public enum CollisionsWithDifferentSubscriptArguments {
        //     public subscript(something: Int) -> Int { 0 }
        //     public subscript(somethingElse: String) -> Int { 0 }
        // }
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentSubscriptArguments", in: tree, asSymbolID: "s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsO")
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)-4fd0l", in: tree, asSymbolID: "s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOyS2icip")
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)-757cj", in: tree, asSymbolID: "s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOySiSScip")
        
        // @objc(MySwiftClassObjectiveCName)
        // public class MySwiftClassSwiftName: NSObject {
        //     @objc(myPropertyObjectiveCName)
        //     public var myPropertySwiftName: Int { 0 }
        //
        //     @objc(myMethodObjectiveCName)
        //     public func myMethodSwiftName() -> Int { 0 }
        // }
        try assertFindsPath("/MixedFramework/MySwiftClassSwiftName", in: tree, asSymbolID: "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName")
        try assertFindsPath("/MixedFramework/MySwiftClassSwiftName/myPropertySwiftName", in: tree, asSymbolID: "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(py)myPropertyObjectiveCName")
        try assertFindsPath("/MixedFramework/MySwiftClassSwiftName/myMethodSwiftName()", in: tree, asSymbolID: "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(im)myMethodObjectiveCName")
        try assertPathNotFound("/MixedFramework/MySwiftClassObjectiveCName/myPropertySwiftName", in: tree)
        try assertPathNotFound("/MixedFramework/MySwiftClassObjectiveCName/myMethodSwiftName()", in: tree)
        
        try assertFindsPath("/MixedFramework/MySwiftClassObjectiveCName", in: tree, asSymbolID: "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName")
        try assertFindsPath("/MixedFramework/MySwiftClassObjectiveCName/myPropertyObjectiveCName", in: tree, asSymbolID: "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(py)myPropertyObjectiveCName")
        try assertFindsPath("/MixedFramework/MySwiftClassObjectiveCName/myMethodObjectiveCName", in: tree, asSymbolID: "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(im)myMethodObjectiveCName")
        try assertPathNotFound("/MixedFramework/MySwiftClassSwiftName/myPropertyObjectiveCName", in: tree)
        try assertPathNotFound("/MixedFramework/MySwiftClassSwiftName/myMethoObjectiveCName", in: tree)
        
        // NS_SWIFT_NAME(MyObjectiveCClassSwiftName)
        // @interface MyObjectiveCClassObjectiveCName : NSObject
        //
        // @property (copy, readonly) NSString * myPropertyObjectiveCName NS_SWIFT_NAME(myPropertySwiftName);
        //
        // - (void)myMethodObjectiveCName NS_SWIFT_NAME(myMethodSwiftName());
        // - (void)myMethodWithArgument:(NSString *)argument NS_SWIFT_NAME(myMethod(argument:));
        //
        // @end
        try assertFindsPath("/MixedFramework/MyObjectiveCClassSwiftName", in: tree, asSymbolID: "c:objc(cs)MyObjectiveCClassObjectiveCName")
        try assertFindsPath("/MixedFramework/MyObjectiveCClassSwiftName/myPropertySwiftName", in: tree, asSymbolID: "c:objc(cs)MyObjectiveCClassObjectiveCName(py)myPropertyObjectiveCName")
        try assertFindsPath("/MixedFramework/MyObjectiveCClassSwiftName/myMethodSwiftName()", in: tree, asSymbolID: "c:objc(cs)MyObjectiveCClassObjectiveCName(im)myMethodObjectiveCName")
        try assertFindsPath("/MixedFramework/MyObjectiveCClassSwiftName/myMethod(argument:)", in: tree, asSymbolID: "c:objc(cs)MyObjectiveCClassObjectiveCName(im)myMethodWithArgument:")
        
        try assertFindsPath("/MixedFramework/MyObjectiveCClassObjectiveCName", in: tree, asSymbolID: "c:objc(cs)MyObjectiveCClassObjectiveCName")
        try assertFindsPath("/MixedFramework/MyObjectiveCClassObjectiveCName/myPropertyObjectiveCName", in: tree, asSymbolID: "c:objc(cs)MyObjectiveCClassObjectiveCName(py)myPropertyObjectiveCName")
        try assertFindsPath("/MixedFramework/MyObjectiveCClassObjectiveCName/myMethodObjectiveCName", in: tree, asSymbolID: "c:objc(cs)MyObjectiveCClassObjectiveCName(im)myMethodObjectiveCName")
        try assertFindsPath("/MixedFramework/MyObjectiveCClassObjectiveCName/myMethodWithArgument:", in: tree, asSymbolID: "c:objc(cs)MyObjectiveCClassObjectiveCName(im)myMethodWithArgument:")
        
        // typedef NS_ENUM(NSInteger, MyObjectiveCEnum) {
        //     MyObjectiveCEnumFirst,
        //     MyObjectiveCEnumSecond NS_SWIFT_NAME(secondCaseSwiftName)
        // };
        try assertFindsPath("/MixedFramework/MyObjectiveCEnum", in: tree, asSymbolID: "c:@E@MyObjectiveCEnum")
        try assertFindsPath("/MixedFramework/MyObjectiveCEnum/MyObjectiveCEnumFirst", in: tree, asSymbolID: "c:@E@MyObjectiveCEnum@MyObjectiveCEnumFirst")
        try assertFindsPath("/MixedFramework/MyObjectiveCEnum/first", in: tree, asSymbolID: "c:@E@MyObjectiveCEnum@MyObjectiveCEnumFirst")
        try assertFindsPath("/MixedFramework/MyObjectiveCEnum/MyObjectiveCEnumSecond", in: tree, asSymbolID: "c:@E@MyObjectiveCEnum@MyObjectiveCEnumSecond")
        try assertFindsPath("/MixedFramework/MyObjectiveCEnum/secondCaseSwiftName", in: tree, asSymbolID: "c:@E@MyObjectiveCEnum@MyObjectiveCEnumSecond")
        
        // typedef NS_ENUM(NSInteger, MyObjectiveCEnumObjectiveCName) {
        //     MyObjectiveCEnumObjectiveCNameFirst,
        //     MyObjectiveCEnumObjectiveCNameSecond NS_SWIFT_NAME(secondCaseSwiftName)
        // } NS_SWIFT_NAME(MyObjectiveCEnumSwiftName);
        try assertFindsPath("/MixedFramework/MyObjectiveCEnumObjectiveCName", in: tree, asSymbolID: "c:@E@MyObjectiveCEnumObjectiveCName")
        try assertFindsPath("/MixedFramework/MyObjectiveCEnumObjectiveCName/MyObjectiveCEnumObjectiveCNameFirst", in: tree, asSymbolID: "c:@E@MyObjectiveCEnumObjectiveCName@MyObjectiveCEnumObjectiveCNameFirst")
        try assertFindsPath("/MixedFramework/MyObjectiveCEnumObjectiveCName/MyObjectiveCEnumObjectiveCNameSecond", in: tree, asSymbolID: "c:@E@MyObjectiveCEnumObjectiveCName@MyObjectiveCEnumObjectiveCNameSecond")
        try assertPathNotFound("/MixedFramework/MyObjectiveCEnumObjectiveCName/first", in: tree)
        try assertPathNotFound("/MixedFramework/MyObjectiveCEnumObjectiveCName/secondCaseSwiftName", in: tree)
        
        try assertFindsPath("/MixedFramework/MyObjectiveCEnumSwiftName", in: tree, asSymbolID: "c:@E@MyObjectiveCEnumObjectiveCName")
        try assertFindsPath("/MixedFramework/MyObjectiveCEnumSwiftName/first", in: tree, asSymbolID: "c:@E@MyObjectiveCEnumObjectiveCName@MyObjectiveCEnumObjectiveCNameFirst")
        try assertFindsPath("/MixedFramework/MyObjectiveCEnumSwiftName/secondCaseSwiftName", in: tree, asSymbolID: "c:@E@MyObjectiveCEnumObjectiveCName@MyObjectiveCEnumObjectiveCNameSecond")
        try assertPathNotFound("/MixedFramework/MyObjectiveCEnumSwiftName/MyObjectiveCEnumObjectiveCNameFirst", in: tree)
        try assertPathNotFound("/MixedFramework/MyObjectiveCEnumSwiftName/MyObjectiveCEnumObjectiveCNameSecond", in: tree)
        
        // typedef NS_OPTIONS(NSInteger, MyObjectiveCOption) {
        //     MyObjectiveCOptionNone                                      = 0,
        //     MyObjectiveCOptionFirst                                     = 1 << 0,
        //     MyObjectiveCOptionSecond NS_SWIFT_NAME(secondCaseSwiftName) = 1 << 1
        // };
        try assertFindsPath("/MixedFramework/MyObjectiveCOption-enum", in: tree, asSymbolID: "c:@E@MyObjectiveCOption")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption-enum/MyObjectiveCOptionNone", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionNone")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption-enum/MyObjectiveCOptionFirst", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption-enum/MyObjectiveCOptionSecond", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        
        try assertFindsPath("/MixedFramework/MyObjectiveCOption-struct", in: tree, asSymbolID: "c:@E@MyObjectiveCOption")
        try assertPathNotFound("/MixedFramework/MyObjectiveCOption-struct/MyObjectiveCOptionNone", in: tree)
        try assertPathNotFound("/MixedFramework/MyObjectiveCOption-struct/none", in: tree)
        try assertFindsPath("/MixedFramework/MyObjectiveCOption-struct/first", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption-struct/secondCaseSwiftName", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        
        // typedef NSInteger MyTypedObjectiveCEnum NS_TYPED_ENUM;
        //
        // MyTypedObjectiveCEnum const MyTypedObjectiveCEnumFirst;
        // MyTypedObjectiveCEnum const MyTypedObjectiveCEnumSecond;
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnum-struct", in: tree, asSymbolID: "c:ObjectiveCDeclarations.h@T@MyTypedObjectiveCEnum")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnum-struct/first", in: tree, asSymbolID: "c:@MyTypedObjectiveCEnumFirst")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnum-struct/second", in: tree, asSymbolID: "c:@MyTypedObjectiveCEnumSecond")
        
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnum-typealias", in: tree, asSymbolID: "c:ObjectiveCDeclarations.h@T@MyTypedObjectiveCEnum")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnumFirst", in: tree, asSymbolID: "c:@MyTypedObjectiveCEnumFirst")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnumSecond", in: tree, asSymbolID: "c:@MyTypedObjectiveCEnumSecond")
        
        // typedef NSInteger MyTypedObjectiveCExtensibleEnum NS_TYPED_EXTENSIBLE_ENUM;
        //
        // MyTypedObjectiveCExtensibleEnum const MyTypedObjectiveCExtensibleEnumFirst;
        // MyTypedObjectiveCExtensibleEnum const MyTypedObjectiveCExtensibleEnumSecond;
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnum-struct", in: tree, asSymbolID: "c:ObjectiveCDeclarations.h@T@MyTypedObjectiveCExtensibleEnum")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnum-struct/first", in: tree, asSymbolID: "c:@MyTypedObjectiveCExtensibleEnumFirst")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnum-struct/second", in: tree, asSymbolID: "c:@MyTypedObjectiveCExtensibleEnumSecond")
        
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnum-typealias", in: tree, asSymbolID: "c:ObjectiveCDeclarations.h@T@MyTypedObjectiveCExtensibleEnum")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnumFirst", in: tree, asSymbolID: "c:@MyTypedObjectiveCExtensibleEnumFirst")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnumSecond", in: tree, asSymbolID: "c:@MyTypedObjectiveCExtensibleEnumSecond")
    }
    
    func testAmbiguousPaths() throws {
        // public enum CollisionsWithDifferentKinds {
        //     case something
        //     public var something: String { "" }
        //     public typealias Something = Int
        // }
        try assertPathCollision("/MixedFramework/CollisionsWithDifferentKinds/something", in: tree, collisions: [
            (symbolID: "s:14MixedFramework28CollisionsWithDifferentKindsO9somethingyA2CmF", disambiguation: "enum.case"),
            (symbolID: "s:14MixedFramework28CollisionsWithDifferentKindsO9somethingSSvp", disambiguation: "property"),
        ])
        
        // public final class CollisionsWithEscapedKeywords {
        //     public subscript() -> Int { 0 }
        //     public func `subscript`() { }
        //     public static func `subscript`() { }
        //
        //     public init() { }
        //     public func `init`() { }
        //     public static func `init`() { }
        // }
        try assertPathCollision("/MixedFramework/CollisionsWithEscapedKeywords/init()", in: tree, collisions: [
            (symbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsCACycfc", disambiguation: "init"),
            (symbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsC4inityyF", disambiguation: "method"),
            (symbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsC4inityyFZ", disambiguation: "type.method"),
        ])
        
        try assertPathCollision("/MixedFramework/CollisionsWithEscapedKeywords/subscript()", in: tree, collisions: [
            (symbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsC9subscriptyyF", disambiguation: "method"),
            (symbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsCSiycip", disambiguation: "subscript"),
            (symbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsC9subscriptyyFZ", disambiguation: "type.method"),
        ])
        
        // public enum CollisionsWithDifferentFunctionArguments {
        //     public func something(argument: Int) -> Int { 0 }
        //     public func something(argument: String) -> Int { 0 }
        // }
        try assertPathCollision("/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)", in: tree, collisions: [
            (symbolID: "s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentS2i_tF", disambiguation: "1cyvp"),
            (symbolID: "s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentSiSS_tF", disambiguation: "2vke2"),
        ])
        
        // public enum CollisionsWithDifferentSubscriptArguments {
        //     public subscript(something: Int) -> Int { 0 }
        //     public subscript(somethingElse: String) -> Int { 0 }
        // }
        try assertPathCollision("/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)", in: tree, collisions: [
            (symbolID: "s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOyS2icip", disambiguation: "4fd0l"),
            (symbolID: "s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOySiSScip", disambiguation: "757cj"),
        ])
        
        // typedef NS_OPTIONS(NSInteger, MyObjectiveCOption) {
        //     MyObjectiveCOptionNone                                      = 0,
        //     MyObjectiveCOptionFirst                                     = 1 << 0,
        //     MyObjectiveCOptionSecond NS_SWIFT_NAME(secondCaseSwiftName) = 1 << 1
        // };
        try assertPathCollision("/MixedFramework/MyObjectiveCOption", in: tree, collisions: [
            (symbolID: "c:@E@MyObjectiveCOption", disambiguation: "enum"),
            (symbolID: "c:@E@MyObjectiveCOption", disambiguation: "struct"),
        ])
        // MyObjectiveCOption is ambiguous but the two collisions can be can be disambiguated by checking their children
        try assertFindsPath("/MixedFramework/MyObjectiveCOption/MyObjectiveCOptionNone", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionNone")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption/MyObjectiveCOptionFirst", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption/MyObjectiveCOptionSecond", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        
        try assertFindsPath("/MixedFramework/MyObjectiveCOption/first", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption/secondCaseSwiftName", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        
        // typedef NSInteger MyTypedObjectiveCEnum NS_TYPED_ENUM;
        //
        // MyTypedObjectiveCEnum const MyTypedObjectiveCEnumFirst;
        // MyTypedObjectiveCEnum const MyTypedObjectiveCEnumSecond;
        try assertPathCollision("/MixedFramework/MyTypedObjectiveCEnum", in: tree, collisions: [
            (symbolID: "c:ObjectiveCDeclarations.h@T@MyTypedObjectiveCEnum", disambiguation: "struct"),
            (symbolID: "c:ObjectiveCDeclarations.h@T@MyTypedObjectiveCEnum", disambiguation: "typealias"),
        ])
        // MyTypedObjectiveCEnum is ambiguous but the two collisions can be can be disambiguated by checking their children
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnum/first", in: tree, asSymbolID: "c:@MyTypedObjectiveCEnumFirst")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnum/second", in: tree, asSymbolID: "c:@MyTypedObjectiveCEnumSecond")
        
        // typedef NSInteger MyTypedObjectiveCExtensibleEnum NS_TYPED_EXTENSIBLE_ENUM;
        //
        // MyTypedObjectiveCExtensibleEnum const MyTypedObjectiveCExtensibleEnumFirst;
        // MyTypedObjectiveCExtensibleEnum const MyTypedObjectiveCExtensibleEnumSecond;
        try assertPathCollision("/MixedFramework/MyTypedObjectiveCExtensibleEnum", in: tree, collisions: [
            (symbolID: "c:ObjectiveCDeclarations.h@T@MyTypedObjectiveCExtensibleEnum", disambiguation: "struct"),
            (symbolID: "c:ObjectiveCDeclarations.h@T@MyTypedObjectiveCExtensibleEnum", disambiguation: "typealias"),
        ])
        // MyTypedObjectiveCExtensibleEnum is ambiguous but the two collisions can be can be disambiguated by checking their children
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnum/first", in: tree, asSymbolID: "c:@MyTypedObjectiveCExtensibleEnumFirst")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnum/second", in: tree, asSymbolID: "c:@MyTypedObjectiveCExtensibleEnumSecond")
    }
    
    func testRedundantKindDisambiguation() throws {
        try assertFindsPath("/MixedFramework-module", in: tree, asSymbolID: "MixedFramework")
        
        // @objc public enum MyEnum: Int {
        //     case firstCase
        //     case secondCase
        //     public func myEnumFunction() { }
        //     public typealias MyEnumTypeAlias = Int
        //     public var myEnumProperty: MyEnumTypeAlias { 0 }
        // }
        try assertFindsPath("/MixedFramework-module/MyEnum-enum", in: tree, asSymbolID: "c:@M@MixedFramework@E@MyEnum")
        try assertFindsPath("/MixedFramework-module/MyEnum-enum/firstCase-enum.case", in: tree, asSymbolID: "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        try assertFindsPath("/MixedFramework-module/MyEnum-enum/secondCase-enum.case", in: tree, asSymbolID: "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        try assertFindsPath("/MixedFramework-module/MyEnum-enum/myEnumFunction()-method", in: tree, asSymbolID: "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        try assertFindsPath("/MixedFramework-module/MyEnum-enum/MyEnumTypeAlias-typealias", in: tree, asSymbolID: "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        try assertFindsPath("/MixedFramework-module/MyEnum-enum/myEnumProperty-property", in: tree, asSymbolID: "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        // public struct MyStruct {
        //     public func myStructFunction() { }
        //     public typealias MyStructTypeAlias = Int
        //     public var myStructProperty: MyStructTypeAlias { 0 }
        //     public static var myStructTypeProperty: MyStructTypeAlias { 0 }
        // }
        try assertFindsPath("/MixedFramework-module/MyStruct-struct", in: tree, asSymbolID: "s:14MixedFramework8MyStructV")
        try assertFindsPath("/MixedFramework-module/MyStruct-struct/myStructFunction()-method", in: tree, asSymbolID: "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        try assertFindsPath("/MixedFramework-module/MyStruct-struct/MyStructTypeAlias-typealias", in: tree, asSymbolID: "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        try assertFindsPath("/MixedFramework-module/MyStruct-struct/myStructProperty-property", in: tree, asSymbolID: "s:14MixedFramework8MyStructV02myD8PropertySivp")
        try assertFindsPath("/MixedFramework-module/MyStruct-struct/myStructTypeProperty-type.property", in: tree, asSymbolID: "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        // public protocol MySwiftProtocol {
        //     func myProtocolMethod()
        //     associatedtype MyProtocolAssociatedType
        //     typealias MyProtocolTypeAlias = MyStruct
        //     var myProtocolProperty: MyProtocolAssociatedType { get }
        //     static var myProtocolTypeProperty: MyProtocolAssociatedType { get }
        // }
        try assertFindsPath("/MixedFramework-module/MySwiftProtocol-protocol", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP")
        try assertFindsPath("/MixedFramework-module/MySwiftProtocol-protocol/myProtocolMethod()-method", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP02myE6MethodyyF")
        try assertFindsPath("/MixedFramework-module/MySwiftProtocol-protocol/MyProtocolAssociatedType-associatedtype", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP0cE14AssociatedTypeQa")
        try assertFindsPath("/MixedFramework-module/MySwiftProtocol-protocol/MyProtocolTypeAlias-typealias", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP0cE9TypeAliasa")
        try assertFindsPath("/MixedFramework-module/MySwiftProtocol-protocol/myProtocolProperty-property", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP02myE8Property0cE14AssociatedTypeQzvp")
        try assertFindsPath("/MixedFramework-module/MySwiftProtocol-protocol/myProtocolTypeProperty-type.property", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP02myE12TypeProperty0ce10AssociatedG0QzvpZ")
        
        // public func myTopLevelFunction() { }
        // public var myTopLevelVariable = true
        try assertFindsPath("/MixedFramework/myTopLevelFunction()-func", in: tree, asSymbolID: "s:14MixedFramework18myTopLevelFunctionyyF")
        try assertFindsPath("/MixedFramework/myTopLevelVariable-var", in: tree, asSymbolID: "s:14MixedFramework18myTopLevelVariableSbvp")
    }
    
    func testBothRedundantDisambiguations() throws {
        try assertFindsPath("/MixedFramework-module-9r7pl", in: tree, asSymbolID: "MixedFramework")
        
        // @objc public enum MyEnum: Int {
        //     case firstCase
        //     case secondCase
        //     public func myEnumFunction() { }
        //     public typealias MyEnumTypeAlias = Int
        //     public var myEnumProperty: MyEnumTypeAlias { 0 }
        // }
        try assertFindsPath("/MixedFramework-module-9r7pl/MyEnum-enum-1m96o", in: tree, asSymbolID: "c:@M@MixedFramework@E@MyEnum")
        try assertFindsPath("/MixedFramework-module-9r7pl/MyEnum-enum-1m96o/firstCase-enum.case-5ocr4", in: tree, asSymbolID: "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        try assertFindsPath("/MixedFramework-module-9r7pl/MyEnum-enum-1m96o/secondCase-enum.case-ihyt", in: tree, asSymbolID: "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        try assertFindsPath("/MixedFramework-module-9r7pl/MyEnum-enum-1m96o/myEnumFunction()-method-2pa9q", in: tree, asSymbolID: "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        try assertFindsPath("/MixedFramework-module-9r7pl/MyEnum-enum-1m96o/MyEnumTypeAlias-typealias-5ejt4", in: tree, asSymbolID: "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        try assertFindsPath("/MixedFramework-module-9r7pl/MyEnum-enum-1m96o/myEnumProperty-property-6cz2q", in: tree, asSymbolID: "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        // public struct MyStruct {
        //     public func myStructFunction() { }
        //     public typealias MyStructTypeAlias = Int
        //     public var myStructProperty: MyStructTypeAlias { 0 }
        //     public static var myStructTypeProperty: MyStructTypeAlias { 0 }
        // }
        try assertFindsPath("/MixedFramework-module-9r7pl/MyStruct-struct-23xcd", in: tree, asSymbolID: "s:14MixedFramework8MyStructV")
        try assertFindsPath("/MixedFramework-module-9r7pl/MyStruct-struct-23xcd/myStructFunction()-method-9p92r", in: tree, asSymbolID: "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        try assertFindsPath("/MixedFramework-module-9r7pl/MyStruct-struct-23xcd/MyStructTypeAlias-typealias-630hf", in: tree, asSymbolID: "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        try assertFindsPath("/MixedFramework-module-9r7pl/MyStruct-struct-23xcd/myStructProperty-property-5ywbx", in: tree, asSymbolID: "s:14MixedFramework8MyStructV02myD8PropertySivp")
        try assertFindsPath("/MixedFramework-module-9r7pl/MyStruct-struct-23xcd/myStructTypeProperty-type.property-8ti6m", in: tree, asSymbolID: "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        // public protocol MySwiftProtocol {
        //     func myProtocolMethod()
        //     associatedtype MyProtocolAssociatedType
        //     typealias MyProtocolTypeAlias = MyStruct
        //     var myProtocolProperty: MyProtocolAssociatedType { get }
        //     static var myProtocolTypeProperty: MyProtocolAssociatedType { get }
        // }
        try assertFindsPath("/MixedFramework-module-9r7pl/MySwiftProtocol-protocol-xmee", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP")
        try assertFindsPath("/MixedFramework-module-9r7pl/MySwiftProtocol-protocol-xmee/myProtocolMethod()-method-6srz6", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP02myE6MethodyyF")
        try assertFindsPath("/MixedFramework-module-9r7pl/MySwiftProtocol-protocol-xmee/MyProtocolAssociatedType-associatedtype-33siz", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP0cE14AssociatedTypeQa")
        try assertFindsPath("/MixedFramework-module-9r7pl/MySwiftProtocol-protocol-xmee/MyProtocolTypeAlias-typealias-9rpv6", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP0cE9TypeAliasa")
        try assertFindsPath("/MixedFramework-module-9r7pl/MySwiftProtocol-protocol-xmee/myProtocolProperty-property-qer2", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP02myE8Property0cE14AssociatedTypeQzvp")
        try assertFindsPath("/MixedFramework-module-9r7pl/MySwiftProtocol-protocol-xmee/myProtocolTypeProperty-type.property-8h7hm", in: tree, asSymbolID: "s:14MixedFramework15MySwiftProtocolP02myE12TypeProperty0ce10AssociatedG0QzvpZ")
        
        // public func myTopLevelFunction() { }
        // public var myTopLevelVariable = true
        try assertFindsPath("/MixedFramework-module-9r7pl/myTopLevelFunction()-func-55lhl", in: tree, asSymbolID: "s:14MixedFramework18myTopLevelFunctionyyF")
        try assertFindsPath("/MixedFramework-module-9r7pl/myTopLevelVariable-var-520ez", in: tree, asSymbolID: "s:14MixedFramework18myTopLevelVariableSbvp")
    }
    
    func testDisambiguatedPaths() throws {
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        print(tree.dump())
        // @objc public enum MyEnum: Int {
        //     case firstCase
        //     case secondCase
        //     public func myEnumFunction() { }
        //     public typealias MyEnumTypeAlias = Int
        //     public var myEnumProperty: MyEnumTypeAlias { 0 }
        // }
        XCTAssertEqual(
            paths["c:@M@MixedFramework@E@MyEnum"],
            "/MixedFramework/MyEnum")
        XCTAssertEqual(
            paths["s:SQsE2neoiySbx_xtFZ::SYNTHESIZED::c:@M@MixedFramework@E@MyEnum"],
            "/MixedFramework/MyEnum/!=(_:_:)")
        XCTAssertEqual(
            paths["c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase"],
            "/MixedFramework/MyEnum/firstCase")
        XCTAssertEqual(
            paths["s:SYsSHRzSH8RawValueSYRpzrlE4hash4intoys6HasherVz_tF::SYNTHESIZED::c:@M@MixedFramework@E@MyEnum"],
            "/MixedFramework/MyEnum/hash(into:)")
        XCTAssertEqual(
            paths["s:SYsSHRzSH8RawValueSYRpzrlE04hashB0Sivp::SYNTHESIZED::c:@M@MixedFramework@E@MyEnum"],
            "/MixedFramework/MyEnum/hashValue")
        XCTAssertEqual(
            paths["s:14MixedFramework6MyEnumO8rawValueACSgSi_tcfc"],
            "/MixedFramework/MyEnum/init(rawValue:)")
        XCTAssertEqual(
            paths["s:14MixedFramework6MyEnumO02myD8FunctionyyF"],
            "/MixedFramework/MyEnum/myEnumFunction()")
        XCTAssertEqual(
            paths["s:14MixedFramework6MyEnumO02myD8PropertySivp"],
            "/MixedFramework/MyEnum/myEnumProperty")
        XCTAssertEqual(
            paths["c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase"],
            "/MixedFramework/MyEnum/secondCase")
        XCTAssertEqual(
            paths["s:14MixedFramework6MyEnumO0cD9TypeAliasa"],
            "/MixedFramework/MyEnum/MyEnumTypeAlias")
        
        // public final class CollisionsWithDifferentCapitalization {
        //     public var something: Int = 0
        //     public var someThing: Int = 0
        // }
        XCTAssertEqual(
            paths["s:14MixedFramework37CollisionsWithDifferentCapitalizationC9somethingSivp"],
            "/MixedFramework/CollisionsWithDifferentCapitalization/something-2c4k6")
        XCTAssertEqual(
            paths["s:14MixedFramework37CollisionsWithDifferentCapitalizationC9someThingSivp"],
            "/MixedFramework/CollisionsWithDifferentCapitalization/someThing-90i4h")
        
        // public enum CollisionsWithDifferentKinds {
        //     case something
        //     public var something: String { "" }
        //     public typealias Something = Int
        // }
        XCTAssertEqual(
            paths["s:14MixedFramework28CollisionsWithDifferentKindsO9somethingyA2CmF"],
            "/MixedFramework/CollisionsWithDifferentKinds/something-enum.case")
        XCTAssertEqual(
            paths["s:14MixedFramework28CollisionsWithDifferentKindsO9somethingSSvp"],
            "/MixedFramework/CollisionsWithDifferentKinds/something-property")
        XCTAssertEqual(
            paths["s:14MixedFramework28CollisionsWithDifferentKindsO9Somethinga"],
            "/MixedFramework/CollisionsWithDifferentKinds/Something-typealias")
        
        // public final class CollisionsWithEscapedKeywords {
        //     public subscript() -> Int { 0 }
        //     public func `subscript`() { }
        //     public static func `subscript`() { }
        //
        //     public init() { }
        //     public func `init`() { }
        //     public static func `init`() { }
        // }
        XCTAssertEqual(
            paths["s:14MixedFramework29CollisionsWithEscapedKeywordsC9subscriptyyF"],
            "/MixedFramework/CollisionsWithEscapedKeywords/subscript()-method")
        XCTAssertEqual(
            paths["s:14MixedFramework29CollisionsWithEscapedKeywordsCSiycip"],
            "/MixedFramework/CollisionsWithEscapedKeywords/subscript()-subscript")
        XCTAssertEqual(
            paths["s:14MixedFramework29CollisionsWithEscapedKeywordsC9subscriptyyFZ"],
            "/MixedFramework/CollisionsWithEscapedKeywords/subscript()-type.method")
        
        XCTAssertEqual(
            paths["s:14MixedFramework29CollisionsWithEscapedKeywordsCACycfc"],
            "/MixedFramework/CollisionsWithEscapedKeywords/init()-init")
        XCTAssertEqual(
            paths["s:14MixedFramework29CollisionsWithEscapedKeywordsC4inityyF"],
            "/MixedFramework/CollisionsWithEscapedKeywords/init()-method")
        XCTAssertEqual(
            paths["s:14MixedFramework29CollisionsWithEscapedKeywordsC4inityyFZ"],
            "/MixedFramework/CollisionsWithEscapedKeywords/init()-type.method")
        
        // public enum CollisionsWithDifferentFunctionArguments {
        //     public func something(argument: Int) -> Int { 0 }
        //     public func something(argument: String) -> Int { 0 }
        // }
        XCTAssertEqual(
            paths["s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentS2i_tF"],
            "/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)-1cyvp")
        XCTAssertEqual(
            paths["s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentSiSS_tF"],
            "/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)-2vke2")
        
        // public enum CollisionsWithDifferentSubscriptArguments {
        //     public subscript(something: Int) -> Int { 0 }
        //     public subscript(somethingElse: String) -> Int { 0 }
        // }
        XCTAssertEqual(
            paths["s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOyS2icip"],
            "/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)-4fd0l")
        XCTAssertEqual(
            paths["s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOySiSScip"],
            "/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)-757cj")
    }
    
    func testFindingRelativePaths() throws {
        let moduleNode = try tree.findNode(path: "/MixedFramework")
        
        // @objc public enum MyEnum: Int {
        //     case firstCase
        //     case secondCase
        //     public func myEnumFunction() { }
        //     public typealias MyEnumTypeAlias = Int
        //     public var myEnumProperty: MyEnumTypeAlias { 0 }
        // }
        //
        // public struct MyStruct {
        //     public func myStructFunction() { }
        //     public typealias MyStructTypeAlias = Int
        //     public var myStructProperty: MyStructTypeAlias { 0 }
        //     public static var myStructTypeProperty: MyStructTypeAlias { 0 }
        // }
        let myEnumNode = try tree.findNode(path: "MyEnum", parent: moduleNode.identifier)
        XCTAssertEqual(try tree.find(path: "firstCase", parent: myEnumNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        XCTAssertEqual(try tree.find(path: "secondCase", parent: myEnumNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        XCTAssertEqual(try tree.find(path: "myEnumFunction()", parent: myEnumNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        XCTAssertEqual(try tree.find(path: "MyEnumTypeAlias", parent: myEnumNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        XCTAssertEqual(try tree.find(path: "myEnumProperty", parent: myEnumNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        let myStructNode = try tree.findNode(path: "MyStruct", parent: moduleNode.identifier)
        XCTAssertEqual(try tree.find(path: "myStructFunction()", parent: myStructNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        XCTAssertEqual(try tree.find(path: "MyStructTypeAlias", parent: myStructNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        XCTAssertEqual(try tree.find(path: "myStructProperty", parent: myStructNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD8PropertySivp")
        XCTAssertEqual(try tree.find(path: "myStructTypeProperty", parent: myStructNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        // Resolve symbols with the same parent
        let myFirstCaseNode = try tree.findNode(path: "firstCase", parent: myEnumNode.identifier)
        XCTAssertEqual(try tree.find(path: "firstCase", parent: myFirstCaseNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        XCTAssertEqual(try tree.find(path: "secondCase", parent: myFirstCaseNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        XCTAssertEqual(try tree.find(path: "myEnumFunction()", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        XCTAssertEqual(try tree.find(path: "MyEnumTypeAlias", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        XCTAssertEqual(try tree.find(path: "myEnumProperty", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        let myStructFunctionNode = try tree.findNode(path: "myStructFunction()", parent: myStructNode.identifier)
        XCTAssertEqual(try tree.find(path: "myStructFunction()", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        XCTAssertEqual(try tree.find(path: "MyStructTypeAlias", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        XCTAssertEqual(try tree.find(path: "myStructProperty", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD8PropertySivp")
        XCTAssertEqual(try tree.find(path: "myStructTypeProperty", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        // Resolve symbols accessible from the parent's parent
        XCTAssertEqual(try tree.find(path: "MyEnum", parent: myFirstCaseNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        XCTAssertEqual(try tree.find(path: "MyEnum/firstCase", parent: myFirstCaseNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        XCTAssertEqual(try tree.find(path: "MyEnum/secondCase", parent: myFirstCaseNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        XCTAssertEqual(try tree.find(path: "MyEnum/myEnumFunction()", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        XCTAssertEqual(try tree.find(path: "MyEnum/MyEnumTypeAlias", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        XCTAssertEqual(try tree.find(path: "MyEnum/myEnumProperty", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        XCTAssertEqual(try tree.find(path: "MyStruct", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV")
        XCTAssertEqual(try tree.find(path: "MyStruct/myStructFunction()", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        XCTAssertEqual(try tree.find(path: "MyStruct/MyStructTypeAlias", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        XCTAssertEqual(try tree.find(path: "MyStruct/myStructProperty", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD8PropertySivp")
        XCTAssertEqual(try tree.find(path: "MyStruct/myStructTypeProperty", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        XCTAssertEqual(try tree.find(path: "MyEnum", parent: myStructFunctionNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        XCTAssertEqual(try tree.find(path: "MyEnum/firstCase", parent: myStructFunctionNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        XCTAssertEqual(try tree.find(path: "MyEnum/secondCase", parent: myStructFunctionNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        XCTAssertEqual(try tree.find(path: "MyEnum/myEnumFunction()", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        XCTAssertEqual(try tree.find(path: "MyEnum/MyEnumTypeAlias", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        XCTAssertEqual(try tree.find(path: "MyEnum/myEnumProperty", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        XCTAssertEqual(try tree.find(path: "MyStruct", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV")
        XCTAssertEqual(try tree.find(path: "MyStruct/myStructFunction()", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        XCTAssertEqual(try tree.find(path: "MyStruct/MyStructTypeAlias", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        XCTAssertEqual(try tree.find(path: "MyStruct/myStructProperty", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD8PropertySivp")
        XCTAssertEqual(try tree.find(path: "MyStruct/myStructTypeProperty", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        XCTAssertEqual(try tree.find(path: "MixedFramework", parent: myFirstCaseNode.identifier).identifier.precise, "MixedFramework")
        XCTAssertEqual(try tree.find(path: "MixedFramework", parent: myStructFunctionNode.identifier).identifier.precise, "MixedFramework")
        
        // All the way up and all the way down
        XCTAssertEqual(try tree.find(path: "MixedFramework-module/MyEnum-enum/firstCase-enum.case", parent: myFirstCaseNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        XCTAssertEqual(try tree.find(path: "MixedFramework-module/MyEnum-enum/secondCase-enum.case", parent: myFirstCaseNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        XCTAssertEqual(try tree.find(path: "MixedFramework-module/MyEnum-enum/myEnumFunction()-method", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        XCTAssertEqual(try tree.find(path: "MixedFramework-module/MyEnum-enum/MyEnumTypeAlias-typealias", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        XCTAssertEqual(try tree.find(path: "MixedFramework-module/MyEnum-enum/myEnumProperty-property", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        XCTAssertEqual(try tree.find(path: "MixedFramework-module/MyStruct-struct/myStructFunction()-method", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        XCTAssertEqual(try tree.find(path: "MixedFramework-module/MyStruct-struct/MyStructTypeAlias-typealias", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        XCTAssertEqual(try tree.find(path: "MixedFramework-module/MyStruct-struct/myStructProperty-property", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD8PropertySivp")
        XCTAssertEqual(try tree.find(path: "MixedFramework-module/MyStruct-struct/myStructTypeProperty-type.property", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        // Absolute links
        XCTAssertEqual(try tree.find(path: "/MixedFramework-module/MyEnum-enum/firstCase-enum.case", parent: myFirstCaseNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        XCTAssertEqual(try tree.find(path: "/MixedFramework-module/MyEnum-enum/secondCase-enum.case", parent: myFirstCaseNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        XCTAssertEqual(try tree.find(path: "/MixedFramework-module/MyEnum-enum/myEnumFunction()-method", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        XCTAssertEqual(try tree.find(path: "/MixedFramework-module/MyEnum-enum/MyEnumTypeAlias-typealias", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        XCTAssertEqual(try tree.find(path: "/MixedFramework-module/MyEnum-enum/myEnumProperty-property", parent: myFirstCaseNode.identifier).identifier.precise, "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        XCTAssertEqual(try tree.find(path: "/MixedFramework-module/MyStruct-struct/myStructFunction()-method", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        XCTAssertEqual(try tree.find(path: "/MixedFramework-module/MyStruct-struct/MyStructTypeAlias-typealias", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        XCTAssertEqual(try tree.find(path: "/MixedFramework-module/MyStruct-struct/myStructProperty-property", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD8PropertySivp")
        XCTAssertEqual(try tree.find(path: "/MixedFramework-module/MyStruct-struct/myStructTypeProperty-type.property", parent: myStructFunctionNode.identifier).identifier.precise, "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        // @objc(MySwiftClassObjectiveCName)
        // public class MySwiftClassSwiftName: NSObject {
        //     @objc(myPropertyObjectiveCName)
        //     public var myPropertySwiftName: Int { 0 }
        //
        //     @objc(myMethodObjectiveCName)
        //     public func myMethodSwiftName() -> Int { 0 }
        // }
        let mySwiftClassSwiftNode = try tree.findNode(path: "MySwiftClassSwiftName", parent: moduleNode.identifier)
        XCTAssertEqual(try tree.find(path: "myPropertySwiftName", parent: mySwiftClassSwiftNode.identifier).identifier.precise, "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(py)myPropertyObjectiveCName")
        XCTAssertEqual(try tree.find(path: "myMethodSwiftName()", parent: mySwiftClassSwiftNode.identifier).identifier.precise, "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(im)myMethodObjectiveCName")
        XCTAssertThrowsError(try tree.find(path: "myPropertyObjectiveCName", parent: mySwiftClassSwiftNode.identifier))
        XCTAssertThrowsError(try tree.find(path: "myMethodObjectiveCName", parent: mySwiftClassSwiftNode.identifier))
        
        let mySwiftClassObjCNode = try tree.findNode(path: "MySwiftClassObjectiveCName", parent: moduleNode.identifier)
        XCTAssertEqual(try tree.find(path: "myPropertyObjectiveCName", parent: mySwiftClassObjCNode.identifier).identifier.precise, "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(py)myPropertyObjectiveCName")
        XCTAssertEqual(try tree.find(path: "myMethodObjectiveCName", parent: mySwiftClassObjCNode.identifier).identifier.precise, "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(im)myMethodObjectiveCName")
        XCTAssertThrowsError(try tree.find(path: "myPropertySwiftName", parent: mySwiftClassObjCNode.identifier))
        XCTAssertThrowsError(try tree.find(path: "myMethodSwiftName()", parent: mySwiftClassObjCNode.identifier))
        
        // typedef NS_OPTIONS(NSInteger, MyObjectiveCOption) {
        //     MyObjectiveCOptionNone                                      = 0,
        //     MyObjectiveCOptionFirst                                     = 1 << 0,
        //     MyObjectiveCOptionSecond NS_SWIFT_NAME(secondCaseSwiftName) = 1 << 1
        // };
        let myOptionAsEnum = try tree.findNode(path: "MyObjectiveCOption-enum", parent: moduleNode.identifier)
        XCTAssertEqual(try tree.find(path: "MyObjectiveCOptionNone", parent: myOptionAsEnum.identifier).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionNone")
        XCTAssertEqual(try tree.find(path: "MyObjectiveCOptionFirst", parent: myOptionAsEnum.identifier).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        XCTAssertEqual(try tree.find(path: "MyObjectiveCOptionSecond", parent: myOptionAsEnum.identifier).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        XCTAssertThrowsError(try tree.find(path: "none", parent: myOptionAsEnum.identifier))
        XCTAssertThrowsError(try tree.find(path: "first", parent: myOptionAsEnum.identifier))
        XCTAssertThrowsError(try tree.find(path: "second", parent: myOptionAsEnum.identifier))
        XCTAssertThrowsError(try tree.find(path: "secondCaseSwiftName", parent: myOptionAsEnum.identifier))
        
        let myOptionAsStruct = try tree.findNode(path: "MyObjectiveCOption-struct", parent: moduleNode.identifier)
        XCTAssertEqual(try tree.find(path: "first", parent: myOptionAsStruct.identifier).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        XCTAssertEqual(try tree.find(path: "secondCaseSwiftName", parent: myOptionAsStruct.identifier).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        XCTAssertThrowsError(try tree.find(path: "none", parent: myOptionAsStruct.identifier))
        XCTAssertThrowsError(try tree.find(path: "second", parent: myOptionAsStruct.identifier))
        XCTAssertThrowsError(try tree.find(path: "MyObjectiveCOptionNone", parent: myOptionAsStruct.identifier))
        XCTAssertThrowsError(try tree.find(path: "MyObjectiveCOptionFirst", parent: myOptionAsStruct.identifier))
        XCTAssertThrowsError(try tree.find(path: "MyObjectiveCOptionSecond", parent: myOptionAsStruct.identifier))
        
        // typedef NSInteger MyTypedObjectiveCExtensibleEnum NS_TYPED_EXTENSIBLE_ENUM;
        //
        // MyTypedObjectiveCExtensibleEnum const MyTypedObjectiveCExtensibleEnumFirst;
        // MyTypedObjectiveCExtensibleEnum const MyTypedObjectiveCExtensibleEnumSecond;
        let myTypedExtensibleEnumNode = try tree.findNode(path: "MyTypedObjectiveCExtensibleEnum-struct", parent: moduleNode.identifier)
        XCTAssertEqual(try tree.find(path: "first", parent: myTypedExtensibleEnumNode.identifier).identifier.precise, "c:@MyTypedObjectiveCExtensibleEnumFirst")
        XCTAssertEqual(try tree.find(path: "second", parent: myTypedExtensibleEnumNode.identifier).identifier.precise, "c:@MyTypedObjectiveCExtensibleEnumSecond")
    }
    
    // TODO: It might be nice to support "almost absolute symbol links" that start top-level in some module but doesn't include the module name in the path
    
    func testPathWithDocumentationPrefix() throws {
        let moduleNode = try tree.findNode(path: "/MixedFramework")
        
        XCTAssertEqual(try tree.find(path: "MyEnum", parent: moduleNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        XCTAssertEqual(try tree.find(path: "MixedFramework/MyEnum", parent: moduleNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        XCTAssertEqual(try tree.find(path: "documentation/MixedFramework/MyEnum", parent: moduleNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        XCTAssertEqual(try tree.find(path: "/documentation/MixedFramework/MyEnum", parent: moduleNode.identifier).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        
        assertParsedPathComponents("documentation/MixedFramework/MyEnum", [("/", nil, nil), ("MixedFramework", nil, nil), ("MyEnum", nil, nil)])
        assertParsedPathComponents("/documentation/MixedFramework/MyEnum", [("/", nil, nil), ("MixedFramework", nil, nil), ("MyEnum", nil, nil)])
    }
    
    func testTestBundle() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        tree = context.symbolPathTree
        
        // Test finding the parent via the `fromTopicReference` integration shim.
        let parentID = tree.fromTopicReference(ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift), context: context)
        XCTAssertNotNil(parentID)
        XCTAssertEqual(try tree.find(path: "globalFunction(_:considering:)", parent: parentID).identifier.precise, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
        XCTAssertEqual(try tree.find(path: "MyKit/globalFunction(_:considering:)", parent: parentID).identifier.precise, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
        XCTAssertEqual(try tree.find(path: "/MyKit/globalFunction(_:considering:)", parent: parentID).identifier.precise, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
          
        let myKidModuleNode = try tree.findNode(path: "/MyKit")
        XCTAssertEqual(try tree.find(path: "globalFunction(_:considering:)", parent: myKidModuleNode.identifier).identifier.precise, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
        XCTAssertEqual(try tree.find(path: "MyKit/globalFunction(_:considering:)", parent: myKidModuleNode.identifier).identifier.precise, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
        XCTAssertEqual(try tree.find(path: "/MyKit/globalFunction(_:considering:)", parent: myKidModuleNode.identifier).identifier.precise, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
        
        XCTAssertEqual(try tree.find(path: "MyClass/init()-33vaw", parent: myKidModuleNode.identifier).identifier.precise, "s:5MyKit0A5ClassCACycfcDUPLICATE")
        
        // Test finding symbol from an extension
        let sideKidModuleNode = try tree.findNode(path: "/SideKit")
        XCTAssertEqual(try tree.find(path: "UncuratedClass/angle", parent: sideKidModuleNode.identifier).identifier.precise, "s:So14UncuratedClassCV5MyKitE5angle12CoreGraphics7CGFloatVSgvp")
        try assertFindsPath("/SideKit/SideClass/Element", in: tree, asSymbolID: "s:7SideKit0A5ClassC7Elementa")
        try assertFindsPath("/SideKit/SideClass/Element/inherited()", in: tree, asSymbolID: "s:7SideKit0A5::SYNTESIZED::inheritedFF")
        try assertPathCollision("/SideKit/SideProtocol/func()", in: tree, collisions: [
            ("s:5MyKit0A5MyProtocol0Afunc()DefaultImp", "2dxqn"),
            ("s:5MyKit0A5MyProtocol0Afunc()", "6ijsi"),
        ])
        
        try assertFindsPath("/FillIntroduced/iOSOnlyDeprecated()", in: tree, asSymbolID: "s:14FillIntroduced17iOSOnlyDeprecatedyyF")
        try assertFindsPath("/FillIntroduced/macCatalystOnlyIntroduced()", in: tree, asSymbolID: "s:14FillIntroduced015macCatalystOnlyB0yyF")
        
        try assertFindsPath("/Test/FirstGroup/MySnippet", in: tree, asSymbolID: "$snippet__Test.FirstGroup.MySnippet")
        
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        try assertFindsPath("/SideKit/UncuratedClass", in: tree, asSymbolID: "s:7SideKit14UncuratedClassC")
        XCTAssertEqual(paths["s:7SideKit14UncuratedClassC"],
                       "/SideKit/UncuratedClass")
    }
    
    func testMixedLanguageFramework() throws {
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFramework")
        tree = context.symbolPathTree
        
        try assertFindsPath("MixedLanguageFramework/Bar/myStringFunction(_:)", in: tree, asSymbolID: "c:objc(cs)Bar(cm)myStringFunction:error:")
        try assertFindsPath("MixedLanguageFramework/Bar/myStringFunction:error:", in: tree, asSymbolID: "c:objc(cs)Bar(cm)myStringFunction:error:")

        try assertPathCollision("MixedLanguageFramework/Foo", in: tree, collisions: [
            ("c:@E@Foo", "enum"),
            ("c:@E@Foo", "struct"),
            ("c:MixedLanguageFramework.h@T@Foo", "typealias"),
        ])
        
        try assertFindsPath("MixedLanguageFramework/Foo/first", in: tree, asSymbolID: "c:@E@Foo@first")
        
        try assertFindsPath("MixedLanguageFramework/Foo-enum/first", in: tree, asSymbolID: "c:@E@Foo@first")
        try assertFindsPath("MixedLanguageFramework/Foo-struct/first", in: tree, asSymbolID: "c:@E@Foo@first")
        try assertFindsPath("MixedLanguageFramework/Foo-c.enum/first", in: tree, asSymbolID: "c:@E@Foo@first")
        try assertFindsPath("MixedLanguageFramework/Foo-swift.struct/first", in: tree, asSymbolID: "c:@E@Foo@first")
        
        try assertFindsPath("MixedLanguageFramework/Foo/first-enum.case", in: tree, asSymbolID: "c:@E@Foo@first")
        try assertFindsPath("MixedLanguageFramework/Foo/first-c.enum.case", in: tree, asSymbolID: "c:@E@Foo@first")
        try assertFindsPath("MixedLanguageFramework/Foo/first-type.property", in: tree, asSymbolID: "c:@E@Foo@first")
        try assertFindsPath("MixedLanguageFramework/Foo/first-swift.type.property", in: tree, asSymbolID: "c:@E@Foo@first")

        try assertFindsPath("MixedLanguageFramework/MixedLanguageProtocol/mixedLanguageMethod()", in: tree, asSymbolID: "c:@M@TestFramework@objc(pl)MixedLanguageProtocol(im)mixedLanguageMethod")
        try assertFindsPath("MixedLanguageFramework/MixedLanguageProtocol/mixedLanguageMethod", in: tree, asSymbolID: "c:@M@TestFramework@objc(pl)MixedLanguageProtocol(im)mixedLanguageMethod")
        
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        XCTAssertEqual(paths["c:@E@Foo"],
                       "/MixedLanguageFramework/Foo-struct")
        XCTAssertEqual(paths["c:MixedLanguageFramework.h@T@Foo"],
                       "/MixedLanguageFramework/Foo-typealias")
        XCTAssertEqual(paths["c:@E@Foo@first"],
                       "/MixedLanguageFramework/Foo/first")
        XCTAssertEqual(paths["c:@E@Foo@second"],
                       "/MixedLanguageFramework/Foo/second")
        XCTAssertEqual(paths["s:So3FooV8rawValueABSu_tcfc"],
                       "/MixedLanguageFramework/Foo/init(rawValue:)")
        XCTAssertEqual(paths["c:objc(cs)Bar(cm)myStringFunction:error:"],
                       "/MixedLanguageFramework/Bar/myStringFunction(_:)")
        XCTAssertEqual(paths["s:22MixedLanguageFramework15SwiftOnlyStructV4tadayyF"],
                       "/MixedLanguageFramework/SwiftOnlyStruct/tada()")
    }
    
    func testOverloadedSymbols() throws {
        let (_, context) = try testBundleAndContext(named: "OverloadedSymbols")
        tree = context.symbolPathTree
        
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        
        XCTAssertEqual(paths["s:8ShapeKit22OverloadedParentStructV"],
                       "/ShapeKit/OverloadedParentStruct-1jr3p")
        XCTAssertEqual(paths["s:8ShapeKit22overloadedparentstructV"],
                       "/ShapeKit/overloadedparentstruct-6a7lx")
        
        // These need to be disambiguated in two path components
        XCTAssertEqual(paths["s:8ShapeKit22OverloadedParentStructV15fifthTestMemberSivpZ"],
                       "/ShapeKit/OverloadedParentStruct-1jr3p/fifthTestMember")
        XCTAssertEqual(paths["s:8ShapeKit22overloadedparentstructV15fifthTestMemberSivp"],
                       "/ShapeKit/overloadedparentstruct-6a7lx/fifthTestMember")
    }
    
    func testParsingPaths() {
        // Check path components without disambiguation
        assertParsedPathComponents("", [])
        assertParsedPathComponents("/", [("/", nil, nil)])
        assertParsedPathComponents("/first", [("/", nil, nil), ("first", nil, nil)])
        assertParsedPathComponents("first", [("first", nil, nil)])
        assertParsedPathComponents("first/second/third", [("first", nil, nil), ("second", nil, nil), ("third", nil, nil)])
        assertParsedPathComponents("first/", [("first", nil, nil)])
        assertParsedPathComponents("first//second", [("first", nil, nil), ("second", nil, nil)])

        // Check disambiguation
        assertParsedPathComponents("path-hash", [("path", nil, "hash")])
        assertParsedPathComponents("path-struct", [("path", "struct", nil)])
        assertParsedPathComponents("path-struct-hash", [("path", "struct", "hash")])
        
        assertParsedPathComponents("path-swift.something", [("path", "something", nil)])
        assertParsedPathComponents("path-c.something", [("path", "something", nil)])
        
        assertParsedPathComponents("path-swift.something-hash", [("path", "something", "hash")])
        assertParsedPathComponents("path-c.something-hash", [("path", "something", "hash")])
        
        assertParsedPathComponents("path-type.property-hash", [("path", "type.property", "hash")])
        assertParsedPathComponents("path-swift.type.property-hash", [("path", "type.property", "hash")])
        assertParsedPathComponents("path-type.property", [("path", "type.property", nil)])
        assertParsedPathComponents("path-swift.type.property", [("path", "type.property", nil)])
    }
    
    // MARK: Test helpers
    
    private func assertFindsPath(_ path: String, in tree: SymbolPathTree, asSymbolID symbolID: String, file: StaticString = #file, line: UInt = #line) throws {
        do {
            let symbol = try tree.find(path: path)
            XCTAssertEqual(symbol.identifier.precise, symbolID, file: file, line: line)
        } catch SymbolPathTree.Error.notFound {
            XCTFail("Symbol for \(path.singleQuoted) not found in tree", file: file, line: line)
        } catch SymbolPathTree.Error.partialResult {
            XCTFail("Symbol for \(path.singleQuoted) not found in tree. Only part of path is found.", file: file, line: line)
        } catch SymbolPathTree.Error.lookupCollision(_, let collisions) {
            let symbols = collisions.map { $0.value }
            XCTFail("Unexpected collision for \(path.singleQuoted); \(symbols.map { return "\($0.names.title) - \($0.kind.identifier.identifier) - \($0.identifier.precise.stableHashString)"})", file: file, line: line)
        }
    }
    
    private func assertPathNotFound(_ path: String, in tree: SymbolPathTree, file: StaticString = #file, line: UInt = #line) throws {
        do {
            let symbol = try tree.find(path: path)
            XCTFail("Unexpectedly found symbol with ID \(symbol.identifier.precise) for path \(path.singleQuoted)", file: file, line: line)
        } catch SymbolPathTree.Error.notFound {
            // This specific error is expected.
        } catch SymbolPathTree.Error.partialResult {
            // For the purpose of this assertion, this also counts as "not found".
        } catch SymbolPathTree.Error.lookupCollision(_, let collisions) {
            let symbols = collisions.map { $0.value }
            XCTFail("Unexpected collision for \(path.singleQuoted); \(symbols.map { return "\($0.names.title) - \($0.kind.identifier.identifier) - \($0.identifier.precise.stableHashString)"})", file: file, line: line)
        }
    }
    
    private func assertPathCollision(_ path: String, in tree: SymbolPathTree, collisions expectedCollisions: [(symbolID: String, disambiguation: String)], file: StaticString = #file, line: UInt = #line) throws {
        do {
            let symbol = try tree.find(path: path)
            XCTFail("Unexpectedly found unambiguous symbol with ID \(symbol.identifier.precise) for path \(path.singleQuoted)", file: file, line: line)
        } catch SymbolPathTree.Error.notFound {
            XCTFail("Symbol for \(path.singleQuoted) not found in tree", file: file, line: line)
        } catch SymbolPathTree.Error.partialResult {
            XCTFail("Symbol for \(path.singleQuoted) not found in tree. Only part of path is found.", file: file, line: line)
        } catch SymbolPathTree.Error.lookupCollision(_, let collisions) {
            let sortedCollisions = collisions.sorted(by: \.disambiguation)
            XCTAssertEqual(sortedCollisions.count, expectedCollisions.count, file: file, line: line)
            
            for (actual, expected) in zip(sortedCollisions, expectedCollisions) {
                XCTAssertEqual(actual.value.identifier.precise, expected.symbolID, file: file, line: line)
                XCTAssertEqual(actual.disambiguation, expected.disambiguation, file: file, line: line)
            }
        }
    }
    
    private func assertParsedPathComponents(_ path: String, _ expected: [(String, String?, String?)], file: StaticString = #file, line: UInt = #line) {
        let actual = SymbolPathTree.parse(path: path)
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (actualComponents, expectedComponents) in zip(actual, expected) {
            XCTAssertEqual(actualComponents.0, expectedComponents.0, "Incorrect path component", file: file, line: line)
            XCTAssertEqual(actualComponents.1, expectedComponents.1, "Incorrect kind disambiguation", file: file, line: line)
            XCTAssertEqual(actualComponents.2, expectedComponents.2, "Incorrect hash disambiguation", file: file, line: line)
        }
    }
}
