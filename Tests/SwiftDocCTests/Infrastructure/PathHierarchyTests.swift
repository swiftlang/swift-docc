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
import SwiftDocCTestUtilities

class PathHierarchyTests: XCTestCase {
    
    func testFindingUnambiguousAbsolutePaths() throws {
        try XCTSkipUnless(LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver)
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFrameworkWithLanguageRefinements")
        let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
        
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
        try assertFindsPath("/MixedFramework/MyObjectiveCCompatibleProtocol/myProtocolTypeProperty", in: tree, asSymbolID: "c:@M@MixedFramework@objc(pl)MyObjectiveCCompatibleProtocol(cpy)myProtocolTypeProperty")
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
        try XCTSkipUnless(LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver)
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFrameworkWithLanguageRefinements")
        let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
        
        // public enum CollisionsWithDifferentKinds {
        //     case something
        //     public var something: String { "" }
        //     public typealias Something = Int
        // }
        try assertPathCollision("/MixedFramework/CollisionsWithDifferentKinds/something", in: tree, collisions: [
            (symbolID: "s:14MixedFramework28CollisionsWithDifferentKindsO9somethingyA2CmF", disambiguation: "enum.case"),
            (symbolID: "s:14MixedFramework28CollisionsWithDifferentKindsO9somethingSSvp", disambiguation: "property"),
        ])
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithDifferentKinds/something", in: tree, context: context, expectedErrorMessage: """
        Reference is ambiguous after '/MixedFramework/CollisionsWithDifferentKinds': \
        Append '-enum.case' to refer to 'case something'. \
        Append '-property' to refer to 'var something: String { get }'.
        """)
        
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
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithEscapedKeywords/init()", in: tree, context: context, expectedErrorMessage: """
        Reference is ambiguous after '/MixedFramework/CollisionsWithEscapedKeywords': \
        Append '-init' to refer to 'init()'. \
        Append '-method' to refer to 'func `init`()'. \
        Append '-type.method' to refer to 'static func `init`()'.
        """)
        
        try assertPathCollision("/MixedFramework/CollisionsWithEscapedKeywords/subscript()", in: tree, collisions: [
            (symbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsC9subscriptyyF", disambiguation: "method"),
            (symbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsCSiycip", disambiguation: "subscript"),
            (symbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsC9subscriptyyFZ", disambiguation: "type.method"),
        ])
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithEscapedKeywords/subscript()", in: tree, context: context, expectedErrorMessage: """
        Reference is ambiguous after '/MixedFramework/CollisionsWithEscapedKeywords': \
        Append '-method' to refer to 'func `subscript`()'. \
        Append '-subscript' to refer to 'subscript() -> Int { get }'. \
        Append '-type.method' to refer to 'static func `subscript`()'.
        """)
        
        // public enum CollisionsWithDifferentFunctionArguments {
        //     public func something(argument: Int) -> Int { 0 }
        //     public func something(argument: String) -> Int { 0 }
        // }
        try assertPathCollision("/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)", in: tree, collisions: [
            (symbolID: "s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentS2i_tF", disambiguation: "1cyvp"),
            (symbolID: "s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentSiSS_tF", disambiguation: "2vke2"),
        ])
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)", in: tree, context: context, expectedErrorMessage: """
        Reference is ambiguous after '/MixedFramework/CollisionsWithDifferentFunctionArguments': \
        Append '-1cyvp' to refer to 'func something(argument: Int) -> Int'. \
        Append '-2vke2' to refer to 'func something(argument: String) -> Int'.
        """)
        
        // public enum CollisionsWithDifferentSubscriptArguments {
        //     public subscript(something: Int) -> Int { 0 }
        //     public subscript(somethingElse: String) -> Int { 0 }
        // }
        try assertPathCollision("/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)", in: tree, collisions: [
            (symbolID: "s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOyS2icip", disambiguation: "4fd0l"),
            (symbolID: "s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOySiSScip", disambiguation: "757cj"),
        ])
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)", in: tree, context: context, expectedErrorMessage: """
        Reference is ambiguous after '/MixedFramework/CollisionsWithDifferentSubscriptArguments': \
        Append '-4fd0l' to refer to 'subscript(something: Int) -> Int { get }'. \
        Append '-757cj' to refer to 'subscript(somethingElse: String) -> Int { get }'.
        """)
        
        // typedef NS_OPTIONS(NSInteger, MyObjectiveCOption) {
        //     MyObjectiveCOptionNone                                      = 0,
        //     MyObjectiveCOptionFirst                                     = 1 << 0,
        //     MyObjectiveCOptionSecond NS_SWIFT_NAME(secondCaseSwiftName) = 1 << 1
        // };
        try assertFindsPath("/MixedFramework/MyObjectiveCOption", in: tree, asSymbolID: "c:@E@MyObjectiveCOption")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption-enum", in: tree, asSymbolID: "c:@E@MyObjectiveCOption")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption-struct", in: tree, asSymbolID: "c:@E@MyObjectiveCOption")
        // Since both collisions are the same symbol (in different languages) it can be disambiguated as one of the values.
        //
        // Resolving subpaths will pick to the version of the symbol that has those descendants.
        try assertFindsPath("/MixedFramework/MyObjectiveCOption/MyObjectiveCOptionNone", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionNone")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption/MyObjectiveCOptionFirst", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption/MyObjectiveCOptionSecond", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        
        try assertFindsPath("/MixedFramework/MyObjectiveCOption/first", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption/secondCaseSwiftName", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        // Using a disambiguation suffix to pick a specific version of the symbol can only find the descendants in that language ...
        try assertFindsPath("/MixedFramework/MyObjectiveCOption-enum/MyObjectiveCOptionNone", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionNone")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption-enum/MyObjectiveCOptionFirst", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption-enum/MyObjectiveCOptionSecond", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        
        try assertFindsPath("/MixedFramework/MyObjectiveCOption-struct/first", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        try assertFindsPath("/MixedFramework/MyObjectiveCOption-struct/secondCaseSwiftName", in: tree, asSymbolID: "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        // ... but not the descendants in the other language.
        try assertPathNotFound("/MixedFramework/MyObjectiveCOption-struct/MyObjectiveCOptionNone", in: tree)
        try assertPathNotFound("/MixedFramework/MyObjectiveCOption-struct/MyObjectiveCOptionFirst", in: tree)
        try assertPathNotFound("/MixedFramework/MyObjectiveCOption-struct/MyObjectiveCOptionSecond", in: tree)
        
        try assertPathNotFound("/MixedFramework/MyObjectiveCOption-enum/first", in: tree)
        try assertPathNotFound("/MixedFramework/MyObjectiveCOption-enum/secondCaseSwiftName", in: tree)
        
        // typedef NSInteger MyTypedObjectiveCEnum NS_TYPED_ENUM;
        //
        // MyTypedObjectiveCEnum const MyTypedObjectiveCEnumFirst;
        // MyTypedObjectiveCEnum const MyTypedObjectiveCEnumSecond;
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnum", in: tree, asSymbolID: "c:ObjectiveCDeclarations.h@T@MyTypedObjectiveCEnum")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnum-struct", in: tree, asSymbolID: "c:ObjectiveCDeclarations.h@T@MyTypedObjectiveCEnum")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnum-typealias", in: tree, asSymbolID: "c:ObjectiveCDeclarations.h@T@MyTypedObjectiveCEnum")
        // Since both collisions are the same symbol (in different languages) it can be disambiguated as one of the values.
        //
        // Resolving subpaths will pick to the version of the symbol that has those descendants.
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnum/first", in: tree, asSymbolID: "c:@MyTypedObjectiveCEnumFirst")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnum/second", in: tree, asSymbolID: "c:@MyTypedObjectiveCEnumSecond")
        
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnumFirst", in: tree, asSymbolID: "c:@MyTypedObjectiveCEnumFirst")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnumSecond", in: tree, asSymbolID: "c:@MyTypedObjectiveCEnumSecond")
        // Using a disambiguation suffix to pick a specific version of the symbol can only find the descendants in that language ...
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnum-struct/first", in: tree, asSymbolID: "c:@MyTypedObjectiveCEnumFirst")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCEnum-struct/second", in: tree, asSymbolID: "c:@MyTypedObjectiveCEnumSecond")
        // ... but not the descendants in the other language.
        try assertPathNotFound("MixedFramework/MyTypedObjectiveCEnum-typealias/first", in: tree)
        try assertPathNotFound("MixedFramework/MyTypedObjectiveCEnum-typealias/second", in: tree)
        
        // typedef NSInteger MyTypedObjectiveCExtensibleEnum NS_TYPED_EXTENSIBLE_ENUM;
        //
        // MyTypedObjectiveCExtensibleEnum const MyTypedObjectiveCExtensibleEnumFirst;
        // MyTypedObjectiveCExtensibleEnum const MyTypedObjectiveCExtensibleEnumSecond;
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnum", in: tree, asSymbolID: "c:ObjectiveCDeclarations.h@T@MyTypedObjectiveCExtensibleEnum")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnum-struct", in: tree, asSymbolID: "c:ObjectiveCDeclarations.h@T@MyTypedObjectiveCExtensibleEnum")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnum-typealias", in: tree, asSymbolID: "c:ObjectiveCDeclarations.h@T@MyTypedObjectiveCExtensibleEnum")
        // Since both collisions are the same symbol (in different languages) it can be disambiguated as one of the values.
        //
        // Resolving subpaths will pick to the version of the symbol that has those descendants.
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnum/first", in: tree, asSymbolID: "c:@MyTypedObjectiveCExtensibleEnumFirst")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnum/second", in: tree, asSymbolID: "c:@MyTypedObjectiveCExtensibleEnumSecond")
        
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnumFirst", in: tree, asSymbolID: "c:@MyTypedObjectiveCExtensibleEnumFirst")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnumSecond", in: tree, asSymbolID: "c:@MyTypedObjectiveCExtensibleEnumSecond")
        // Using a disambiguation suffix to pick a specific version of the symbol can only find the descendants in that language ...
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnum-struct/first", in: tree, asSymbolID: "c:@MyTypedObjectiveCExtensibleEnumFirst")
        try assertFindsPath("/MixedFramework/MyTypedObjectiveCExtensibleEnum-struct/second", in: tree, asSymbolID: "c:@MyTypedObjectiveCExtensibleEnumSecond")
        // ... but not the descendants in the other language.
        try assertPathNotFound("MixedFramework/MyTypedObjectiveCExtensibleEnum-typealias/first", in: tree)
        try assertPathNotFound("MixedFramework/MyTypedObjectiveCExtensibleEnum-typealias/second", in: tree)
    }
    
    func testRedundantKindDisambiguation() throws {
        try XCTSkipUnless(LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver)
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFrameworkWithLanguageRefinements")
        let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
        
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
        try XCTSkipUnless(LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver)
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFrameworkWithLanguageRefinements")
        let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
        
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
        try XCTSkipUnless(LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver)
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFrameworkWithLanguageRefinements")
        let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
        
        let paths = tree.caseInsensitiveDisambiguatedPaths()
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
        try XCTSkipUnless(LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver)
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFrameworkWithLanguageRefinements")
        let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
        
        let moduleID = try tree.find(path: "/MixedFramework", onlyFindSymbols: true)
        
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
        let myEnumID = try tree.find(path: "MyEnum", parent: moduleID, onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "firstCase", parent: myEnumID).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        XCTAssertEqual(try tree.findSymbol(path: "secondCase", parent: myEnumID).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        XCTAssertEqual(try tree.findSymbol(path: "myEnumFunction()", parent: myEnumID).identifier.precise, "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        XCTAssertEqual(try tree.findSymbol(path: "MyEnumTypeAlias", parent: myEnumID).identifier.precise, "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        XCTAssertEqual(try tree.findSymbol(path: "myEnumProperty", parent: myEnumID).identifier.precise, "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        let myStructID = try tree.find(path: "MyStruct", parent: moduleID, onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "myStructFunction()", parent: myStructID).identifier.precise, "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        XCTAssertEqual(try tree.findSymbol(path: "MyStructTypeAlias", parent: myStructID).identifier.precise, "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        XCTAssertEqual(try tree.findSymbol(path: "myStructProperty", parent: myStructID).identifier.precise, "s:14MixedFramework8MyStructV02myD8PropertySivp")
        XCTAssertEqual(try tree.findSymbol(path: "myStructTypeProperty", parent: myStructID).identifier.precise, "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        // Resolve symbols with the same parent
        let myFirstCaseID = try tree.find(path: "firstCase", parent: myEnumID, onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "firstCase", parent: myFirstCaseID).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        XCTAssertEqual(try tree.findSymbol(path: "secondCase", parent: myFirstCaseID).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        XCTAssertEqual(try tree.findSymbol(path: "myEnumFunction()", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        XCTAssertEqual(try tree.findSymbol(path: "MyEnumTypeAlias", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        XCTAssertEqual(try tree.findSymbol(path: "myEnumProperty", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        let myStructFunctionID = try tree.find(path: "myStructFunction()", parent: myStructID, onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "myStructFunction()", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        XCTAssertEqual(try tree.findSymbol(path: "MyStructTypeAlias", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        XCTAssertEqual(try tree.findSymbol(path: "myStructProperty", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV02myD8PropertySivp")
        XCTAssertEqual(try tree.findSymbol(path: "myStructTypeProperty", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        // Resolve symbols accessible from the parent's parent
        XCTAssertEqual(try tree.findSymbol(path: "MyEnum", parent: myFirstCaseID).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        XCTAssertEqual(try tree.findSymbol(path: "MyEnum/firstCase", parent: myFirstCaseID).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        XCTAssertEqual(try tree.findSymbol(path: "MyEnum/secondCase", parent: myFirstCaseID).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        XCTAssertEqual(try tree.findSymbol(path: "MyEnum/myEnumFunction()", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        XCTAssertEqual(try tree.findSymbol(path: "MyEnum/MyEnumTypeAlias", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        XCTAssertEqual(try tree.findSymbol(path: "MyEnum/myEnumProperty", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        XCTAssertEqual(try tree.findSymbol(path: "MyStruct", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework8MyStructV")
        XCTAssertEqual(try tree.findSymbol(path: "MyStruct/myStructFunction()", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        XCTAssertEqual(try tree.findSymbol(path: "MyStruct/MyStructTypeAlias", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        XCTAssertEqual(try tree.findSymbol(path: "MyStruct/myStructProperty", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework8MyStructV02myD8PropertySivp")
        XCTAssertEqual(try tree.findSymbol(path: "MyStruct/myStructTypeProperty", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        XCTAssertEqual(try tree.findSymbol(path: "MyEnum", parent: myStructFunctionID).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        XCTAssertEqual(try tree.findSymbol(path: "MyEnum/firstCase", parent: myStructFunctionID).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        XCTAssertEqual(try tree.findSymbol(path: "MyEnum/secondCase", parent: myStructFunctionID).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        XCTAssertEqual(try tree.findSymbol(path: "MyEnum/myEnumFunction()", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        XCTAssertEqual(try tree.findSymbol(path: "MyEnum/MyEnumTypeAlias", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        XCTAssertEqual(try tree.findSymbol(path: "MyEnum/myEnumProperty", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        XCTAssertEqual(try tree.findSymbol(path: "MyStruct", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV")
        XCTAssertEqual(try tree.findSymbol(path: "MyStruct/myStructFunction()", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        XCTAssertEqual(try tree.findSymbol(path: "MyStruct/MyStructTypeAlias", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        XCTAssertEqual(try tree.findSymbol(path: "MyStruct/myStructProperty", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV02myD8PropertySivp")
        XCTAssertEqual(try tree.findSymbol(path: "MyStruct/myStructTypeProperty", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        XCTAssertEqual(try tree.findSymbol(path: "MixedFramework", parent: myFirstCaseID).identifier.precise, "MixedFramework")
        XCTAssertEqual(try tree.findSymbol(path: "MixedFramework", parent: myStructFunctionID).identifier.precise, "MixedFramework")
        
        // All the way up and all the way down
        XCTAssertEqual(try tree.findSymbol(path: "MixedFramework-module/MyEnum-enum/firstCase-enum.case", parent: myFirstCaseID).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        XCTAssertEqual(try tree.findSymbol(path: "MixedFramework-module/MyEnum-enum/secondCase-enum.case", parent: myFirstCaseID).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        XCTAssertEqual(try tree.findSymbol(path: "MixedFramework-module/MyEnum-enum/myEnumFunction()-method", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        XCTAssertEqual(try tree.findSymbol(path: "MixedFramework-module/MyEnum-enum/MyEnumTypeAlias-typealias", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        XCTAssertEqual(try tree.findSymbol(path: "MixedFramework-module/MyEnum-enum/myEnumProperty-property", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        XCTAssertEqual(try tree.findSymbol(path: "MixedFramework-module/MyStruct-struct/myStructFunction()-method", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        XCTAssertEqual(try tree.findSymbol(path: "MixedFramework-module/MyStruct-struct/MyStructTypeAlias-typealias", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        XCTAssertEqual(try tree.findSymbol(path: "MixedFramework-module/MyStruct-struct/myStructProperty-property", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV02myD8PropertySivp")
        XCTAssertEqual(try tree.findSymbol(path: "MixedFramework-module/MyStruct-struct/myStructTypeProperty-type.property", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        // Absolute links
        XCTAssertEqual(try tree.findSymbol(path: "/MixedFramework-module/MyEnum-enum/firstCase-enum.case", parent: myFirstCaseID).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumFirstCase")
        XCTAssertEqual(try tree.findSymbol(path: "/MixedFramework-module/MyEnum-enum/secondCase-enum.case", parent: myFirstCaseID).identifier.precise, "c:@M@MixedFramework@E@MyEnum@MyEnumSecondCase")
        XCTAssertEqual(try tree.findSymbol(path: "/MixedFramework-module/MyEnum-enum/myEnumFunction()-method", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework6MyEnumO02myD8FunctionyyF")
        XCTAssertEqual(try tree.findSymbol(path: "/MixedFramework-module/MyEnum-enum/MyEnumTypeAlias-typealias", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework6MyEnumO0cD9TypeAliasa")
        XCTAssertEqual(try tree.findSymbol(path: "/MixedFramework-module/MyEnum-enum/myEnumProperty-property", parent: myFirstCaseID).identifier.precise, "s:14MixedFramework6MyEnumO02myD8PropertySivp")
        
        XCTAssertEqual(try tree.findSymbol(path: "/MixedFramework-module/MyStruct-struct/myStructFunction()-method", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV02myD8FunctionyyF")
        XCTAssertEqual(try tree.findSymbol(path: "/MixedFramework-module/MyStruct-struct/MyStructTypeAlias-typealias", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV0cD9TypeAliasa")
        XCTAssertEqual(try tree.findSymbol(path: "/MixedFramework-module/MyStruct-struct/myStructProperty-property", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV02myD8PropertySivp")
        XCTAssertEqual(try tree.findSymbol(path: "/MixedFramework-module/MyStruct-struct/myStructTypeProperty-type.property", parent: myStructFunctionID).identifier.precise, "s:14MixedFramework8MyStructV02myD12TypePropertySivpZ")
        
        // @objc(MySwiftClassObjectiveCName)
        // public class MySwiftClassSwiftName: NSObject {
        //     @objc(myPropertyObjectiveCName)
        //     public var myPropertySwiftName: Int { 0 }
        //
        //     @objc(myMethodObjectiveCName)
        //     public func myMethodSwiftName() -> Int { 0 }
        // }
        let mySwiftClassSwiftID = try tree.find(path: "MySwiftClassSwiftName", parent: moduleID, onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "myPropertySwiftName", parent: mySwiftClassSwiftID).identifier.precise, "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(py)myPropertyObjectiveCName")
        XCTAssertEqual(try tree.findSymbol(path: "myMethodSwiftName()", parent: mySwiftClassSwiftID).identifier.precise, "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(im)myMethodObjectiveCName")
        XCTAssertThrowsError(try tree.findSymbol(path: "myPropertyObjectiveCName", parent: mySwiftClassSwiftID))
        XCTAssertThrowsError(try tree.findSymbol(path: "myMethodObjectiveCName", parent: mySwiftClassSwiftID))
        
        let mySwiftClassObjCID = try tree.find(path: "MySwiftClassObjectiveCName", parent: moduleID, onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "myPropertyObjectiveCName", parent: mySwiftClassObjCID).identifier.precise, "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(py)myPropertyObjectiveCName")
        XCTAssertEqual(try tree.findSymbol(path: "myMethodObjectiveCName", parent: mySwiftClassObjCID).identifier.precise, "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(im)myMethodObjectiveCName")
        XCTAssertThrowsError(try tree.findSymbol(path: "myPropertySwiftName", parent: mySwiftClassObjCID))
        XCTAssertThrowsError(try tree.findSymbol(path: "myMethodSwiftName()", parent: mySwiftClassObjCID))
        
        // typedef NS_OPTIONS(NSInteger, MyObjectiveCOption) {
        //     MyObjectiveCOptionNone                                      = 0,
        //     MyObjectiveCOptionFirst                                     = 1 << 0,
        //     MyObjectiveCOptionSecond NS_SWIFT_NAME(secondCaseSwiftName) = 1 << 1
        // };
        let myOptionAsEnumID = try tree.find(path: "MyObjectiveCOption-enum", parent: moduleID, onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "MyObjectiveCOptionNone", parent: myOptionAsEnumID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionNone")
        XCTAssertEqual(try tree.findSymbol(path: "MyObjectiveCOptionFirst", parent: myOptionAsEnumID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        XCTAssertEqual(try tree.findSymbol(path: "MyObjectiveCOptionSecond", parent: myOptionAsEnumID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        XCTAssertThrowsError(try tree.findSymbol(path: "none", parent: myOptionAsEnumID))
        XCTAssertThrowsError(try tree.findSymbol(path: "first", parent: myOptionAsEnumID))
        XCTAssertThrowsError(try tree.findSymbol(path: "second", parent: myOptionAsEnumID))
        XCTAssertThrowsError(try tree.findSymbol(path: "secondCaseSwiftName", parent: myOptionAsEnumID))
        
        let myOptionAsStructID = try tree.find(path: "MyObjectiveCOption-struct", parent: moduleID, onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "first", parent: myOptionAsStructID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        XCTAssertEqual(try tree.findSymbol(path: "secondCaseSwiftName", parent: myOptionAsStructID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        XCTAssertThrowsError(try tree.findSymbol(path: "none", parent: myOptionAsStructID))
        XCTAssertThrowsError(try tree.findSymbol(path: "second", parent: myOptionAsStructID))
        XCTAssertThrowsError(try tree.findSymbol(path: "MyObjectiveCOptionNone", parent: myOptionAsStructID))
        XCTAssertThrowsError(try tree.findSymbol(path: "MyObjectiveCOptionFirst", parent: myOptionAsStructID))
        XCTAssertThrowsError(try tree.findSymbol(path: "MyObjectiveCOptionSecond", parent: myOptionAsStructID))
        
        // typedef NSInteger MyTypedObjectiveCExtensibleEnum NS_TYPED_EXTENSIBLE_ENUM;
        //
        // MyTypedObjectiveCExtensibleEnum const MyTypedObjectiveCExtensibleEnumFirst;
        // MyTypedObjectiveCExtensibleEnum const MyTypedObjectiveCExtensibleEnumSecond;
        let myTypedExtensibleEnumID = try tree.find(path: "MyTypedObjectiveCExtensibleEnum-struct", parent: moduleID, onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "first", parent: myTypedExtensibleEnumID).identifier.precise, "c:@MyTypedObjectiveCExtensibleEnumFirst")
        XCTAssertEqual(try tree.findSymbol(path: "second", parent: myTypedExtensibleEnumID).identifier.precise, "c:@MyTypedObjectiveCExtensibleEnumSecond")
    }
    
    func testPathWithDocumentationPrefix() throws {
        try XCTSkipUnless(LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver)
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFrameworkWithLanguageRefinements")
        let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
        
        let moduleID = try tree.find(path: "/MixedFramework", onlyFindSymbols: true)
        
        XCTAssertEqual(try tree.findSymbol(path: "MyEnum", parent: moduleID).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        XCTAssertEqual(try tree.findSymbol(path: "MixedFramework/MyEnum", parent: moduleID).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        XCTAssertEqual(try tree.findSymbol(path: "documentation/MixedFramework/MyEnum", parent: moduleID).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        XCTAssertEqual(try tree.findSymbol(path: "/documentation/MixedFramework/MyEnum", parent: moduleID).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        
        assertParsedPathComponents("documentation/MixedFramework/MyEnum", [("documentation", nil, nil), ("MixedFramework", nil, nil), ("MyEnum", nil, nil)])
        assertParsedPathComponents("/documentation/MixedFramework/MyEnum", [("documentation", nil, nil), ("MixedFramework", nil, nil), ("MyEnum", nil, nil)])
    }
    
    func testTestBundle() throws {
        try XCTSkipUnless(LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver)
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let linkResolver = try XCTUnwrap(context.hierarchyBasedLinkResolver)
        let tree = try XCTUnwrap(linkResolver.pathHierarchy)
        
        // Test finding the parent via the `fromTopicReference` integration shim.
        let parentID = linkResolver.resolvedReferenceMap[ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift)]!
        XCTAssertNotNil(parentID)
        XCTAssertEqual(try tree.findSymbol(path: "globalFunction(_:considering:)", parent: parentID).identifier.precise, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
        XCTAssertEqual(try tree.findSymbol(path: "MyKit/globalFunction(_:considering:)", parent: parentID).identifier.precise, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
        XCTAssertEqual(try tree.findSymbol(path: "/MyKit/globalFunction(_:considering:)", parent: parentID).identifier.precise, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
          
        let myKidModuleID = try tree.find(path: "/MyKit", onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "globalFunction(_:considering:)", parent: myKidModuleID).identifier.precise, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
        XCTAssertEqual(try tree.findSymbol(path: "MyKit/globalFunction(_:considering:)", parent: myKidModuleID).identifier.precise, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
        XCTAssertEqual(try tree.findSymbol(path: "/MyKit/globalFunction(_:considering:)", parent: myKidModuleID).identifier.precise, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
        
        XCTAssertEqual(try tree.findSymbol(path: "MyClass/init()-33vaw", parent: myKidModuleID).identifier.precise, "s:5MyKit0A5ClassCACycfcDUPLICATE")
        
        // Test finding symbol from an extension
        let sideKidModuleID = try tree.find(path: "/SideKit", onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "UncuratedClass/angle", parent: sideKidModuleID).identifier.precise, "s:So14UncuratedClassCV5MyKitE5angle12CoreGraphics7CGFloatVSgvp")
        try assertFindsPath("/SideKit/SideClass/Element", in: tree, asSymbolID: "s:7SideKit0A5ClassC7Elementa")
        try assertFindsPath("/SideKit/SideClass/Element/inherited()", in: tree, asSymbolID: "s:7SideKit0A5::SYNTESIZED::inheritedFF")
        try assertPathCollision("/SideKit/SideProtocol/func()", in: tree, collisions: [
            ("s:5MyKit0A5MyProtocol0Afunc()DefaultImp", "2dxqn"),
            ("s:5MyKit0A5MyProtocol0Afunc()", "6ijsi"),
        ])
        try assertPathRaisesErrorMessage("/SideKit/SideProtocol/func()", in: tree, context: context, expectedErrorMessage: """
        Reference is ambiguous after '/SideKit/SideProtocol': \
        Append '-2dxqn' to refer to 'func1()'. \
        Append '-6ijsi' to refer to 'func1()'.
        """) // This test data have the same declaration for both symbols.
        
        try assertFindsPath("/FillIntroduced/iOSOnlyDeprecated()", in: tree, asSymbolID: "s:14FillIntroduced17iOSOnlyDeprecatedyyF")
        try assertFindsPath("/FillIntroduced/macCatalystOnlyIntroduced()", in: tree, asSymbolID: "s:14FillIntroduced015macCatalystOnlyB0yyF")
        
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        try assertFindsPath("/SideKit/UncuratedClass", in: tree, asSymbolID: "s:7SideKit14UncuratedClassC")
        XCTAssertEqual(paths["s:7SideKit14UncuratedClassC"],
                       "/SideKit/UncuratedClass")
        
        // Test finding non-symbol children
        let discussionID = try tree.find(path: "/SideKit#Discussion", onlyFindSymbols: false)
        XCTAssertNil(tree.lookup[discussionID]!.symbol)
        XCTAssertEqual(tree.lookup[discussionID]!.name, "Discussion")
        
        let protocolImplementationsID = try tree.find(path: "/SideKit/SideClass/Element/Protocol-Implementations", onlyFindSymbols: false)
        XCTAssertNil(tree.lookup[protocolImplementationsID]!.symbol)
        XCTAssertEqual(tree.lookup[protocolImplementationsID]!.name, "Protocol-Implementations")
        
        let landmarkID = try tree.find(path: "/Test-Bundle/TestTutorial#Create-a-New-AR-Project-💻", onlyFindSymbols: false)
        XCTAssertNil(tree.lookup[landmarkID]!.symbol)
        XCTAssertEqual(tree.lookup[landmarkID]!.name, "Create-a-New-AR-Project-💻")
        
        let articleID = try tree.find(path: "/Test-Bundle/Default-Code-Listing-Syntax", onlyFindSymbols: false)
        XCTAssertNil(tree.lookup[articleID]!.symbol)
        XCTAssertEqual(tree.lookup[articleID]!.name, "Default-Code-Listing-Syntax")
    }
    
    func testMixedLanguageFramework() throws {
        try XCTSkipUnless(LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver)
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFramework")
        let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
        
        try assertFindsPath("MixedLanguageFramework/Bar/myStringFunction(_:)", in: tree, asSymbolID: "c:objc(cs)Bar(cm)myStringFunction:error:")
        try assertFindsPath("MixedLanguageFramework/Bar/myStringFunction:error:", in: tree, asSymbolID: "c:objc(cs)Bar(cm)myStringFunction:error:")

        try assertPathCollision("MixedLanguageFramework/Foo", in: tree, collisions: [
            ("c:@E@Foo", "enum"),
            ("c:@E@Foo", "struct"),
            ("c:MixedLanguageFramework.h@T@Foo", "typealias"),
        ])
        try assertPathRaisesErrorMessage("MixedLanguageFramework/Foo", in: tree, context: context, expectedErrorMessage: """
        Reference is ambiguous after '/MixedLanguageFramework': \
        Append '-enum' to refer to 'typedef enum Foo : NSString { ... } Foo;'. \
        Append '-struct' to refer to 'struct Foo'. \
        Append '-typealias' to refer to 'typedef enum Foo : NSString { ... } Foo;'.
        """) // The 'enum' and 'typealias' symbols have multi-line declarations that are presented on a single line
        
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
        try XCTSkipUnless(LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver)
        let (_, context) = try testBundleAndContext(named: "OverloadedSymbols")
        let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
        
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
        
        // This is the only enum case and can be disambiguated as such
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameyACSScACmF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-enum.case")
        // These are all methods and can only be disambiguated with the USR hash
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSiF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-14g8s")
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSfF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-14ife")
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSSF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-14ob0")
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameyS2dF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-4ja8m")
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSaySdGF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-88rbf")
    }
    
    func testSnippets() throws {
        try XCTSkipUnless(LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver)
        let (_, context) = try testBundleAndContext(named: "Snippets")
        let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
        
        try assertFindsPath("/Snippets/Snippets/MySnippet", in: tree, asSymbolID: "$snippet__Test.Snippets.MySnippet")
        
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        XCTAssertEqual(paths["$snippet__Test.Snippets.MySnippet"],
                       "/Snippets/Snippets/MySnippet")
        
        // Test relative links from the article that overlap with the snippet's path
        let snippetsArticleID = try tree.find(path: "/Snippets/Snippets", onlyFindSymbols: false)
        XCTAssertEqual(try tree.findSymbol(path: "MySnippet", parent: snippetsArticleID).identifier.precise, "$snippet__Test.Snippets.MySnippet")
        XCTAssertEqual(try tree.findSymbol(path: "Snippets/MySnippet", parent: snippetsArticleID).identifier.precise, "$snippet__Test.Snippets.MySnippet")
        XCTAssertEqual(try tree.findSymbol(path: "Snippets/Snippets/MySnippet", parent: snippetsArticleID).identifier.precise, "$snippet__Test.Snippets.MySnippet")
        XCTAssertEqual(try tree.findSymbol(path: "/Snippets/Snippets/MySnippet", parent: snippetsArticleID).identifier.precise, "$snippet__Test.Snippets.MySnippet")
        
        // Test relative links from another article (which doesn't overlap with the snippet's path)
        let sliceArticleID = try tree.find(path: "/Snippets/SliceIndentation", onlyFindSymbols: false)
        XCTAssertThrowsError(try tree.findSymbol(path: "MySnippet", parent: sliceArticleID))
        XCTAssertEqual(try tree.findSymbol(path: "Snippets/MySnippet", parent: sliceArticleID).identifier.precise, "$snippet__Test.Snippets.MySnippet")
        XCTAssertEqual(try tree.findSymbol(path: "Snippets/Snippets/MySnippet", parent: sliceArticleID).identifier.precise, "$snippet__Test.Snippets.MySnippet")
        XCTAssertEqual(try tree.findSymbol(path: "/Snippets/Snippets/MySnippet", parent: sliceArticleID).identifier.precise, "$snippet__Test.Snippets.MySnippet")
    }
    
    func testInheritedOperators() throws {
        try XCTSkipUnless(LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver)
        let (_, context) = try testBundleAndContext(named: "InheritedOperators")
        let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
        
        // public struct MyNumber: SignedNumeric, Comparable, Equatable, Hashable {
        //     ... stub minimal conformance
        // }
        let myNumberID = try tree.find(path: "/Operators/MyNumber", onlyFindSymbols: true)
        
        XCTAssertEqual(try tree.findSymbol(path: "!=(_:_:)", parent: myNumberID).identifier.precise, "s:SQsE2neoiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        
        XCTAssertEqual(try tree.findSymbol(path: "+(_:_:)", parent: myNumberID).identifier.precise, "s:9Operators8MyNumberV1poiyA2C_ACtFZ")
        XCTAssertEqual(try tree.findSymbol(path: "+(_:)", parent: myNumberID).identifier.precise, "s:s18AdditiveArithmeticPsE1popyxxFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "+=(_:_:)", parent: myNumberID).identifier.precise, "s:s18AdditiveArithmeticPsE2peoiyyxz_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        
        XCTAssertEqual(try tree.findSymbol(path: "-(_:_:)", parent: myNumberID).identifier.precise, "s:9Operators8MyNumberV1soiyA2C_ACtFZ")
        XCTAssertEqual(try tree.findSymbol(path: "-(_:)", parent: myNumberID).identifier.precise, "s:s13SignedNumericPsE1sopyxxFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "-=(_:_:)", parent: myNumberID).identifier.precise, "s:s18AdditiveArithmeticPsE2seoiyyxz_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        
        XCTAssertEqual(try tree.findSymbol(path: "*(_:_:)", parent: myNumberID).identifier.precise, "s:9Operators8MyNumberV1moiyA2C_ACtFZ")
        XCTAssertEqual(try tree.findSymbol(path: "*=(_:_:)", parent: myNumberID).identifier.precise, "s:9Operators8MyNumberV2meoiyyACz_ACtFZ")
        
        XCTAssertEqual(try tree.findSymbol(path: "...(_:)-28faz", parent: myNumberID).identifier.precise, "s:SLsE3zzzoPys16PartialRangeFromVyxGxFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "...(_:)-8ooeh", parent: myNumberID).identifier.precise, "s:SLsE3zzzopys19PartialRangeThroughVyxGxFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "...(_:_:)", parent: myNumberID).identifier.precise, "s:SLsE3zzzoiySNyxGx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "..<(_:)", parent: myNumberID).identifier.precise, "s:SLsE3zzlopys16PartialRangeUpToVyxGxFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "..<(_:_:)", parent: myNumberID).identifier.precise, "s:SLsE3zzloiySnyxGx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        
        XCTAssertEqual(try tree.findSymbol(path: "<(_:_:)", parent: myNumberID).identifier.precise, "s:9Operators8MyNumberV1loiySbAC_ACtFZ")
        XCTAssertEqual(try tree.findSymbol(path: ">(_:_:)", parent: myNumberID).identifier.precise, "s:SLsE1goiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "<=(_:_:)", parent: myNumberID).identifier.precise, "s:SLsE2leoiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: ">=(_:_:)", parent: myNumberID).identifier.precise, "s:SLsE2geoiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        
        // Unmodified operator name in URL
        XCTAssertEqual("/Operators/MyNumber/!=(_:_:)", paths["s:SQsE2neoiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        XCTAssertEqual("/Operators/MyNumber/+(_:_:)", paths["s:9Operators8MyNumberV1poiyA2C_ACtFZ"])
        XCTAssertEqual("/Operators/MyNumber/+(_:)", paths["s:s18AdditiveArithmeticPsE1popyxxFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        XCTAssertEqual("/Operators/MyNumber/+=(_:_:)", paths["s:s18AdditiveArithmeticPsE2peoiyyxz_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        XCTAssertEqual("/Operators/MyNumber/-(_:_:)", paths["s:9Operators8MyNumberV1soiyA2C_ACtFZ"])
        XCTAssertEqual("/Operators/MyNumber/-(_:)", paths["s:s13SignedNumericPsE1sopyxxFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        XCTAssertEqual("/Operators/MyNumber/-=(_:_:)", paths["s:s18AdditiveArithmeticPsE2seoiyyxz_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        XCTAssertEqual("/Operators/MyNumber/*(_:_:)", paths["s:9Operators8MyNumberV1moiyA2C_ACtFZ"])
        XCTAssertEqual("/Operators/MyNumber/*=(_:_:)", paths["s:9Operators8MyNumberV2meoiyyACz_ACtFZ"])
        XCTAssertEqual("/Operators/MyNumber/...(_:)-28faz", paths["s:SLsE3zzzoPys16PartialRangeFromVyxGxFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        XCTAssertEqual("/Operators/MyNumber/...(_:)-8ooeh", paths["s:SLsE3zzzopys19PartialRangeThroughVyxGxFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        XCTAssertEqual("/Operators/MyNumber/...(_:_:)", paths["s:SLsE3zzzoiySNyxGx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        
        // "<" is replaced with "_" without introducing ambiguity
        XCTAssertEqual("/Operators/MyNumber/.._(_:)", paths["s:SLsE3zzlopys16PartialRangeUpToVyxGxFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        XCTAssertEqual("/Operators/MyNumber/.._(_:_:)", paths["s:SLsE3zzloiySnyxGx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        
        // "<" and ">" are not allowed in paths of URLs resulting in added ambiguity.
        XCTAssertEqual("/Operators/MyNumber/_(_:_:)-736gk",  /* <(_:_:) */ paths["s:9Operators8MyNumberV1loiySbAC_ACtFZ"])
        XCTAssertEqual("/Operators/MyNumber/_(_:_:)-21jxf",  /* >(_:_:) */ paths["s:SLsE1goiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        XCTAssertEqual("/Operators/MyNumber/_=(_:_:)-9uewk", /* <=(_:_:) */ paths["s:SLsE2leoiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        XCTAssertEqual("/Operators/MyNumber/_=(_:_:)-70j0d", /* >=(_:_:) */ paths["s:SLsE2geoiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
    }
    
    func testOneSymbolPathsWithKnownDisambiguation() throws {
        try XCTSkipUnless(LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver)
        let exampleDocumentation = Folder(name: "MyKit.docc", content: [
            CopyOfFile(original: Bundle.module.url(forResource: "mykit-one-symbol.symbols", withExtension: "json", subdirectory: "Test Resources")!),
            InfoPlist(displayName: "MyKit", identifier: "com.test.MyKit"),
        ])
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try exampleDocumentation.write(inside: tempURL)

        do {
            let (_, _, context) = try loadBundle(from: bundleURL)
            let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
            
            try assertFindsPath("/MyKit/MyClass/myFunction()", in: tree, asSymbolID: "s:5MyKit0A5ClassC10myFunctionyyF")
            try assertPathNotFound("/MyKit/MyClass-swift.class/myFunction()", in: tree)
            try assertPathNotFound("/MyKit/MyClass", in: tree)
            
            XCTAssertEqual(tree.caseInsensitiveDisambiguatedPaths()["s:5MyKit0A5ClassC10myFunctionyyF"],
                           "/MyKit/MyClass/myFunction()")
            
            XCTAssertEqual(context.symbolIndex["s:5MyKit0A5ClassC10myFunctionyyF"]?.reference.path,
                           "/documentation/MyKit/MyClass/myFunction()")
        }
        
        do {
            let (_, _, context) = try loadBundle(from: bundleURL) { context in
                context.knownDisambiguatedSymbolPathComponents = [
                    "s:5MyKit0A5ClassC10myFunctionyyF": ["MyClass-swift.class", "myFunction()"]
                ]
            }
            let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
            
            try assertFindsPath("/MyKit/MyClass-swift.class/myFunction()", in: tree, asSymbolID: "s:5MyKit0A5ClassC10myFunctionyyF")
            try assertPathNotFound("/MyKit/MyClass", in: tree)
            try assertPathNotFound("/MyKit/MyClass-swift.class", in: tree)
            
            XCTAssertEqual(tree.caseInsensitiveDisambiguatedPaths()["s:5MyKit0A5ClassC10myFunctionyyF"],
                           "/MyKit/MyClass-class/myFunction()")
            
            XCTAssertEqual(context.symbolIndex["s:5MyKit0A5ClassC10myFunctionyyF"]?.reference.path,
                           "/documentation/MyKit/MyClass-swift.class/myFunction()")
        }
        
        do {
            let (_, _, context) = try loadBundle(from: bundleURL) { context in
                context.knownDisambiguatedSymbolPathComponents = [
                    "s:5MyKit0A5ClassC10myFunctionyyF": ["MyClass-swift.class-hash", "myFunction()"]
                ]
            }
            let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
            
            try assertFindsPath("/MyKit/MyClass-swift.class-hash/myFunction()", in: tree, asSymbolID: "s:5MyKit0A5ClassC10myFunctionyyF")
            try assertPathNotFound("/MyKit/MyClass", in: tree)
            try assertPathNotFound("/MyKit/MyClass-swift.class", in: tree)
            try assertPathNotFound("/MyKit/MyClass-swift.class-hash", in: tree)
            
            
            XCTAssertEqual(tree.caseInsensitiveDisambiguatedPaths()["s:5MyKit0A5ClassC10myFunctionyyF"],
                           "/MyKit/MyClass-class-hash/myFunction()")
            
            XCTAssertEqual(context.symbolIndex["s:5MyKit0A5ClassC10myFunctionyyF"]?.reference.path,
                           "/documentation/MyKit/MyClass-swift.class-hash/myFunction()")
        }
    }
    
    func testPartialSymbolGraphPaths() throws {
        try XCTSkipUnless(LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver)
        let symbolPaths = [
            ["A", "B", "C"],
            ["A", "B", "C2"],
            ["X", "Y"],
            ["X", "Y2", "Z", "W"],
        ]
        let graph = SymbolGraph(
            metadata: SymbolGraph.Metadata(
                formatVersion: SymbolGraph.SemanticVersion(major: 1, minor: 1, patch: 1),
                generator: "unit-test"
            ),
            module: SymbolGraph.Module(
                name: "Module",
                platform: SymbolGraph.Platform(architecture: nil, vendor: nil, operatingSystem: nil)
            ),
            symbols: symbolPaths.map {
                SymbolGraph.Symbol(
                    identifier: SymbolGraph.Symbol.Identifier(precise: $0.joined(separator: "."), interfaceLanguage: "swift"),
                    names: SymbolGraph.Symbol.Names(title: "Title", navigator: nil, subHeading: nil, prose: nil), // names doesn't matter for path disambiguation
                    pathComponents: $0,
                    docComment: nil,
                    accessLevel: SymbolGraph.Symbol.AccessControl(rawValue: "public"),
                    kind: SymbolGraph.Symbol.Kind(parsedIdentifier: .class, displayName: "Kind Display Name"), // kind display names doesn't matter for path disambiguation
                    mixins: [:]
                )
            },
            relationships: []
        )
        let exampleDocumentation = Folder(name: "MyKit.docc", content: [
            try TextFile(name: "mykit.symbols.json", utf8Content: XCTUnwrap(String(data: JSONEncoder().encode(graph), encoding: .utf8))),
            InfoPlist(displayName: "MyKit", identifier: "com.test.MyKit"),
        ])
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try exampleDocumentation.write(inside: tempURL)
        
        let (_, _, context) = try loadBundle(from: bundleURL)
        let tree = try XCTUnwrap(context.hierarchyBasedLinkResolver?.pathHierarchy)
        
        try assertPathNotFound("/Module/A", in: tree)
        try assertPathNotFound("/Module/A/B", in: tree)
        try assertFindsPath("/Module/A/B/C", in: tree, asSymbolID: "A.B.C")
        try assertFindsPath("/Module/A/B/C2", in: tree, asSymbolID: "A.B.C2")
        
        try assertPathNotFound("/Module/X", in: tree)
        try assertFindsPath("/Module/X/Y", in: tree, asSymbolID: "X.Y")
        try assertPathNotFound("/Module/X/Y2", in: tree)
        try assertPathNotFound("/Module/X/Y2/Z", in: tree)
        try assertFindsPath("/Module/X/Y2/Z/W", in: tree, asSymbolID: "X.Y2.Z.W")
        
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        XCTAssertEqual(paths.keys.sorted(), ["A.B.C", "A.B.C2", "Module", "X.Y", "X.Y2.Z.W"])
        XCTAssertEqual(paths["A.B.C"], "/Module/A/B/C")
        XCTAssertEqual(paths["A.B.C2"], "/Module/A/B/C2")
        XCTAssertEqual(paths["X.Y"], "/Module/X/Y")
        XCTAssertEqual(paths["X.Y2.Z.W"], "/Module/X/Y2/Z/W")
    }
    
    func testParsingPaths() {
        // Check path components without disambiguation
        assertParsedPathComponents("", [])
        assertParsedPathComponents("/", [])
        assertParsedPathComponents("/first", [("first", nil, nil)])
        assertParsedPathComponents("first", [("first", nil, nil)])
        assertParsedPathComponents("first/second/third", [("first", nil, nil), ("second", nil, nil), ("third", nil, nil)])
        assertParsedPathComponents("first/", [("first", nil, nil)])
        assertParsedPathComponents("first//second", [("first", nil, nil), ("second", nil, nil)])
        assertParsedPathComponents("first/second#third", [("first", nil, nil), ("second", nil, nil), ("third", nil, nil)])

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
    
    private func assertFindsPath(_ path: String, in tree: PathHierarchy, asSymbolID symbolID: String, file: StaticString = #file, line: UInt = #line) throws {
        do {
            let symbol = try tree.findSymbol(path: path)
            XCTAssertEqual(symbol.identifier.precise, symbolID, file: file, line: line)
        } catch PathHierarchy.Error.notFound {
            XCTFail("Symbol for \(path.singleQuoted) not found in tree", file: file, line: line)
        } catch PathHierarchy.Error.partialResult {
            XCTFail("Symbol for \(path.singleQuoted) not found in tree. Only part of path is found.", file: file, line: line)
        } catch PathHierarchy.Error.lookupCollision(_, let collisions) {
            let symbols = collisions.map { $0.node.symbol! }
            XCTFail("Unexpected collision for \(path.singleQuoted); \(symbols.map { return "\($0.names.title) - \($0.kind.identifier.identifier) - \($0.identifier.precise.stableHashString)"})", file: file, line: line)
        }
    }
    
    private func assertPathNotFound(_ path: String, in tree: PathHierarchy, file: StaticString = #file, line: UInt = #line) throws {
        do {
            let symbol = try tree.findSymbol(path: path)
            XCTFail("Unexpectedly found symbol with ID \(symbol.identifier.precise) for path \(path.singleQuoted)", file: file, line: line)
        } catch PathHierarchy.Error.notFound, PathHierarchy.Error.unfindableMatch, PathHierarchy.Error.nonSymbolMatchForSymbolLink {
            // This specific error is expected.
        } catch PathHierarchy.Error.partialResult {
            // For the purpose of this assertion, this also counts as "not found".
        } catch PathHierarchy.Error.lookupCollision(_, let collisions) {
            let symbols = collisions.map { $0.node.symbol! }
            XCTFail("Unexpected collision for \(path.singleQuoted); \(symbols.map { return "\($0.names.title) - \($0.kind.identifier.identifier) - \($0.identifier.precise.stableHashString)"})", file: file, line: line)
        }
    }
    
    private func assertPathCollision(_ path: String, in tree: PathHierarchy, collisions expectedCollisions: [(symbolID: String, disambiguation: String)], file: StaticString = #file, line: UInt = #line) throws {
        do {
            let symbol = try tree.findSymbol(path: path)
            XCTFail("Unexpectedly found unambiguous symbol with ID \(symbol.identifier.precise) for path \(path.singleQuoted)", file: file, line: line)
        } catch PathHierarchy.Error.notFound {
            XCTFail("Symbol for \(path.singleQuoted) not found in tree", file: file, line: line)
        } catch PathHierarchy.Error.partialResult {
            XCTFail("Symbol for \(path.singleQuoted) not found in tree. Only part of path is found.", file: file, line: line)
        } catch PathHierarchy.Error.lookupCollision(_, let collisions) {
            let sortedCollisions = collisions.sorted(by: \.disambiguation)
            XCTAssertEqual(sortedCollisions.count, expectedCollisions.count, file: file, line: line)
            for (actual, expected) in zip(sortedCollisions, expectedCollisions) {
                XCTAssertEqual(actual.node.symbol?.identifier.precise, expected.symbolID, file: file, line: line)
                XCTAssertEqual(actual.disambiguation, expected.disambiguation, file: file, line: line)
            }
        }
    }
    
    private func assertPathRaisesErrorMessage(_ path: String, in tree: PathHierarchy, context: DocumentationContext, expectedErrorMessage: String, file: StaticString = #file, line: UInt = #line) throws {
        XCTAssertThrowsError(try tree.findSymbol(path: path), "Finding path \(path) didn't raise an error.",file: file,line: line) { untypedError in
            let error = untypedError as! PathHierarchy.Error
            let errorMessage = error.errorMessage(context: context)
            XCTAssertEqual(errorMessage, expectedErrorMessage, file: file, line: line)
        }
    }
    
    private func assertParsedPathComponents(_ path: String, _ expected: [(String, String?, String?)], file: StaticString = #file, line: UInt = #line) {
        let (actual, _) = PathHierarchy.parse(path: path)
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (actualComponents, expectedComponents) in zip(actual, expected) {
            XCTAssertEqual(actualComponents.name, expectedComponents.0, "Incorrect path component", file: file, line: line)
            XCTAssertEqual(actualComponents.kind, expectedComponents.1, "Incorrect kind disambiguation", file: file, line: line)
            XCTAssertEqual(actualComponents.hash, expectedComponents.2, "Incorrect hash disambiguation", file: file, line: line)
        }
    }
}

extension PathHierarchy {
    func findSymbol(path rawPath: String, parent: ResolvedIdentifier? = nil) throws -> SymbolGraph.Symbol {
        let id = try find(path: rawPath, parent: parent, onlyFindSymbols: true)
        return lookup[id]!.symbol!
    }
}
