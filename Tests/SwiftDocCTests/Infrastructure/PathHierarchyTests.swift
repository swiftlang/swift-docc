/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SymbolKit
@testable import SwiftDocC
import SwiftDocCTestUtilities
import Markdown

class PathHierarchyTests: XCTestCase {
    
    func testFindingUnambiguousAbsolutePaths() throws {
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFrameworkWithLanguageRefinements")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
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
        
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)-(Int)", in: tree, asSymbolID: "s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentS2i_tF")
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)-(String)", in: tree, asSymbolID: "s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentSiSS_tF")
        
        // public enum CollisionsWithDifferentSubscriptArguments {
        //     public subscript(something: Int) -> Int { 0 }
        //     public subscript(somethingElse: String) -> Int { 0 }
        // }
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentSubscriptArguments", in: tree, asSymbolID: "s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsO")
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)-4fd0l", in: tree, asSymbolID: "s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOyS2icip")
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)-757cj", in: tree, asSymbolID: "s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOySiSScip")
        
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)-(Int)", in: tree, asSymbolID: "s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOyS2icip")
        try assertFindsPath("/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)-(String)", in: tree, asSymbolID: "s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOySiSScip")
        
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
        let originalFeatureFlagsState = FeatureFlags.current
        FeatureFlags.current.isExperimentalLinkHierarchySerializationEnabled = true
        defer {
            FeatureFlags.current = originalFeatureFlagsState
        }
        
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFrameworkWithLanguageRefinements")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        // Symbol name not found. Suggestions only include module names (search is not relative to a known page)
        try assertPathRaisesErrorMessage("/MixFramework", in: tree, context: context, expectedErrorMessage: """
        No module named 'MixFramework'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Replace 'MixFramework' with 'MixedFramework'", replacements: [("MixedFramework", 1, 13)]),
            ])
        }
        try assertPathRaisesErrorMessage("/documentation/MixFramework", in: tree, context: context, expectedErrorMessage: """
        No module named 'MixFramework'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Replace 'MixFramework' with 'MixedFramework'", replacements: [("MixedFramework", 15, 27)]),
            ])
        }
        
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
        'something' is ambiguous at '/MixedFramework/CollisionsWithDifferentKinds'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Insert 'enum.case' for \n'case something'", replacements: [("-enum.case", 54, 54)]),
                .init(summary: "Insert 'property' for \n'var something: String { get }'", replacements: [("-property", 54, 54)]),
            ])
        }
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithDifferentKinds/something-class", in: tree, context: context, expectedErrorMessage: """
        'class' isn't a disambiguation for 'something' at '/MixedFramework/CollisionsWithDifferentKinds'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Replace 'class' with 'enum.case' for \n'case something'", replacements: [("-enum.case", 54, 60)]),
                .init(summary: "Replace 'class' with 'property' for \n'var something: String { get }'", replacements: [("-property", 54, 60)]),
            ])
        }
        
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
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithEscapedKeywords/init()-abc123", in: tree, context: context, expectedErrorMessage: """
        'abc123' isn't a disambiguation for 'init()' at '/MixedFramework/CollisionsWithEscapedKeywords'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Replace 'abc123' with 'method' for \n'func `init`()'", replacements: [("-method", 52, 59)]),
                .init(summary: "Replace 'abc123' with 'init' for \n'init()'", replacements: [("-init", 52, 59)]),
                .init(summary: "Replace 'abc123' with 'type.method' for \n'static func `init`()'", replacements: [("-type.method", 52, 59)]),
            ])
        }
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithEscapedKeywords/init()", in: tree, context: context, expectedErrorMessage: """
        'init()' is ambiguous at '/MixedFramework/CollisionsWithEscapedKeywords'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Insert 'method' for \n'func `init`()'", replacements: [("-method", 52, 52)]),
                .init(summary: "Insert 'init' for \n'init()'", replacements: [("-init", 52, 52)]),
                .init(summary: "Insert 'type.method' for \n'static func `init`()'", replacements: [("-type.method", 52, 52)]),
            ])
        }
        // Providing disambiguation will narrow down the suggestions. Note that `()` is missing in the last path component
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithEscapedKeywords/init-method", in: tree, context: context, expectedErrorMessage: """
        'init-method' doesn't exist at '/MixedFramework/CollisionsWithEscapedKeywords'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Replace 'init' with 'init()'", replacements: [("init()", 46, 50)]), // The disambiguation is not replaced so the suggested link is unambiguous
            ])
        }
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithEscapedKeywords/init-init", in: tree, context: context, expectedErrorMessage: """
        'init-init' doesn't exist at '/MixedFramework/CollisionsWithEscapedKeywords'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Replace 'init' with 'init()'", replacements: [("init()", 46, 50)]), // The disambiguation is not replaced so the suggested link is unambiguous
            ])
        }
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithEscapedKeywords/init-type.method", in: tree, context: context, expectedErrorMessage: """
        'init-type.method' doesn't exist at '/MixedFramework/CollisionsWithEscapedKeywords'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Replace 'init' with 'init()'", replacements: [("init()", 46, 50)]), // The disambiguation is not replaced so the suggested link is unambiguous
            ])
        }
        
        try assertPathCollision("/MixedFramework/CollisionsWithEscapedKeywords/subscript()", in: tree, collisions: [
            (symbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsC9subscriptyyF", disambiguation: "method"),
            (symbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsCSiycip", disambiguation: "subscript"),
            (symbolID: "s:14MixedFramework29CollisionsWithEscapedKeywordsC9subscriptyyFZ", disambiguation: "type.method"),
        ])
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithEscapedKeywords/subscript()", in: tree, context: context, expectedErrorMessage: """
        'subscript()' is ambiguous at '/MixedFramework/CollisionsWithEscapedKeywords'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Insert 'method' for \n'func `subscript`()'", replacements: [("-method", 57, 57)]),
                .init(summary: "Insert 'type.method' for \n'static func `subscript`()'", replacements: [("-type.method", 57, 57)]),
                .init(summary: "Insert 'subscript' for \n'subscript() -> Int { get }'", replacements: [("-subscript", 57, 57)]),
            ])
        }
        
        // public enum CollisionsWithDifferentFunctionArguments {
        //     public func something(argument: Int) -> Int { 0 }
        //     public func something(argument: String) -> Int { 0 }
        // }
        try assertPathCollision("/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)", in: tree, collisions: [
            (symbolID: "s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentS2i_tF", disambiguation: "(Int)"),
            (symbolID: "s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentSiSS_tF", disambiguation: "(String)"),
        ])
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)", in: tree, context: context, expectedErrorMessage: """
        'something(argument:)' is ambiguous at '/MixedFramework/CollisionsWithDifferentFunctionArguments'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Insert '(Int)' for \n'func something(argument: Int) -> Int'", replacements: [("-(Int)", 77, 77)]),
                .init(summary: "Insert '(String)' for \n'func something(argument: String) -> Int'", replacements: [("-(String)", 77, 77)]),
            ])
        }
        // The path starts with "/documentation" which is optional
        try assertPathRaisesErrorMessage("/documentation/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)", in: tree, context: context, expectedErrorMessage: """
        'something(argument:)' is ambiguous at '/MixedFramework/CollisionsWithDifferentFunctionArguments'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Insert '(Int)' for \n'func something(argument: Int) -> Int'", replacements: [("-(Int)", 91, 91)]),
                .init(summary: "Insert '(String)' for \n'func something(argument: String) -> Int'", replacements: [("-(String)", 91, 91)]),
            ])
        }
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)-abc123", in: tree, context: context, expectedErrorMessage: """
        'abc123' isn't a disambiguation for 'something(argument:)' at '/MixedFramework/CollisionsWithDifferentFunctionArguments'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Replace 'abc123' with '(Int)' for \n'func something(argument: Int) -> Int'", replacements: [("-(Int)", 77, 84)]),
                .init(summary: "Replace 'abc123' with '(String)' for \n'func something(argument: String) -> Int'", replacements: [("-(String)", 77, 84)]),
            ])
        }
        // Providing disambiguation will narrow down the suggestions. Note that `argument` label is missing in the last path component
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithDifferentFunctionArguments/something(_:)-1cyvp", in: tree, context: context, expectedErrorMessage: """
        'something(_:)-1cyvp' doesn't exist at '/MixedFramework/CollisionsWithDifferentFunctionArguments'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Replace 'something(_:)' with 'something(argument:)'", replacements: [("something(argument:)", 57, 70)]), // The disambiguation is not replaced so the suggested link is unambiguous
            ])
        }
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithDifferentFunctionArguments/something(_:)-2vke2", in: tree, context: context, expectedErrorMessage: """
        'something(_:)-2vke2' doesn't exist at '/MixedFramework/CollisionsWithDifferentFunctionArguments'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Replace 'something(_:)' with 'something(argument:)'", replacements: [("something(argument:)", 57, 70)]), // The disambiguation is not replaced so the suggested link is unambiguous
            ])
        }
        
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)-method", in: tree, context: context, expectedErrorMessage: """
        'something(argument:)-method' is ambiguous at '/MixedFramework/CollisionsWithDifferentFunctionArguments'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Replace 'method' with '(Int)' for \n'func something(argument: Int) -> Int'", replacements: [("-(Int)", 77, 84)]),
                .init(summary: "Replace 'method' with '(String)' for \n'func something(argument: String) -> Int'", replacements: [("-(String)", 77, 84)]),
            ])
        }
        // The path starts with "/documentation" which is optional
        try assertPathRaisesErrorMessage("/documentation/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)-method", in: tree, context: context, expectedErrorMessage: """
        'something(argument:)-method' is ambiguous at '/MixedFramework/CollisionsWithDifferentFunctionArguments'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Replace 'method' with '(Int)' for \n'func something(argument: Int) -> Int'", replacements: [("-(Int)", 91, 98)]),
                .init(summary: "Replace 'method' with '(String)' for \n'func something(argument: String) -> Int'", replacements: [("-(String)", 91, 98)]),
            ])
        }
        
        // public enum CollisionsWithDifferentSubscriptArguments {
        //     public subscript(something: Int) -> Int { 0 }
        //     public subscript(somethingElse: String) -> Int { 0 }
        // }
        try assertPathCollision("/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)", in: tree, collisions: [
            (symbolID: "s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOyS2icip", disambiguation: "(Int)"),
            (symbolID: "s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOySiSScip", disambiguation: "(String)"),
        ])
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)", in: tree, context: context, expectedErrorMessage: """
        'subscript(_:)' is ambiguous at '/MixedFramework/CollisionsWithDifferentSubscriptArguments'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Insert '(Int)' for \n'subscript(something: Int) -> Int { get }'", replacements: [("-(Int)", 71, 71)]),
                .init(summary: "Insert '(String)' for \n'subscript(somethingElse: String) -> Int { get }'", replacements: [("-(String)", 71, 71)]),
            ])
        }
        
        try assertPathRaisesErrorMessage("/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)-subscript", in: tree, context: context, expectedErrorMessage: """
        'subscript(_:)-subscript' is ambiguous at '/MixedFramework/CollisionsWithDifferentSubscriptArguments'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Replace 'subscript' with '(Int)' for \n'subscript(something: Int) -> Int { get }'", replacements: [("-(Int)", 71, 81)]),
                .init(summary: "Replace 'subscript' with '(String)' for \n'subscript(somethingElse: String) -> Int { get }'", replacements: [("-(String)", 71, 81)]),
            ])
        }
        
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
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFrameworkWithLanguageRefinements")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
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
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFrameworkWithLanguageRefinements")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
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
    
    func testDefaultImplementationWithCollidingTargetSymbol() throws {
 
        // ---- Inner
        // public protocol Something {
        //     func doSomething()
        // }
        // public extension Something {
        //     func doSomething() {}
        // }
        //
        // ---- Outer
        // @_exported import Inner
        // public typealias Something = Inner.Something
        let (_, context) = try testBundleAndContext(named: "DefaultImplementationsWithExportedImport")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        // The @_export imported protocol can be found
        try assertFindsPath("/DefaultImplementationsWithExportedImport/Something-protocol", in: tree, asSymbolID: "s:5Inner9SomethingP")
        // The wrapping type alias can be found
        try assertFindsPath("/DefaultImplementationsWithExportedImport/Something-typealias", in: tree, asSymbolID: "s:40DefaultImplementationsWithExportedImport9Somethinga")
        
        // The protocol requirement and the default implementation both exist at the @_export imported Something protocol.
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        XCTAssertEqual(paths["s:5Inner9SomethingP02doB0yyF"],    "/DefaultImplementationsWithExportedImport/Something/doSomething()-8skxc")
        XCTAssertEqual(paths["s:5Inner9SomethingPAAE02doB0yyF"], "/DefaultImplementationsWithExportedImport/Something/doSomething()-scj9")
        
        // Test disfavoring a default implementation in a symbol collision
        try assertFindsPath("DefaultImplementationsWithExportedImport/Something-protocol/doSomething()", in: tree, asSymbolID: "s:5Inner9SomethingP02doB0yyF")
        try assertFindsPath("DefaultImplementationsWithExportedImport/Something-protocol/doSomething()-method", in: tree, asSymbolID: "s:5Inner9SomethingP02doB0yyF")
        try assertFindsPath("DefaultImplementationsWithExportedImport/Something-protocol/doSomething()-8skxc", in: tree, asSymbolID: "s:5Inner9SomethingP02doB0yyF")
        // Only with disambiguation does the link resolve to the default implementation symbol
        try assertFindsPath("DefaultImplementationsWithExportedImport/Something-protocol/doSomething()-scj9", in: tree, asSymbolID: "s:5Inner9SomethingPAAE02doB0yyF")
    }
    
    func testDisambiguatedPaths() throws {
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFrameworkWithLanguageRefinements")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
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
            "/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)-(Int)")
        XCTAssertEqual(
            paths["s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentSiSS_tF"],
            "/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)-(String)")
            
        let hashAndKindDisambiguatedPaths = tree.caseInsensitiveDisambiguatedPaths(allowAdvancedDisambiguation: false)

        XCTAssertEqual(
            hashAndKindDisambiguatedPaths["s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentS2i_tF"],
            "/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)-1cyvp")
        XCTAssertEqual(
            hashAndKindDisambiguatedPaths["s:14MixedFramework40CollisionsWithDifferentFunctionArgumentsO9something8argumentSiSS_tF"],
            "/MixedFramework/CollisionsWithDifferentFunctionArguments/something(argument:)-2vke2")
        
        // public enum CollisionsWithDifferentSubscriptArguments {
        //     public subscript(something: Int) -> Int { 0 }
        //     public subscript(somethingElse: String) -> Int { 0 }
        // }
        XCTAssertEqual(
            paths["s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOyS2icip"],
            "/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)-(Int)")
        XCTAssertEqual(
            paths["s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOySiSScip"],
            "/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)-(String)")
        
        XCTAssertEqual(
            hashAndKindDisambiguatedPaths["s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOyS2icip"],
            "/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)-4fd0l")
        XCTAssertEqual(
            hashAndKindDisambiguatedPaths["s:14MixedFramework41CollisionsWithDifferentSubscriptArgumentsOySiSScip"],
            "/MixedFramework/CollisionsWithDifferentSubscriptArguments/subscript(_:)-757cj")
    }
    
    func testDisambiguatedOperatorPaths() throws {
        let (_, context) = try testBundleAndContext(named: "InheritedOperators")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        let hashAndKindDisambiguatedPaths = tree.caseInsensitiveDisambiguatedPaths(allowAdvancedDisambiguation: false)
        
        // Operators where all characters in the operator name are also allowed in URL paths
        
        XCTAssertEqual(
            // static func * (lhs: MyNumber, rhs: MyNumber) -> MyNumber
            paths["s:9Operators8MyNumberV1moiyA2C_ACtFZ"],
            "/Operators/MyNumber/*(_:_:)")
        XCTAssertEqual(
            // static func *= (lhs: inout MyNumber, rhs: MyNumber)
            paths["s:9Operators8MyNumberV2meoiyyACz_ACtFZ"],
            "/Operators/MyNumber/*=(_:_:)")
        XCTAssertEqual(
            // static func - (lhs: MyNumber, rhs: MyNumber) -> MyNumber
            paths["s:9Operators8MyNumberV1soiyA2C_ACtFZ"],
            "/Operators/MyNumber/-(_:_:)")
        XCTAssertEqual(
            // static func + (lhs: MyNumber, rhs: MyNumber) -> MyNumber
            paths["s:9Operators8MyNumberV1poiyA2C_ACtFZ"],
            "/Operators/MyNumber/+(_:_:)")
        
        // Characters that are not allowed in URL paths are replaced with "_" (adding disambiguation if the replacement introduces conflicts)
        
        XCTAssertEqual(
            // static func < (lhs: MyNumber, rhs: MyNumber) -> Bool
            paths["s:9Operators8MyNumberV1loiySbAC_ACtFZ"],
            "/Operators/MyNumber/_(_:_:)-736gk")
        XCTAssertEqual(
            // static func <= (lhs: Self, rhs: Self) -> Bool
            paths["s:SLsE2leoiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV"],
            "/Operators/MyNumber/_=(_:_:)-9uewk")
        XCTAssertEqual(
            // static func > (lhs: Self, rhs: Self) -> Bool
            paths["s:SLsE1goiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV"],
            "/Operators/MyNumber/_(_:_:)-(Self,_)")
        XCTAssertEqual(
            // static func > (lhs: Self, rhs: Self) -> Bool
            hashAndKindDisambiguatedPaths["s:SLsE1goiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV"],
            "/Operators/MyNumber/_(_:_:)-21jxf")
        XCTAssertEqual(
            // static func >= (lhs: Self, rhs: Self) -> Bool
            paths["s:SLsE2geoiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV"],
            "/Operators/MyNumber/_=(_:_:)-70j0d")
        
        // "/" is a separator in URL paths so it's replaced with with "_" (adding disambiguation if the replacement introduces conflicts)
        
        XCTAssertEqual(
            // static func / (lhs: MyNumber, rhs: MyNumber) -> MyNumber
            paths["s:9Operators8MyNumberV1doiyA2C_ACtFZ"],
            "/Operators/MyNumber/_(_:_:)->MyNumber")
        XCTAssertEqual(
            // static func /= (lhs: inout MyNumber, rhs: MyNumber) -> MyNumber
            paths["s:9Operators8MyNumberV2deoiyA2Cz_ACtFZ"],
            "/Operators/MyNumber/_=(_:_:)->MyNumber")
        XCTAssertEqual(
            // static func / (lhs: MyNumber, rhs: MyNumber) -> MyNumber
            hashAndKindDisambiguatedPaths["s:9Operators8MyNumberV1doiyA2C_ACtFZ"],
            "/Operators/MyNumber/_(_:_:)-7am4")
        XCTAssertEqual(
            // static func /= (lhs: inout MyNumber, rhs: MyNumber) -> MyNumber
            hashAndKindDisambiguatedPaths["s:9Operators8MyNumberV2deoiyA2Cz_ACtFZ"],
            "/Operators/MyNumber/_=(_:_:)-3m4ko")
        
    }
    
    func testFindingRelativePaths() throws {
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFrameworkWithLanguageRefinements")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
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
        // Relative links can start with either language representation. This enabled documentation extension files to use relative links.
        XCTAssertEqual(try tree.findSymbol(path: "myPropertyObjectiveCName", parent: mySwiftClassSwiftID).identifier.precise, "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(py)myPropertyObjectiveCName")
        XCTAssertEqual(try tree.findSymbol(path: "myMethodObjectiveCName", parent: mySwiftClassSwiftID).identifier.precise, "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(im)myMethodObjectiveCName")
        // Links can't mix languages
        XCTAssertThrowsError(try tree.findSymbol(path: "MySwiftClassSwiftName/myPropertyObjectiveCName", parent: moduleID))
        XCTAssertThrowsError(try tree.findSymbol(path: "MySwiftClassSwiftName/myMethodObjectiveCName", parent: moduleID))
        
        let mySwiftClassObjCID = try tree.find(path: "MySwiftClassObjectiveCName", parent: moduleID, onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "myPropertyObjectiveCName", parent: mySwiftClassObjCID).identifier.precise, "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(py)myPropertyObjectiveCName")
        XCTAssertEqual(try tree.findSymbol(path: "myMethodObjectiveCName", parent: mySwiftClassObjCID).identifier.precise, "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(im)myMethodObjectiveCName")
        // Relative links can use either language representation. This enabled documentation extension files to use relative links.
        XCTAssertEqual(try tree.findSymbol(path: "myPropertySwiftName", parent: mySwiftClassObjCID).identifier.precise, "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(py)myPropertyObjectiveCName")
        XCTAssertEqual(try tree.findSymbol(path: "myMethodSwiftName()", parent: mySwiftClassObjCID).identifier.precise, "c:@M@MixedFramework@objc(cs)MySwiftClassObjectiveCName(im)myMethodObjectiveCName")
        // Absolute links can't mix languages
        XCTAssertThrowsError(try tree.findSymbol(path: "myPropertySwiftName", parent: moduleID))
        XCTAssertThrowsError(try tree.findSymbol(path: "myMethodSwiftName()", parent: moduleID))
        
        // typedef NS_OPTIONS(NSInteger, MyObjectiveCOption) {
        //     MyObjectiveCOptionNone                                      = 0,
        //     MyObjectiveCOptionFirst                                     = 1 << 0,
        //     MyObjectiveCOptionSecond NS_SWIFT_NAME(secondCaseSwiftName) = 1 << 1
        // };
        let myOptionAsEnumID = try tree.find(path: "MyObjectiveCOption-enum", parent: moduleID, onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "MyObjectiveCOptionNone", parent: myOptionAsEnumID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionNone")
        XCTAssertEqual(try tree.findSymbol(path: "MyObjectiveCOptionFirst", parent: myOptionAsEnumID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        XCTAssertEqual(try tree.findSymbol(path: "MyObjectiveCOptionSecond", parent: myOptionAsEnumID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        // These names don't exist in either language representation
        XCTAssertThrowsError(try tree.findSymbol(path: "none", parent: myOptionAsEnumID))
        XCTAssertThrowsError(try tree.findSymbol(path: "second", parent: myOptionAsEnumID))
        // Relative links can start with either language representation. This enabled documentation extension files to use relative links.
        XCTAssertEqual(try tree.findSymbol(path: "first", parent: myOptionAsEnumID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        XCTAssertEqual(try tree.findSymbol(path: "secondCaseSwiftName", parent: myOptionAsEnumID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        // Links can't mix languages
        XCTAssertThrowsError(try tree.findSymbol(path: "MyObjectiveCOption-enum/first", parent: myOptionAsEnumID))
        XCTAssertThrowsError(try tree.findSymbol(path: "MyObjectiveCOption-enum/secondCaseSwiftName", parent: myOptionAsEnumID))
        
        let myOptionAsStructID = try tree.find(path: "MyObjectiveCOption-struct", parent: moduleID, onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "first", parent: myOptionAsStructID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        XCTAssertEqual(try tree.findSymbol(path: "secondCaseSwiftName", parent: myOptionAsStructID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        // These names don't exist in either language representation
        XCTAssertThrowsError(try tree.findSymbol(path: "none", parent: myOptionAsStructID))
        XCTAssertThrowsError(try tree.findSymbol(path: "second", parent: myOptionAsStructID))
        // Relative links can start with either language representation. This enabled documentation extension files to use relative links.
        XCTAssertEqual(try tree.findSymbol(path: "MyObjectiveCOptionNone", parent: myOptionAsStructID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionNone")
        XCTAssertEqual(try tree.findSymbol(path: "MyObjectiveCOptionFirst", parent: myOptionAsStructID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionFirst")
        XCTAssertEqual(try tree.findSymbol(path: "MyObjectiveCOptionSecond", parent: myOptionAsStructID).identifier.precise, "c:@E@MyObjectiveCOption@MyObjectiveCOptionSecond")
        // Links can't mix languages
        XCTAssertThrowsError(try tree.findSymbol(path: "MyObjectiveCOption-struct/MyObjectiveCOptionNone", parent: moduleID))
        XCTAssertThrowsError(try tree.findSymbol(path: "MyObjectiveCOption-struct/MyObjectiveCOptionFirst", parent: moduleID))
        XCTAssertThrowsError(try tree.findSymbol(path: "MyObjectiveCOption-struct/MyObjectiveCOptionSecond", parent: moduleID))
        
        // typedef NSInteger MyTypedObjectiveCExtensibleEnum NS_TYPED_EXTENSIBLE_ENUM;
        //
        // MyTypedObjectiveCExtensibleEnum const MyTypedObjectiveCExtensibleEnumFirst;
        // MyTypedObjectiveCExtensibleEnum const MyTypedObjectiveCExtensibleEnumSecond;
        let myTypedExtensibleEnumID = try tree.find(path: "MyTypedObjectiveCExtensibleEnum-struct", parent: moduleID, onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "first", parent: myTypedExtensibleEnumID).identifier.precise, "c:@MyTypedObjectiveCExtensibleEnumFirst")
        XCTAssertEqual(try tree.findSymbol(path: "second", parent: myTypedExtensibleEnumID).identifier.precise, "c:@MyTypedObjectiveCExtensibleEnumSecond")
    }
    
    func testPathWithDocumentationPrefix() throws {
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFrameworkWithLanguageRefinements")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let moduleID = try tree.find(path: "/MixedFramework", onlyFindSymbols: true)
        
        XCTAssertEqual(try tree.findSymbol(path: "MyEnum", parent: moduleID).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        XCTAssertEqual(try tree.findSymbol(path: "MixedFramework/MyEnum", parent: moduleID).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        XCTAssertEqual(try tree.findSymbol(path: "documentation/MixedFramework/MyEnum", parent: moduleID).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        XCTAssertEqual(try tree.findSymbol(path: "/documentation/MixedFramework/MyEnum", parent: moduleID).identifier.precise, "c:@M@MixedFramework@E@MyEnum")
        
        assertParsedPathComponents("documentation/MixedFramework/MyEnum", [("documentation", nil), ("MixedFramework", nil), ("MyEnum", nil)])
        assertParsedPathComponents("/documentation/MixedFramework/MyEnum", [("documentation", nil), ("MixedFramework", nil), ("MyEnum", nil)])
    }
    
    func testTestBundle() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let linkResolver = try XCTUnwrap(context.linkResolver.localResolver)
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
        try assertFindsPath("/SideKit/SideClass/Element/inherited()", in: tree, asSymbolID: "s:7SideKit0A5::SYNTHESIZED::inheritedFF")
        
        // Test disfavoring a default implementation in a symbol collision
        try assertFindsPath("/SideKit/SideProtocol/func()", in: tree, asSymbolID: "s:5MyKit0A5MyProtocol0Afunc()")
        try assertFindsPath("/SideKit/SideProtocol/func()-method", in: tree, asSymbolID: "s:5MyKit0A5MyProtocol0Afunc()")
        try assertFindsPath("/SideKit/SideProtocol/func()-6ijsi", in: tree, asSymbolID: "s:5MyKit0A5MyProtocol0Afunc()")
        // Only with disambiguation does the link resolve to the default implementation symbol
        try assertFindsPath("/SideKit/SideProtocol/func()-2dxqn", in: tree, asSymbolID: "s:5MyKit0A5MyProtocol0Afunc()DefaultImp")
        
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
        
        let modulePageTaskGroupID = try tree.find(path: "/MyKit#Extensions-to-other-frameworks", onlyFindSymbols: false)
        XCTAssertNil(tree.lookup[modulePageTaskGroupID]!.symbol)
        XCTAssertEqual(tree.lookup[modulePageTaskGroupID]!.name, "Extensions-to-other-frameworks")
        
        let symbolPageTaskGroupID = try tree.find(path: "/MyKit/MyProtocol#Task-Group-Exercising-Symbol-Links", onlyFindSymbols: false)
        XCTAssertNil(tree.lookup[symbolPageTaskGroupID]!.symbol)
        XCTAssertEqual(tree.lookup[symbolPageTaskGroupID]!.name, "Task-Group-Exercising-Symbol-Links")
    }
    
    func testMixedLanguageFramework() throws {
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFramework")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        try assertFindsPath("MixedLanguageFramework/Bar/myStringFunction(_:)", in: tree, asSymbolID: "c:objc(cs)Bar(cm)myStringFunction:error:")
        try assertFindsPath("MixedLanguageFramework/Bar/myStringFunction:error:", in: tree, asSymbolID: "c:objc(cs)Bar(cm)myStringFunction:error:")

        try assertPathCollision("MixedLanguageFramework/Foo", in: tree, collisions: [
            ("c:@E@Foo", "enum"),
            ("c:@E@Foo", "struct"),
            ("c:MixedLanguageFramework.h@T@Foo", "typealias"),
        ])
        try assertPathRaisesErrorMessage("MixedLanguageFramework/Foo", in: tree, context: context, expectedErrorMessage: """
        'Foo' is ambiguous at '/MixedLanguageFramework'
        """) { error in
            XCTAssertEqual(error.solutions, [
                .init(summary: "Insert 'struct' for \n'struct Foo'", replacements: [("-struct", 26, 26)]),
                .init(summary: "Insert 'enum' for \n'typedef enum Foo : NSString { ... } Foo;'", replacements: [("-enum", 26, 26)]),
                .init(summary: "Insert 'typealias' for \n'typedef enum Foo : NSString { ... } Foo;'", replacements: [("-typealias", 26, 26)]),
            ])
        } // The 'enum' and 'typealias' symbols have multi-line declarations that are presented on a single line
        
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
    
    func testArticleAndSymbolCollisions() throws {
        let (_, _, context) = try testBundleAndContext(copying: "MixedLanguageFramework") { url in
            try """
            # An article
            
            This article has the same path as a symbol
            """.write(to: url.appendingPathComponent("Bar.md"), atomically: true, encoding: .utf8)
        }
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        // The added article above has the same path as an existing symbol in the this module.
        let symbolNode = try tree.findNode(path: "/MixedLanguageFramework/Bar", onlyFindSymbols: true)
        XCTAssertNotNil(symbolNode.symbol, "Symbol link finds the symbol")
        let articleNode = try tree.findNode(path: "/MixedLanguageFramework/Bar", onlyFindSymbols: false)
        XCTAssertNil(articleNode.symbol, "General documentation link find the article")
    }
    
    func testArticleSelfAnchorLinks() throws {
        let (_, _, context) = try testBundleAndContext(copying: "MixedLanguageFramework") { url in
            try """
            # ArticleWithHeading

            ## TestTargetHeading

            This article has the same path as a symbol. See also:
            - <doc:TestTargetHeading>
            - <doc:#TestTargetHeading>

            """.write(to: url.appendingPathComponent("ArticleWithHeading.md"), atomically: true, encoding: .utf8)
        }

        let tree = context.linkResolver.localResolver.pathHierarchy
        let articleNode = try tree.findNode(path: "/MixedLanguageFramework/ArticleWithHeading", onlyFindSymbols: false)

        let linkNode = try tree.find(path: "TestTargetHeading", parent: articleNode.identifier, onlyFindSymbols: false)
        let anchorLinkNode = try tree.find(path: "#TestTargetHeading", parent: articleNode.identifier, onlyFindSymbols: false)
        XCTAssertNotNil(linkNode)
        XCTAssertNotNil(anchorLinkNode)
    }

    func testOverloadedSymbols() throws {
        let (_, context) = try testBundleAndContext(named: "OverloadedSymbols")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
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
        
        // These methods have different parameter types and use that for disambiguation.
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSiF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-(Int)")
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSfF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-(Float)")
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSSF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-(String)")
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameyS2dF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-(Double)")
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSaySdGF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-([Double])")
        
        let hashAndKindDisambiguatedPaths = tree.caseInsensitiveDisambiguatedPaths(allowAdvancedDisambiguation: false)
        
        XCTAssertEqual(hashAndKindDisambiguatedPaths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSiF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-14g8s")
        XCTAssertEqual(hashAndKindDisambiguatedPaths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSfF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-14ife")
        XCTAssertEqual(hashAndKindDisambiguatedPaths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSSF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-14ob0")
    }

    func testOverloadedSymbolsWithOverloadGroups() throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let (_, context) = try testBundleAndContext(named: "OverloadedSymbols")
        let tree = context.linkResolver.localResolver.pathHierarchy

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
        // These 4 methods have different parameter types and use that for disambiguation.
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSiF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-(Int)")
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSfF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-(Float)")
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSSF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-(String)")
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSaySdGF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-([Double])")
        
        // The overload group is cloned from this symbol and therefore have the same function signature.
        // Because there are two collisions with the same signature, this method can only be uniquely disambiguated with its hash.
        XCTAssertEqual(paths["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameyS2dF"],
                       "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-4ja8m")
    }
    
    func testApplyingSyntaxSugarToTypeName() {
        func functionSignatureParameterTypeName(_ fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment]) -> String? {
            return PathHierarchy.functionSignatureTypeNames(for: SymbolGraph.Symbol(
                identifier: SymbolGraph.Symbol.Identifier(precise: "some-symbol-id", interfaceLanguage: SourceLanguage.swift.id),
                names: .init(title: "SymbolName", navigator: nil, subHeading: nil, prose: nil),
                pathComponents: ["SymbolName"], docComment: nil, accessLevel: .public, kind: .init(parsedIdentifier: .class, displayName: "Kind Display NAme"), mixins: [
                    SymbolGraph.Symbol.FunctionSignature.mixinKey: SymbolGraph.Symbol.FunctionSignature(
                        parameters: [
                            .init(name: "someName", externalName: "with", declarationFragments: [
                                .init(kind: .identifier, spelling: "someName", preciseIdentifier: nil),
                                .init(kind: .text, spelling: ": ", preciseIdentifier: nil),
                            ] + fragments, children: [])
                        ],
                        returns: []
                    )
                ])
            )?.parameterTypeNames.first
        }
        
        // Int
        XCTAssertEqual("Int", functionSignatureParameterTypeName([
            .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
        ]))
        
        // Array<Int>
        XCTAssertEqual("[Int]", functionSignatureParameterTypeName([
            .init(kind: .typeIdentifier, spelling: "Array", preciseIdentifier: "s:Sa"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
            .init(kind: .text, spelling: ">", preciseIdentifier: nil),
        ]))
        
        // Array<(Int,Double)>
        XCTAssertEqual("[(Int,Double)]", functionSignatureParameterTypeName([
            .init(kind: .typeIdentifier, spelling: "Array", preciseIdentifier: "s:Sa"),
            .init(kind: .text, spelling: "<(", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
            .init(kind: .text, spelling: ",", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Double", preciseIdentifier: "s:Sd"),
            .init(kind: .text, spelling: ")>", preciseIdentifier: nil),
        ]))
        
        // Optional<Int>
        XCTAssertEqual("Int?", functionSignatureParameterTypeName([
            .init(kind: .typeIdentifier, spelling: "Optional", preciseIdentifier: "s:Sq"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
            .init(kind: .text, spelling: ">", preciseIdentifier: nil),
        ]))
        
        // Optional<(Int,Double)>
        XCTAssertEqual("(Int,Double)?", functionSignatureParameterTypeName([
            .init(kind: .typeIdentifier, spelling: "Optional", preciseIdentifier: "s:Sq"),
            .init(kind: .text, spelling: "<(", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
            .init(kind: .text, spelling: ",", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Double", preciseIdentifier: "s:Sd"),
            .init(kind: .text, spelling: ")>", preciseIdentifier: nil),
        ]))
        
        // Array<(Array<Int>,Optional<Optional<Double>>)>
        XCTAssertEqual("[([Int],Double??)]", functionSignatureParameterTypeName([
            .init(kind: .typeIdentifier, spelling: "Array", preciseIdentifier: "s:Sa"),
            .init(kind: .text, spelling: "<(", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Array", preciseIdentifier: "s:Sa"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
            .init(kind: .text, spelling: ">,", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Optional", preciseIdentifier: "s:Sq"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Optional", preciseIdentifier: "s:Sq"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Double", preciseIdentifier: "s:Sd"),
            .init(kind: .text, spelling: ">>)>", preciseIdentifier: nil),
        ]))
        
        // Dictionary<Key,Value>
        XCTAssertEqual("[Double:Int]", functionSignatureParameterTypeName([
            .init(kind: .typeIdentifier, spelling: "Dictionary", preciseIdentifier: "s:SD"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Double", preciseIdentifier: "s:Sd"),
            .init(kind: .text, spelling: ",", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
            .init(kind: .text, spelling: ">", preciseIdentifier: nil),
        ]))
        
        // Dictionary<(Optional<Int>,String),Array<Optional<String>>>
        XCTAssertEqual("[(Int?,String):[Double?]]", functionSignatureParameterTypeName([
            .init(kind: .typeIdentifier, spelling: "Dictionary", preciseIdentifier: "s:SD"),
            .init(kind: .text, spelling: "<(", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Optional", preciseIdentifier: "s:Sq"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
            .init(kind: .text, spelling: ">,", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "String", preciseIdentifier: "s:SS"),
            .init(kind: .text, spelling: "),", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Array", preciseIdentifier: "s:Sa"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Optional", preciseIdentifier: "s:Sq"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Double", preciseIdentifier: "s:Sd"),
            .init(kind: .text, spelling: ">>>", preciseIdentifier: nil),
        ]))
        
        // Dictionary<Optional<Dictionary<Int,Dictionary<String,Double>>>,Array<Dictionary<Int,Dictionary<String,Double>>>>
        XCTAssertEqual("[[Int:[String:Double]]?:[[Int:[String:Double]]]]", functionSignatureParameterTypeName([
            .init(kind: .typeIdentifier, spelling: "Dictionary", preciseIdentifier: "s:SD"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Optional", preciseIdentifier: "s:Sq"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Dictionary", preciseIdentifier: "s:SD"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
            .init(kind: .text, spelling: ",", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Dictionary", preciseIdentifier: "s:SD"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "String", preciseIdentifier: "s:SS"),
            .init(kind: .text, spelling: ",", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Double", preciseIdentifier: "s:Sd"),
            .init(kind: .text, spelling: ">>>,", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Array", preciseIdentifier: "s:Sa"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Dictionary", preciseIdentifier: "s:SD"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
            .init(kind: .text, spelling: ",", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Dictionary", preciseIdentifier: "s:SD"),
            .init(kind: .text, spelling: "<", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "String", preciseIdentifier: "s:SS"),
            .init(kind: .text, spelling: ",", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "Double", preciseIdentifier: "s:Sd"),
            .init(kind: .text, spelling: ">>>>", preciseIdentifier: nil),
        ]))
    }
    
    func testTypeNamesFromSymbolSignature() throws {
        func functionSignatureTypeNames(_ signature: SymbolGraph.Symbol.FunctionSignature) -> (parameterTypeNames: [String], returnTypeNames: [String])? {
            return PathHierarchy.functionSignatureTypeNames(for: SymbolGraph.Symbol(
                identifier: SymbolGraph.Symbol.Identifier(precise: "some-symbol-id", interfaceLanguage: SourceLanguage.swift.id),
                names: .init(title: "SymbolName", navigator: nil, subHeading: nil, prose: nil),
                pathComponents: ["SymbolName"], docComment: nil, accessLevel: .public, kind: .init(parsedIdentifier: .class, displayName: "Kind Display NAme"), mixins: [
                    SymbolGraph.Symbol.FunctionSignature.mixinKey: signature
                ])
            )
        }
        
        // Objective-C types
        do {
            // - (id)doSomething:(NSString *)someName;
            let stringArgument = functionSignatureTypeNames(.init(
                parameters: [
                    .init(name: "someName", externalName: nil, declarationFragments: [
                        .init(kind: .text, spelling: "(", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "NSString", preciseIdentifier: "c:objc(cs)NSString"),
                        .init(kind: .text, spelling: " * )", preciseIdentifier: nil),
                        .init(kind: .internalParameter, spelling: "someName", preciseIdentifier: nil),
                    ], children: [])
                ],
                returns: [
                    .init(kind: .typeIdentifier, spelling: "id", preciseIdentifier: "c:*Qo"),
                ])
            )
            XCTAssertEqual(stringArgument?.parameterTypeNames, ["NSString*"])
            XCTAssertEqual(stringArgument?.returnTypeNames, ["id"])
            
            // - (void)doSomething:(NSArray<NSString *> *)someName;
            let genericArrayArgument = functionSignatureTypeNames(.init(
                parameters: [
                    .init(name: "someName", externalName: nil, declarationFragments: [
                        .init(kind: .text, spelling: "(", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "NSArray<NSString *>", preciseIdentifier: "c:Q$objc(cs)NSArray"),
                        .init(kind: .text, spelling: " * )", preciseIdentifier: nil),
                        .init(kind: .internalParameter, spelling: "someName", preciseIdentifier: nil),
                    ], children: [])
                ],
                returns: [
                    .init(kind: .typeIdentifier, spelling: "void", preciseIdentifier: "c:v"),
                ])
            )
            XCTAssertEqual(genericArrayArgument?.parameterTypeNames, ["NSArray<NSString*>*"])
            XCTAssertEqual(genericArrayArgument?.returnTypeNames, [])
            
            // // - (void)doSomething:(id<MyProtocol>)someName;
            let protocolArgument = functionSignatureTypeNames(.init(
                parameters: [
                    .init(name: "someName", externalName: nil, declarationFragments: [
                        .init(kind: .text, spelling: "(", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "id<MyProtocol>", preciseIdentifier: "c:Qoobjc(pl)MyProtocol"),
                        .init(kind: .text, spelling: ")", preciseIdentifier: nil),
                        .init(kind: .internalParameter, spelling: "someName", preciseIdentifier: nil),
                    ], children: [])
                ],
                returns: [])
            )
            XCTAssertEqual(protocolArgument?.parameterTypeNames, ["id<MyProtocol>"])
            
            // - (void)doSomething:(NSError **)someName;
            let errorArgument = functionSignatureTypeNames(.init(
                parameters: [
                    .init(name: "someName", externalName: nil, declarationFragments: [
                        .init(kind: .text, spelling: "(", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "NSError", preciseIdentifier: "c:objc(cs)NSError"),
                        .init(kind: .text, spelling: " * *)", preciseIdentifier: nil),
                        .init(kind: .internalParameter, spelling: "someName", preciseIdentifier: nil),
                    ], children: [])
                ],
                returns: [])
            )
            XCTAssertEqual(errorArgument?.parameterTypeNames, ["NSError**"])
            
            // - (void)doSomething:(NSString * (^)(CGFloat, NSInteger))blockName;
            let blockArgument = functionSignatureTypeNames(.init(
                parameters: [
                    .init(name: "blockName", externalName: nil, declarationFragments: [
                        .init(kind: .text, spelling: "(", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "NSString", preciseIdentifier: "c:objc(cs)NSString"),
                        .init(kind: .text, spelling: " * (^", preciseIdentifier: nil),
                        .init(kind: .text, spelling: ")(", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "CGFloat", preciseIdentifier: "c:@T@CGFloat"),
                        .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                        .init(kind: .internalParameter, spelling: "", preciseIdentifier: nil),
                        .init(kind: .text, spelling: ", ", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "NSInteger", preciseIdentifier: "c:@T@NSInteger"),
                        .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                        .init(kind: .internalParameter, spelling: "", preciseIdentifier: nil),
                        .init(kind: .text, spelling: "))", preciseIdentifier: nil),
                        .init(kind: .internalParameter, spelling: "blockName", preciseIdentifier: nil),
                    ], children: [])
                ],
                returns: [])
            )
            XCTAssertEqual(blockArgument?.parameterTypeNames, ["NSString*(^)(CGFloat,NSInteger)"])
        }
        
        // Swift types
        do {
            // func doSomething(someName: ((Int, String), Date)) -> ([Int, String?])
            let tupleArgument = functionSignatureTypeNames(.init(
                parameters: [
                    .init(name: "someName", externalName: nil, declarationFragments: [
                        .init(kind: .identifier, spelling: "someName", preciseIdentifier: nil),
                        .init(kind: .text, spelling: ": ((", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
                        .init(kind: .text, spelling: ", ", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "String", preciseIdentifier: "s:SS"),
                        .init(kind: .text, spelling: "), ", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Date", preciseIdentifier: "s:10Foundation4DateV"),
                        .init(kind: .text, spelling: ")", preciseIdentifier: nil),
                    ], children: [])
                ],
                returns: [
                    .init(kind: .text, spelling: "([", preciseIdentifier: nil),
                    .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
                    .init(kind: .text, spelling: "], ", preciseIdentifier: nil),
                    .init(kind: .typeIdentifier, spelling: "String", preciseIdentifier: "s:SS"),
                    .init(kind: .text, spelling: "?)", preciseIdentifier: nil),
                ])
            )
            XCTAssertEqual(tupleArgument?.parameterTypeNames, ["((Int,String),Date)"])
            XCTAssertEqual(tupleArgument?.returnTypeNames, ["([Int],String?)"])
            
            // func doSomething(with someName: [Int?: String??])
            let dictionaryWithOptionalsArgument = functionSignatureTypeNames(.init(
                parameters: [
                    .init(name: "someName", externalName: "with", declarationFragments: [
                        .init(kind: .identifier, spelling: "someName", preciseIdentifier: nil),
                        .init(kind: .text, spelling: ": [", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
                        .init(kind: .text, spelling: "? : ", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "String", preciseIdentifier: "s:SS"),
                        .init(kind: .text, spelling: "??]", preciseIdentifier: nil),
                    ], children: [])
                ],
                returns: [
                    .init(kind: .typeIdentifier, spelling: "Void", preciseIdentifier: "s:s4Voida"),
                ])
            )
            XCTAssertEqual(dictionaryWithOptionalsArgument?.parameterTypeNames, ["[Int?:String??]"])
            XCTAssertEqual(dictionaryWithOptionalsArgument?.returnTypeNames, [])
            
            // func doSomething(with someName: Dictionary<Optional<Int>, Optional<(Optional<String>, Array<Double>)>>)
            let unsugaredDictionaryWithOptionalsArgument = functionSignatureTypeNames(.init(
                parameters: [
                    .init(name: "someName", externalName: "with", declarationFragments: [
                        .init(kind: .identifier, spelling: "someName", preciseIdentifier: nil),
                        .init(kind: .text, spelling: ": ", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Dictionary", preciseIdentifier: "s:SD"),
                        .init(kind: .text, spelling: "<", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Optional", preciseIdentifier: "s:Sq"),
                        .init(kind: .text, spelling: "<", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
                        .init(kind: .text, spelling: ">, ", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Optional", preciseIdentifier: "s:Sq"),
                        .init(kind: .text, spelling: "<(", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Optional", preciseIdentifier: "s:Sq"),
                        .init(kind: .text, spelling: "<", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "String", preciseIdentifier: "s:SS"),
                        .init(kind: .text, spelling: ">, ", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Array", preciseIdentifier: "s:Sa"),
                        .init(kind: .text, spelling: "<", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Double", preciseIdentifier: "s:Sd"),
                        .init(kind: .text, spelling: ">)>>", preciseIdentifier: nil),
                    ], children: [])
                ],
                returns: [])
            )
            XCTAssertEqual(unsugaredDictionaryWithOptionalsArgument?.parameterTypeNames, ["[Int?:(String?,[Double])?]"])
            
            // doSomething<each Value>(someName: repeat each Value) {}
            let parameterPackArgument = functionSignatureTypeNames(.init(
                parameters: [
                    .init(name: "someName", externalName: nil, declarationFragments: [
                        .init(kind: .identifier, spelling: "someName", preciseIdentifier: nil),
                        .init(kind: .text, spelling: ": ", preciseIdentifier: nil),
                        .init(kind: .keyword, spelling: "repeat", preciseIdentifier: "s:SD"),
                        .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                        .init(kind: .keyword, spelling: "each", preciseIdentifier: "s:Sq"),
                        .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Value", preciseIdentifier: "s:24ComplicatedArgumentTypes11doSomething8someNameyxxQp_tRvzlF5ValueL_xmfp"),
                    ], children: [])
                ],
                returns: [])
            )
            XCTAssertEqual(parameterPackArgument?.parameterTypeNames, ["Value"])
            
            // func doSomething<Value>(someName: @escaping ((inout Int?, consuming Double, (String, Value)) -> ((Int) -> Value?)))
            let complicatedClosureArgument = functionSignatureTypeNames(.init(
                parameters: [
                    .init(name: "someName", externalName: nil, declarationFragments: [
                        .init(kind: .identifier, spelling: "someName", preciseIdentifier: nil),
                        .init(kind: .text, spelling: ": ", preciseIdentifier: nil),
                        .init(kind: .attribute, spelling: "@escaping", preciseIdentifier: nil),
                        .init(kind: .text, spelling: " ((", preciseIdentifier: nil),
                        .init(kind: .keyword, spelling: "inout", preciseIdentifier: nil),
                        .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
                        .init(kind: .text, spelling: "?, ", preciseIdentifier: nil),
                        .init(kind: .keyword, spelling: "consuming", preciseIdentifier: nil),
                        .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Double", preciseIdentifier: "s:Sd"),
                        .init(kind: .text, spelling: ", (", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "String", preciseIdentifier: "s:SS"),
                        .init(kind: .text, spelling: ", ", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Value", preciseIdentifier: "s:24ComplicatedArgumentTypes11doSomething8someNameyxSgSicSiSgz_SdnSS_xttcSg_tlF5ValueL_xmfp"),
                        .init(kind: .text, spelling: ")) -> ((", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
                        .init(kind: .text, spelling: ") -> ", preciseIdentifier: nil),
                        .init(kind: .typeIdentifier, spelling: "Value", preciseIdentifier: "s:24ComplicatedArgumentTypes11doSomething8someNameyxSgSicSiSgz_SdnSS_xttcSg_tlF5ValueL_xmfp"),
                        .init(kind: .text, spelling: "))", preciseIdentifier: nil),
                    ], children: [])
                ],
                returns: [])
            )
            XCTAssertEqual(complicatedClosureArgument?.parameterTypeNames, ["(Int?,Double,(String,Value))->((Int)->Value)"])
            
            
        }
    }
    
    func testOverloadGroupSymbolsResolveLinksWithoutHash() throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let (_, context) = try testBundleAndContext(named: "OverloadedSymbols")
        let tree = context.linkResolver.localResolver.pathHierarchy

        // The enum case should continue to resolve by kind, since it has no hash collision
        XCTAssertNoThrow(try tree.findNode(path: "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-enum.case", onlyFindSymbols: true))

        // The overloaded enum method should now be able to resolve by kind, which will point to the overload group
        let overloadedEnumMethod = try tree.findNode(path: "/ShapeKit/OverloadedEnum/firstTestMemberName(_:)-method", onlyFindSymbols: true)
        XCTAssert(overloadedEnumMethod.symbol?.identifier.precise.hasSuffix(SymbolGraph.Symbol.overloadGroupIdentifierSuffix) == true)

        // This overloaded protocol method should be able to resolve without a suffix at all, since it doesn't conflict with anything
        let overloadedProtocolMethod = try tree.findNode(path: "/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)", onlyFindSymbols: true)
        XCTAssert(overloadedProtocolMethod.symbol?.identifier.precise.hasSuffix(SymbolGraph.Symbol.overloadGroupIdentifierSuffix) == true)
    }

    func testSymbolsWithSameNameAsModule() throws {
        let (_, context) = try testBundleAndContext(named: "SymbolsWithSameNameAsModule")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        // /* in a module named "Something "*/
        // public struct Something {
        //     public enum Something {
        //         case first
        //     }
        //     public var second = 0
        // }
        // public struct Wrapper {
        //     public struct Something {
        //         public var third = 0
        //     }
        // }
        try assertFindsPath("Something", in: tree, asSymbolID: "Something")
        try assertFindsPath("/Something", in: tree, asSymbolID: "Something")
        
        let moduleID = try tree.find(path: "/Something", onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "/Something", parent: moduleID).identifier.precise, "Something")
        XCTAssertEqual(try tree.findSymbol(path: "Something-module", parent: moduleID).identifier.precise, "Something")
        XCTAssertEqual(try tree.findSymbol(path: "Something", parent: moduleID).identifier.precise, "s:9SomethingAAV")
        XCTAssertEqual(try tree.findSymbol(path: "/Something/Something", parent: moduleID).identifier.precise, "s:9SomethingAAV")
        XCTAssertEqual(try tree.findSymbol(path: "Something/Something", parent: moduleID).identifier.precise, "s:9SomethingAAVAAO")
        XCTAssertEqual(try tree.findSymbol(path: "Something/Something/Something", parent: moduleID).identifier.precise, "s:9SomethingAAVAAO")
        XCTAssertEqual(try tree.findSymbol(path: "/Something/Something/Something", parent: moduleID).identifier.precise, "s:9SomethingAAVAAO")
        XCTAssertEqual(try tree.findSymbol(path: "/Something/Something", parent: moduleID).identifier.precise, "s:9SomethingAAV")
        XCTAssertEqual(try tree.findSymbol(path: "Something/second", parent: moduleID).identifier.precise, "s:9SomethingAAV6secondSivp")
        
        let topLevelSymbolID = try tree.find(path: "/Something/Something", onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "Something", parent: topLevelSymbolID).identifier.precise, "s:9SomethingAAVAAO")
        XCTAssertEqual(try tree.findSymbol(path: "Something/Something", parent: topLevelSymbolID).identifier.precise, "s:9SomethingAAVAAO")
        XCTAssertEqual(try tree.findSymbol(path: "Something/second", parent: topLevelSymbolID).identifier.precise, "s:9SomethingAAV6secondSivp")
        
        let wrapperID = try tree.find(path: "/Something/Wrapper", onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "Something/second", parent: wrapperID).identifier.precise, "s:9SomethingAAV6secondSivp")
        XCTAssertEqual(try tree.findSymbol(path: "Something/third", parent: wrapperID).identifier.precise, "s:9Something7WrapperVAAV5thirdSivp")
        
        let wrappedID = try tree.find(path: "/Something/Wrapper/Something", onlyFindSymbols: true)
        XCTAssertEqual(try tree.findSymbol(path: "Something/second", parent: wrappedID).identifier.precise, "s:9SomethingAAV6secondSivp")
        XCTAssertEqual(try tree.findSymbol(path: "Something/third", parent: wrappedID).identifier.precise, "s:9Something7WrapperVAAV5thirdSivp")
        
        XCTAssertEqual(try tree.findSymbol(path: "Something/first", parent: topLevelSymbolID).identifier.precise, "s:9SomethingAAVAAO5firstyA2CmF")
        XCTAssertEqual(try tree.findSymbol(path: "Something/second", parent: topLevelSymbolID).identifier.precise, "s:9SomethingAAV6secondSivp")
    }
    
    func testSymbolsWithSameNameAsExtendedModule() throws {
        // ---- Inner
        // public struct InnerStruct {}
        // public class InnerClass {}
        //
        // ---- Outer
        // // Shadow the Inner module with a local type
        // public struct Inner {}
        //
        // public extension InnerStruct {
        //     func something() {}
        // }
        // public extension InnerClass {
        //     func something() {}
        // }
        let (_, context) = try testBundleAndContext(named: "ShadowExtendedModuleWithLocalSymbol")
        let tree = context.linkResolver.localResolver.pathHierarchy

        try assertPathCollision("Outer/Inner", in: tree, collisions: [
            ("s:m:s:e:s:5Inner0A5ClassC5OuterE9somethingyyF", "module.extension"),
            ("s:5Outer5InnerV", "struct"),
        ])
        // If the first path component is ambiguous, it should have the same error as if that was a later path component.
        try assertPathCollision("Inner", in: tree, collisions: [
            ("s:m:s:e:s:5Inner0A5ClassC5OuterE9somethingyyF", "module.extension"),
            ("s:5Outer5InnerV", "struct"),
        ])
        
        try assertFindsPath("Inner-struct", in: tree, asSymbolID: "s:5Outer5InnerV")
        try assertFindsPath("Inner-module.extension", in: tree, asSymbolID: "s:m:s:e:s:5Inner0A5ClassC5OuterE9somethingyyF")
        
        try assertFindsPath("Inner-module.extension/InnerStruct", in: tree, asSymbolID: "s:e:s:5Inner0A6StructV5OuterE9somethingyyF")
        try assertFindsPath("Inner-module.extension/InnerClass", in: tree, asSymbolID: "s:e:s:5Inner0A5ClassC5OuterE9somethingyyF")
        try assertFindsPath("Inner-module.extension/InnerStruct/something()", in: tree, asSymbolID: "s:5Inner0A6StructV5OuterE9somethingyyF")
        try assertFindsPath("Inner-module.extension/InnerClass/something()", in: tree, asSymbolID: "s:5Inner0A5ClassC5OuterE9somethingyyF")
        
        // The "Inner" struct doesn't have "InnerStruct" or "InnerClass" descendants so the path is not ambiguous.
        try assertFindsPath("Inner/InnerStruct", in: tree, asSymbolID: "s:e:s:5Inner0A6StructV5OuterE9somethingyyF")
        try assertFindsPath("Inner/InnerClass", in: tree, asSymbolID: "s:e:s:5Inner0A5ClassC5OuterE9somethingyyF")
        try assertFindsPath("Inner/InnerStruct/something()", in: tree, asSymbolID: "s:5Inner0A6StructV5OuterE9somethingyyF")
        try assertFindsPath("Inner/InnerClass/something()", in: tree, asSymbolID: "s:5Inner0A5ClassC5OuterE9somethingyyF")
    }
    
    func testSnippets() throws {
        let (_, context) = try testBundleAndContext(named: "Snippets")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
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
        let (_, context) = try testBundleAndContext(named: "InheritedOperators")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        // public struct MyNumber: SignedNumeric, Comparable, Equatable, Hashable {
        //    public static func / (lhs: MyNumber, rhs: MyNumber) -> MyNumber { ... }
        //    public static func /= (lhs: inout MyNumber, rhs: MyNumber) -> MyNumber { ... }
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
        
        XCTAssertEqual(try tree.findSymbol(path: "/(_:_:)", parent: myNumberID).identifier.precise, "s:9Operators8MyNumberV1doiyA2C_ACtFZ")
        XCTAssertEqual(try tree.findSymbol(path: "/=(_:_:)", parent: myNumberID).identifier.precise, "s:9Operators8MyNumberV2deoiyA2Cz_ACtFZ")
        
        XCTAssertEqual(try tree.findSymbol(path: "...(_:)->PartialRangeFrom<Self>", parent: myNumberID).identifier.precise, "s:SLsE3zzzoPys16PartialRangeFromVyxGxFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "...(_:)-28faz", parent: myNumberID).identifier.precise, "s:SLsE3zzzoPys16PartialRangeFromVyxGxFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "...(_:)->PartialRangeThrough<Self>", parent: myNumberID).identifier.precise, "s:SLsE3zzzopys19PartialRangeThroughVyxGxFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "...(_:)-8ooeh", parent: myNumberID).identifier.precise, "s:SLsE3zzzopys19PartialRangeThroughVyxGxFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        
        XCTAssertEqual(try tree.findSymbol(path: "...(_:_:)", parent: myNumberID).identifier.precise, "s:SLsE3zzzoiySNyxGx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "..<(_:)", parent: myNumberID).identifier.precise, "s:SLsE3zzlopys16PartialRangeUpToVyxGxFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "..<(_:_:)", parent: myNumberID).identifier.precise, "s:SLsE3zzloiySnyxGx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        
        XCTAssertEqual(try tree.findSymbol(path: "<(_:_:)", parent: myNumberID).identifier.precise, "s:9Operators8MyNumberV1loiySbAC_ACtFZ")
        XCTAssertEqual(try tree.findSymbol(path: ">(_:_:)", parent: myNumberID).identifier.precise, "s:SLsE1goiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "<=(_:_:)", parent: myNumberID).identifier.precise, "s:SLsE2leoiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: ">=(_:_:)", parent: myNumberID).identifier.precise, "s:SLsE2geoiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        
        XCTAssertEqual(try tree.findSymbol(path: "-(_:_:)-22pw2", parent: myNumberID).identifier.precise, "s:9Operators8MyNumberV1soiyA2C_ACtFZ")
        XCTAssertEqual(try tree.findSymbol(path: "-(_:)-9xdx0", parent: myNumberID).identifier.precise, "s:s13SignedNumericPsE1sopyxxFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "-=(_:_:)-7w3vn", parent: myNumberID).identifier.precise, "s:s18AdditiveArithmeticPsE2seoiyyxz_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        
        XCTAssertEqual(try tree.findSymbol(path: "-(_:_:)-func.op", parent: myNumberID).identifier.precise, "s:9Operators8MyNumberV1soiyA2C_ACtFZ")
        XCTAssertEqual(try tree.findSymbol(path: "-(_:)-func.op", parent: myNumberID).identifier.precise, "s:s13SignedNumericPsE1sopyxxFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        XCTAssertEqual(try tree.findSymbol(path: "-=(_:_:)-func.op", parent: myNumberID).identifier.precise, "s:s18AdditiveArithmeticPsE2seoiyyxz_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV")
        
        let paths = tree.caseInsensitiveDisambiguatedPaths(allowAdvancedDisambiguation: false)
        
        // Unmodified operator name in the path
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
        
        // "/" is an allowed character in URL paths.
        XCTAssertEqual("/Operators/MyNumber/_(_:_:)-7am4", paths["s:9Operators8MyNumberV1doiyA2C_ACtFZ"])
        XCTAssertEqual("/Operators/MyNumber/_=(_:_:)-3m4ko", paths["s:9Operators8MyNumberV2deoiyA2Cz_ACtFZ"])
        
        // Some of these have more human readable disambiguation alternatives
        let humanReadablePaths = tree.caseInsensitiveDisambiguatedPaths()
        
        XCTAssertEqual("/Operators/MyNumber/...(_:)->PartialRangeFrom<Self>", humanReadablePaths["s:SLsE3zzzoPys16PartialRangeFromVyxGxFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        XCTAssertEqual("/Operators/MyNumber/...(_:)->PartialRangeThrough<Self>", humanReadablePaths["s:SLsE3zzzopys19PartialRangeThroughVyxGxFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        
        XCTAssertEqual("/Operators/MyNumber/_(_:_:)-(Self,_)",  /* >(_:_:) */ humanReadablePaths["s:SLsE1goiySbx_xtFZ::SYNTHESIZED::s:9Operators8MyNumberV"])
        
        XCTAssertEqual("/Operators/MyNumber/_(_:_:)->MyNumber", humanReadablePaths["s:9Operators8MyNumberV1doiyA2C_ACtFZ"])
        XCTAssertEqual("/Operators/MyNumber/_=(_:_:)->MyNumber", humanReadablePaths["s:9Operators8MyNumberV2deoiyA2Cz_ACtFZ"])
    }
    
    func testSameNameForSymbolAndContainer() throws {
        let (_, context) = try testBundleAndContext(named: "BundleWithSameNameForSymbolAndContainer")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        // public struct Something {
        //     public struct Something {
        //         public enum SomethingElse {}
        //     }
        //     public enum SomethingElse {}
        // }
        let moduleID = try tree.find(path: "/SameNames", onlyFindSymbols: true)
        let outerStructID = try tree.find(path: "Something", parent: moduleID, onlyFindSymbols: true)
        
        XCTAssertEqual(try tree.findSymbol(path: "Something", parent: moduleID).identifier.precise, "s:9SameNames9SomethingV") // the outer Something struct
        XCTAssertEqual(try tree.findSymbol(path: "Something", parent: moduleID).absolutePath, "Something")
        XCTAssertEqual(try tree.findSymbol(path: "Something", parent: outerStructID).identifier.precise, "s:9SameNames9SomethingVABV") // the inner Something struct
        XCTAssertEqual(try tree.findSymbol(path: "Something", parent: outerStructID).absolutePath, "Something/Something")
        
        let innerStructID = try tree.find(path: "Something", parent: outerStructID, onlyFindSymbols: true)
        
        XCTAssertEqual(try tree.findSymbol(path: "SomethingElse", parent: outerStructID).identifier.precise, "s:9SameNames9SomethingV0C4ElseO") // the enum within the outer Something struct
        XCTAssertEqual(try tree.findSymbol(path: "SomethingElse", parent: outerStructID).absolutePath, "Something/SomethingElse")
        XCTAssertEqual(try tree.findSymbol(path: "SomethingElse", parent: innerStructID).identifier.precise, "s:9SameNames9SomethingVABV0C4ElseO") // the enum within the inner Something struct
        XCTAssertEqual(try tree.findSymbol(path: "SomethingElse", parent: innerStructID).absolutePath, "Something/Something/SomethingElse")
        
        XCTAssertEqual(try tree.findSymbol(path: "Something/SomethingElse", parent: outerStructID).identifier.precise, "s:9SameNames9SomethingVABV0C4ElseO") // the enum within the inner Something struct
        XCTAssertEqual(try tree.findSymbol(path: "Something/SomethingElse", parent: outerStructID).absolutePath, "Something/Something/SomethingElse")
        XCTAssertEqual(try tree.findSymbol(path: "Something/SomethingElse", parent: innerStructID).identifier.precise, "s:9SameNames9SomethingVABV0C4ElseO") // the enum within the inner Something struct
        XCTAssertEqual(try tree.findSymbol(path: "Something/SomethingElse", parent: innerStructID).absolutePath, "Something/Something/SomethingElse")
        
        XCTAssertEqual(try tree.findSymbol(path: "Something/SomethingElse", parent: moduleID).identifier.precise, "s:9SameNames9SomethingV0C4ElseO") // the enum within the outer Something struct
        XCTAssertEqual(try tree.findSymbol(path: "Something/SomethingElse", parent: moduleID).absolutePath, "Something/SomethingElse")
    }
    
    func testPrefersNonSymbolsWhenOnlyFindSymbolIsFalse() throws {
        let (_, _, context) = try testBundleAndContext(copying: "SymbolsWithSameNameAsModule") { url in
            // This bundle has a top-level struct named "Wrapper". Adding an article named "Wrapper.md" introduces a possibility for a link collision
            try """
            # An article
            
            This is an article with the same name as a top-level symbol
            """.write(to: url.appendingPathComponent("Wrapper.md"), atomically: true, encoding: .utf8)
            
            // Also change the display name so that the article container has the same name as the module.
            try InfoPlist(displayName: "Something", identifier: "com.example.Something").write(inside: url)
        }
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        do {
            // Links to non-symbols can use only the file name, without specifying the module or catalog name.
            let articleID = try tree.find(path: "Wrapper", onlyFindSymbols: false)
            let articleMatch = try XCTUnwrap(tree.lookup[articleID])
            XCTAssertNil(articleMatch.symbol, "Should have found the article")
        }
        do {
            // Links to non-symbols can also use module-relative links.
            let articleID = try tree.find(path: "/Something/Wrapper", onlyFindSymbols: false)
            let articleMatch = try XCTUnwrap(tree.lookup[articleID])
            XCTAssertNil(articleMatch.symbol, "Should have found the article")
        }
        // Symbols can only use absolute links or be found relative to another page.
        let symbolID = try tree.find(path: "/Something/Wrapper", onlyFindSymbols: true)
        let symbolMatch = try XCTUnwrap(tree.lookup[symbolID])
        XCTAssertNotNil(symbolMatch.symbol, "Should have found the struct")
    }
    
    func testOneSymbolPathsWithKnownDisambiguation() throws {
        let exampleDocumentation = Folder(name: "MyKit.docc", content: [
            CopyOfFile(original: Bundle.module.url(forResource: "mykit-one-symbol.symbols", withExtension: "json", subdirectory: "Test Resources")!),
            InfoPlist(displayName: "MyKit", identifier: "com.test.MyKit"),
        ])
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try exampleDocumentation.write(inside: tempURL)

        do {
            let (_, _, context) = try loadBundle(from: bundleURL)
            let tree = context.linkResolver.localResolver.pathHierarchy
            
            try assertFindsPath("/MyKit/MyClass/myFunction()", in: tree, asSymbolID: "s:5MyKit0A5ClassC10myFunctionyyF")
            try assertPathNotFound("/MyKit/MyClass-swift.class/myFunction()", in: tree)
            try assertPathNotFound("/MyKit/MyClass", in: tree)
            
            XCTAssertEqual(tree.caseInsensitiveDisambiguatedPaths()["s:5MyKit0A5ClassC10myFunctionyyF"],
                           "/MyKit/MyClass/myFunction()")
            
            XCTAssertEqual(context.documentationCache.reference(symbolID: "s:5MyKit0A5ClassC10myFunctionyyF")?.path,
                           "/documentation/MyKit/MyClass/myFunction()")
        }
        
        do {
            let (_, _, context) = try loadBundle(from: bundleURL) { context in
                context.knownDisambiguatedSymbolPathComponents = [
                    "s:5MyKit0A5ClassC10myFunctionyyF": ["MyClass-swift.class", "myFunction()"]
                ]
            }
            let tree = context.linkResolver.localResolver.pathHierarchy
            
            try assertFindsPath("/MyKit/MyClass-swift.class/myFunction()", in: tree, asSymbolID: "s:5MyKit0A5ClassC10myFunctionyyF")
            try assertPathNotFound("/MyKit/MyClass", in: tree)
            try assertPathNotFound("/MyKit/MyClass-swift.class", in: tree)
            
            XCTAssertEqual(tree.caseInsensitiveDisambiguatedPaths()["s:5MyKit0A5ClassC10myFunctionyyF"],
                           "/MyKit/MyClass-class/myFunction()")
            
            XCTAssertEqual(context.documentationCache.reference(symbolID: "s:5MyKit0A5ClassC10myFunctionyyF")?.path,
                           "/documentation/MyKit/MyClass-swift.class/myFunction()")
        }
        
        do {
            let (_, _, context) = try loadBundle(from: bundleURL) { context in
                context.knownDisambiguatedSymbolPathComponents = [
                    "s:5MyKit0A5ClassC10myFunctionyyF": ["MyClass-swift.class-hash", "myFunction()"]
                ]
            }
            let tree = context.linkResolver.localResolver.pathHierarchy
            
            try assertFindsPath("/MyKit/MyClass-swift.class-hash/myFunction()", in: tree, asSymbolID: "s:5MyKit0A5ClassC10myFunctionyyF")
            try assertPathNotFound("/MyKit/MyClass", in: tree)
            try assertPathNotFound("/MyKit/MyClass-swift.class", in: tree)
            try assertPathNotFound("/MyKit/MyClass-swift.class-hash", in: tree)
            
            
            XCTAssertEqual(tree.caseInsensitiveDisambiguatedPaths()["s:5MyKit0A5ClassC10myFunctionyyF"],
                           "/MyKit/MyClass-class-hash/myFunction()")
            
            XCTAssertEqual(context.documentationCache.reference(symbolID: "s:5MyKit0A5ClassC10myFunctionyyF")?.path,
                           "/documentation/MyKit/MyClass-swift.class-hash/myFunction()")
        }
    }
    
    func testArticleWithDisambiguationLookingName() throws {
        let exampleDocumentation = Folder(name: "MyKit.docc", content: [
            CopyOfFile(original: Bundle.module.url(forResource: "BaseKit.symbols", withExtension: "json", subdirectory: "Test Resources")!),
            InfoPlist(displayName: "BaseKit", identifier: "com.test.BaseKit"),
            TextFile(name: "basekit.md", utf8Content: """
            # ``BaseKit``
            
            Curate an article that look like a disambiguated symbol
            
            ## Topics
            
            - <doc:OtherStruct>
            - <doc:OtherStruct-abcd>
            """),
            TextFile(name: "OtherStruct-abcd.md", utf8Content: """
            # Some article
            
            An article with a file name that resembles a disambiguated symbol name.
            """),
        ])
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try exampleDocumentation.write(inside: tempURL)

        do {
            let (_, _, context) = try loadBundle(from: bundleURL)
            XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map { DiagnosticConsoleWriter.formattedDescription(for: $0) })")
            
            let tree = context.linkResolver.localResolver.pathHierarchy
            
            let baseKitID = try tree.find(path: "/BaseKit", onlyFindSymbols: true)
            
            XCTAssertEqual(try tree.findSymbol(path: "OtherStruct", parent: baseKitID).identifier.precise, "s:7BaseKit11OtherStructV")
            
            let articleID = try tree.find(path: "OtherStruct-abcd", parent: baseKitID, onlyFindSymbols: false)
            let articleNode = try XCTUnwrap(tree.lookup[articleID])
            XCTAssertNil(articleNode.symbol)
            XCTAssertEqual(articleNode.name, "OtherStruct-abcd")
        }
    }
    
    func testGeometricalShapes() throws {
        let (_, context) = try testBundleAndContext(named: "GeometricalShapes")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let paths = tree.caseInsensitiveDisambiguatedPaths().values.sorted()
        XCTAssertEqual(paths, [
            "/GeometricalShapes",
            "/GeometricalShapes/Circle",
            "/GeometricalShapes/Circle/center",
            "/GeometricalShapes/Circle/debugDescription",
            "/GeometricalShapes/Circle/defaultRadius",
            "/GeometricalShapes/Circle/init()",
            "/GeometricalShapes/Circle/init(center:radius:)",
            "/GeometricalShapes/Circle/init(string:)",
            "/GeometricalShapes/Circle/intersects(_:)",
            "/GeometricalShapes/Circle/isEmpty",
            "/GeometricalShapes/Circle/isNull",
            "/GeometricalShapes/Circle/null",
            "/GeometricalShapes/Circle/radius",
            "/GeometricalShapes/Circle/zero",
            "/GeometricalShapes/TLACircleMake",
        ])
    }
    
    func testPartialSymbolGraphPaths() throws {
        let symbolPaths = [
            ["A", "B", "C"],
            ["A", "B", "C2"],
            ["X", "Y"],
            ["X", "Y2", "Z", "W"],
        ]
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "Module.symbols.json", content: makeSymbolGraph(
                moduleName: "Module",
                symbols: symbolPaths.map { ($0.joined(separator: "."), .swift, $0, .class) }
            )),
        ])
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try exampleDocumentation.write(inside: tempURL)
        
        let (_, _, context) = try loadBundle(from: bundleURL)
        let tree = context.linkResolver.localResolver.pathHierarchy
        
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
    
    func testMixedLanguageSymbolWithSameKindAndAddedMemberFromExtendingModule() throws {
        let containerID = "some-container-symbol-id"
        let memberID = "some-member-symbol-id"
        
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            Folder(name: "clang", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName", 
                    symbols: [
                        (containerID, .objectiveC, ["ContainerName"], .class)
                    ]
                )),
            ]),
            
            Folder(name: "swift", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    symbols: [
                        (containerID, .swift, ["ContainerName"], .class)
                    ]
                )),
                
                JSONFile(name: "ExtendingModule@ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ExtendingModule",
                    symbols: [
                        (memberID, .swift, ["ContainerName", "MemberName"], .property)
                    ],
                    relationships: [
                        .init(source: memberID, target: containerID, kind: .memberOf, targetFallback: nil)
                    ]
                )),
            ])
        ])
        
        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, _, context) = try loadBundle(from: tempURL)
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        XCTAssertEqual(paths[containerID], "/ModuleName/ContainerName")
        XCTAssertEqual(paths[memberID], "/ModuleName/ContainerName/MemberName")
    }
    
    func testMixedLanguageSymbolWithDifferentKindsAndAddedMemberFromExtendingModule() throws {
        let containerID = "some-container-symbol-id"
        let memberID = "some-member-symbol-id"
        
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            Folder(name: "clang", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    symbols: [
                        (containerID, .objectiveC, ["ContainerName"], .typealias)
                    ]
                )),
            ]),
            
            Folder(name: "swift", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    symbols: [
                        (containerID, .swift, ["ContainerName"], .struct)
                    ]
                )),
                
                JSONFile(name: "ExtendingModule@ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ExtendingModule",
                    symbols: [
                        (memberID, .swift, ["ContainerName", "MemberName"], .property)
                    ],
                    relationships: [
                        .init(source: memberID, target: containerID, kind: .memberOf, targetFallback: nil)
                    ]
                )),
            ])
        ])
        
        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, _, context) = try loadBundle(from: tempURL)
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        XCTAssertEqual(paths[containerID], "/ModuleName/ContainerName")
        XCTAssertEqual(paths[memberID], "/ModuleName/ContainerName/MemberName")
    }
    
    func testLanguageRepresentationsWithDifferentCapitalization() throws {
        let containerID = "some-container-symbol-id"
        let memberID = "some-member-symbol-id"
        
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            Folder(name: "clang", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName", 
                    symbols: [
                        (containerID, .objectiveC, ["ContainerName"], .class),
                        (memberID, .objectiveC, ["ContainerName", "MemberName"], .property), // member starts with uppercase "M"
                    ],
                    relationships: [
                        .init(source: memberID, target: containerID, kind: .memberOf, targetFallback: nil)
                    ]
                )),
            ]),
            
            Folder(name: "swift", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    symbols: [
                        (containerID, .swift, ["ContainerName"], .class),
                        (memberID, .swift, ["ContainerName", "memberName"], .property), // member starts with lowercase "m"
                    ],
                    relationships: [
                        .init(source: memberID, target: containerID, kind: .memberOf, targetFallback: nil)
                    ]
                )),
            ])
        ])
        
        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, _, context) = try loadBundle(from: tempURL)
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        XCTAssertEqual(paths[containerID], "/ModuleName/ContainerName")
        XCTAssertEqual(paths[memberID], "/ModuleName/ContainerName/memberName") // The Swift spelling is preferred
    }
    
    func testMixedLanguageSymbolAndItsExtendingModuleWithDifferentContainerNames() throws {
        let containerID = "some-container-symbol-id"
        let memberID = "some-member-symbol-id"
        
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            Folder(name: "clang", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    symbols: [
                        (containerID, .objectiveC, ["ObjectiveCContainerName"], .class)
                    ]
                )),
            ]),
            
            Folder(name: "swift", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    symbols: [
                        (containerID, .swift, ["SwiftContainerName"], .class)
                    ]
                )),
                
                JSONFile(name: "ExtendingModule@ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ExtendingModule",
                    symbols: [
                        (memberID, .swift, ["SwiftContainerName", "MemberName"], .property)
                    ],
                    relationships: [
                        .init(source: memberID, target: containerID, kind: .memberOf, targetFallback: nil)
                    ]
                )),
            ])
        ])
        
        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, _, context) = try loadBundle(from: tempURL)
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        XCTAssertEqual(paths[containerID], "/ModuleName/SwiftContainerName")
        XCTAssertEqual(paths[memberID], "/ModuleName/SwiftContainerName/MemberName")
    }
    
    func testOptionalMemberUnderCorrectContainer() throws {
        let containerID = "some-container-symbol-id"
        let otherID = "some-other-symbol-id"
        let memberID = "some-member-symbol-id"
        
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                moduleName: "ModuleName",
                symbols: [
                    (containerID, .swift, ["ContainerName"], .class),
                    (otherID, .swift, ["ContainerName"], .class),
                    (memberID, .swift, ["ContainerName", "MemberName1"], .property),
                ],
                relationships: [
                    .init(source: memberID, target: containerID, kind: .optionalMemberOf, targetFallback: nil),
                ]
            ))
        ])
        
        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, _, context) = try loadBundle(from: tempURL)
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let paths = tree.caseInsensitiveDisambiguatedPaths(includeDisambiguationForUnambiguousChildren: true)
        XCTAssertEqual(paths[otherID], "/ModuleName/ContainerName-2vaqf")
        XCTAssertEqual(paths[containerID], "/ModuleName/ContainerName-qwwf")
        XCTAssertEqual(paths[memberID], "/ModuleName/ContainerName-qwwf/MemberName1")
    }
    
    func testLinkToTopicSection() throws {
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                moduleName: "ModuleName",
                symbols: [
                    ("some-symbol-id", .swift, ["SymbolName"], .class),
                ],
                relationships: []
            )),
            
            TextFile(name: "ModuleName.md", utf8Content: """
            # ``ModuleName``
            
            A module with some named topic sections
            
            ## Other level 2 heading
            
            Some content
            
            ### Other level 3 heading
            
            Some more content
            
            ## Topics
            
            ### My classes
            
            - ``SymbolName``
            
            ### My articles
            
            - <doc:Article>
            """),
            
            TextFile(name: "Article.md", utf8Content: """
            # Some Article
            
            An article with a top-level topic section
            
            ## Topics
            
            - ``SymbolName``
            """)
        ])
        
        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, _, context) = try loadBundle(from: tempURL)
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let moduleID = try tree.find(path: "/ModuleName", onlyFindSymbols: true)
        // Relative link from the module to a topic section
        do {
            let topicSectionID = try tree.find(path: "#My-classes", parent: moduleID, onlyFindSymbols: false)
            let node = try XCTUnwrap(tree.lookup[topicSectionID])
            XCTAssertNil(node.symbol)
            XCTAssertEqual(node.name, "My-classes")
        }
        
        // Absolute link to a topic section on the module page
        do {
            let topicSectionID = try tree.find(path: "/ModuleName#My-classes", parent: nil, onlyFindSymbols: false)
            let node = try XCTUnwrap(tree.lookup[topicSectionID])
            XCTAssertNil(node.symbol)
            XCTAssertEqual(node.name, "My-classes")
        }
        
        // Absolute link to a heading on the module page
        do {
            let headingID = try tree.find(path: "/ModuleName#Other-level-2-heading", parent: nil, onlyFindSymbols: false)
            let node = try XCTUnwrap(tree.lookup[headingID])
            XCTAssertNil(node.symbol)
            XCTAssertEqual(node.name, "Other-level-2-heading")
        }
        
        // Relative link to a heading on the module page
        do {
            let headingID = try tree.find(path: "#Other-level-3-heading", parent: moduleID, onlyFindSymbols: false)
            let node = try XCTUnwrap(tree.lookup[headingID])
            XCTAssertNil(node.symbol)
            XCTAssertEqual(node.name, "Other-level-3-heading")
        }
        
        // Relative link to a top-level topic section on another page
        do {
            let topicSectionID = try tree.find(path: "Article#Topics", parent: moduleID, onlyFindSymbols: false)
            let node = try XCTUnwrap(tree.lookup[topicSectionID])
            XCTAssertNil(node.symbol)
            XCTAssertEqual(node.name, "Topics")
        }
        
        let paths = tree.caseInsensitiveDisambiguatedPaths(includeDisambiguationForUnambiguousChildren: true)
        XCTAssertEqual(paths.values.sorted(), [
            "/ModuleName",
            "/ModuleName/SymbolName",
        ], "The hierarchy only computes paths for symbols, not for headings or topic sections")
    }
    
    func testModuleAndCollidingTechnologyRootHasPathsForItsSymbols() throws {
        let symbolID = "some-symbol-id"
        
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                moduleName: "ModuleName",
                symbols: [
                    (symbolID, .swift, ["SymbolName"], .class),
                ],
                relationships: []
            )),
            
            TextFile(name: "ModuleName.md", utf8Content: """
            # Manual Technology Root
            
            @Metadata {
              @TechnologyRoot
            }
            
            A technology root with the same file name as the module name.
            """)
        ])
        
        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, _, context) = try loadBundle(from: tempURL)
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let paths = tree.caseInsensitiveDisambiguatedPaths(includeDisambiguationForUnambiguousChildren: true)
        XCTAssertEqual(paths[symbolID], "/ModuleName/SymbolName")
    }
    
    func testSameDefaultImplementationOnMultiplePlatforms() throws {
        let protocolID = "some-protocol-symbol-id"
        let protocolRequirementID = "some-protocol-requirement-symbol-id"
        let defaultImplementationID = "some-default-implementation-symbol-id"
        
        func makeSymbolGraphFile(platformName: String) -> JSONFile<SymbolGraph> {
            JSONFile(name: "\(platformName)-ModuleName.symbols.json", content: makeSymbolGraph(
                moduleName: "ModuleName",
                platformName: platformName,
                symbols: [
                    (protocolID, .swift, ["SomeProtocolName"], .class),
                    (protocolRequirementID, .swift, ["SomeProtocolName", "someProtocolRequirement()"], .class),
                    (defaultImplementationID, .swift, ["SomeConformingType", "someProtocolRequirement()"], .class),
                ],
                relationships: [
                    .init(source: protocolRequirementID, target: protocolID, kind: .requirementOf, targetFallback: nil),
                    .init(source: defaultImplementationID, target: protocolRequirementID, kind: .defaultImplementationOf, targetFallback: nil),
                ]
            ))
        }
        
        let multiPlatform = Folder(name: "unit-test.docc", content: [
            makeSymbolGraphFile(platformName: "PlatformOne"),
            makeSymbolGraphFile(platformName: "PlatformTwo"),
        ])
        
        let (_, _, context) = try loadBundle(from: createTempFolder(content: [multiPlatform]))
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let paths = tree.caseInsensitiveDisambiguatedPaths()
        XCTAssertEqual(paths[protocolRequirementID], "/ModuleName/SomeProtocolName/someProtocolRequirement()-8lcpm")
        XCTAssertEqual(paths[defaultImplementationID], "/ModuleName/SomeProtocolName/someProtocolRequirement()-3docm")
        
        // Verify that the multi platform paths are the same as the single platform paths
        let singlePlatform = Folder(name: "unit-test.docc", content: [
            makeSymbolGraphFile(platformName: "PlatformOne"),
        ])
        let (_, _, singlePlatformContext) = try loadBundle(from: createTempFolder(content: [singlePlatform]))
        let singlePlatformPaths = singlePlatformContext.linkResolver.localResolver.pathHierarchy.caseInsensitiveDisambiguatedPaths()
        XCTAssertEqual(paths[protocolRequirementID], singlePlatformPaths[protocolRequirementID])
        XCTAssertEqual(paths[defaultImplementationID], singlePlatformPaths[defaultImplementationID])
    }
    
    func testMultiPlatformModuleWithExtension() throws {
        let (_, context) = try testBundleAndContext(named: "MultiPlatformModuleWithExtension")
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        try assertFindsPath("/MainModule/TopLevelProtocol/extensionMember(_:)", in: tree, asSymbolID: "extensionMember1")
        try assertFindsPath("/MainModule/TopLevelProtocol/InnerStruct/extensionMember(_:)", in: tree, asSymbolID: "extensionMember2")
    }
    
    func testParsingPaths() {
        // Check path components without disambiguation
        assertParsedPathComponents("", [])
        assertParsedPathComponents("/", [])
        assertParsedPathComponents("/first", [("first", nil)])
        assertParsedPathComponents("first", [("first", nil)])
        assertParsedPathComponents("first/", [("first", nil)])
        assertParsedPathComponents("first/second/third", [("first", nil), ("second", nil), ("third", nil)])
        assertParsedPathComponents("/first/second/third", [("first", nil), ("second", nil), ("third", nil)])
        assertParsedPathComponents("first/", [("first", nil)])
        assertParsedPathComponents("first//second", [("first", nil), ("/second", nil)])
        assertParsedPathComponents("first/second#third", [("first", nil), ("second", nil), ("third", nil)])
        assertParsedPathComponents("#first", [("first", nil)])

        // Check disambiguation
        assertParsedPathComponents("path-hash", [("path", .kindAndHash(kind: nil, hash: "hash"))])
        assertParsedPathComponents("path-struct", [("path", .kindAndHash(kind: "struct", hash: nil))])
        assertParsedPathComponents("path-struct-hash", [("path", .kindAndHash(kind: "struct", hash: "hash"))])
        
        assertParsedPathComponents("path-swift.something", [("path", .kindAndHash(kind: "something", hash: nil))])
        assertParsedPathComponents("path-c.something", [("path", .kindAndHash(kind: "something", hash: nil))])
        
        assertParsedPathComponents("path-swift.something-hash", [("path", .kindAndHash(kind: "something", hash: "hash"))])
        assertParsedPathComponents("path-c.something-hash", [("path", .kindAndHash(kind: "something", hash: "hash"))])
        
        assertParsedPathComponents("path-type.property-hash", [("path", .kindAndHash(kind: "type.property", hash: "hash"))])
        assertParsedPathComponents("path-swift.type.property-hash", [("path", .kindAndHash(kind: "type.property", hash: "hash"))])
        assertParsedPathComponents("path-type.property", [("path", .kindAndHash(kind: "type.property", hash: nil))])
        assertParsedPathComponents("path-swift.type.property", [("path", .kindAndHash(kind: "type.property", hash: nil))])
        
        assertParsedPathComponents("-(_:_:)-hash", [("-(_:_:)", .kindAndHash(kind: nil, hash: "hash"))])
        assertParsedPathComponents("/=(_:_:)", [("/=(_:_:)", nil)])
        assertParsedPathComponents("/(_:_:)-func.op", [("/(_:_:)", .kindAndHash(kind: "func.op", hash: nil))])
        assertParsedPathComponents("//(_:_:)-hash", [("//(_:_:)", .kindAndHash(kind: nil, hash: "hash"))])
        assertParsedPathComponents("+/-(_:_:)", [("+/-(_:_:)", nil)])
        assertParsedPathComponents("+/-(_:_:)-hash", [("+/-(_:_:)", .kindAndHash(kind: nil, hash: "hash"))])
        assertParsedPathComponents("+/-(_:_:)-func.op", [("+/-(_:_:)", .kindAndHash(kind: "func.op", hash: nil))])
        assertParsedPathComponents("+/-(_:_:)-func.op-hash", [("+/-(_:_:)", .kindAndHash(kind: "func.op", hash: "hash"))])
        assertParsedPathComponents("+/-(_:_:)/+/-(_:_:)/+/-(_:_:)/+/-(_:_:)", [("+/-(_:_:)", nil), ("+/-(_:_:)", nil), ("+/-(_:_:)", nil), ("+/-(_:_:)", nil)])
        assertParsedPathComponents("+/-(_:_:)-hash/+/-(_:_:)-func.op/+/-(_:_:)-func.op-hash/+/-(_:_:)", [("+/-(_:_:)", .kindAndHash(kind: nil, hash: "hash")), ("+/-(_:_:)", .kindAndHash(kind: "func.op", hash: nil)), ("+/-(_:_:)", .kindAndHash(kind: "func.op", hash: "hash")), ("+/-(_:_:)", nil)])

        assertParsedPathComponents("MyNumber//=(_:_:)", [("MyNumber", nil), ("/=(_:_:)", nil)])
        assertParsedPathComponents("MyNumber////=(_:_:)", [("MyNumber", nil), ("///=(_:_:)", nil)])
        assertParsedPathComponents("MyNumber/+/-(_:_:)", [("MyNumber", nil), ("+/-(_:_:)", nil)])

        // Check parsing return values and parameter types
        assertParsedPathComponents("..<(_:_:)->Bool", [("..<(_:_:)", .typeSignature(parameterTypes: nil, returnTypes: ["Bool"]))])
        assertParsedPathComponents("..<(_:_:)-(_,Int)", [("..<(_:_:)", .typeSignature(parameterTypes: ["_", "Int"], returnTypes: nil))])
        
        
        assertParsedPathComponents("something(first:second:third:)->(_,_,_)", [("something(first:second:third:)", .typeSignature(parameterTypes: nil, returnTypes: ["_", "_", "_"]))])
        
        assertParsedPathComponents("something(first:second:third:)->(String,_,_)", [("something(first:second:third:)", .typeSignature(parameterTypes: nil, returnTypes: ["String", "_", "_"]))])
        assertParsedPathComponents("something(first:second:third:)->(_,Int,_)", [("something(first:second:third:)", .typeSignature(parameterTypes: nil, returnTypes: ["_", "Int", "_"]))])
        assertParsedPathComponents("something(first:second:third:)->(_,_,Bool)", [("something(first:second:third:)", .typeSignature(parameterTypes: nil, returnTypes: ["_", "_", "Bool"]))])
        
        assertParsedPathComponents("something(first:second:third:)->(String,Int,_)", [("something(first:second:third:)", .typeSignature(parameterTypes: nil, returnTypes: ["String", "Int", "_"]))])
        assertParsedPathComponents("something(first:second:third:)->(String,_,Bool)", [("something(first:second:third:)", .typeSignature(parameterTypes: nil, returnTypes: ["String", "_", "Bool"]))])
        assertParsedPathComponents("something(first:second:third:)->(_,Int,Bool)", [("something(first:second:third:)", .typeSignature(parameterTypes: nil, returnTypes: ["_", "Int", "Bool"]))])
        
        assertParsedPathComponents("something(first:second:third:)->(String,Int,Bool)", [("something(first:second:third:)", .typeSignature(parameterTypes: nil, returnTypes: ["String", "Int", "Bool"]))])
        
        // Check closure parameters
        assertParsedPathComponents("map(_:)-((Element)->T)", [("map(_:)", .typeSignature(parameterTypes: ["(Element)->T"], returnTypes: nil))])
        assertParsedPathComponents("map(_:)->[T]", [("map(_:)", .typeSignature(parameterTypes: nil, returnTypes: ["[T]"]))])
        
        assertParsedPathComponents("filter(_:)-((Element)->Bool)", [("filter(_:)", .typeSignature(parameterTypes: ["(Element)->Bool"], returnTypes: nil))])
        assertParsedPathComponents("filter(_:)->[Element]", [("filter(_:)", .typeSignature(parameterTypes: nil, returnTypes: ["[Element]"]))])
        
        assertParsedPathComponents("reduce(_:_:)-(Result,_)", [("reduce(_:_:)", .typeSignature(parameterTypes: ["Result", "_"], returnTypes: nil))])
        assertParsedPathComponents("reduce(_:_:)-(_,(Result,Element)->Result)", [("reduce(_:_:)", .typeSignature(parameterTypes: ["_", "(Result,Element)->Result"], returnTypes: nil))])
        
        assertParsedPathComponents("partition(by:)-((Element)->Bool)", [("partition(by:)", .typeSignature(parameterTypes: ["(Element)->Bool"], returnTypes: nil))])
        assertParsedPathComponents("partition(by:)->Index", [("partition(by:)", .typeSignature(parameterTypes: nil, returnTypes: ["Index"]))])
        
        assertParsedPathComponents("max(by:)-((Element,Element)->Bool)", [("max(by:)", .typeSignature(parameterTypes: ["(Element,Element)->Bool"], returnTypes: nil))])
        assertParsedPathComponents("max(by:)->Element?", [("max(by:)", .typeSignature(parameterTypes: nil, returnTypes: ["Element?"]))])
        
        // Nested tuples
        assertParsedPathComponents("functionName->((A,(B,C),D),(E,F),G)", [("functionName", .typeSignature(parameterTypes: nil, returnTypes: ["(A,(B,C),D)", "(E,F)", "G"]))])
        assertParsedPathComponents("functionName-((A,(B,C),D),(E,F),G)", [("functionName", .typeSignature(parameterTypes: ["(A,(B,C),D)", "(E,F)", "G"], returnTypes: nil))])
        
        // Nested closures
        assertParsedPathComponents("functionName->((A)->B,(C,(D)->E),(F,(G)->H)->I)", [("functionName", .typeSignature(parameterTypes: nil, returnTypes: ["(A)->B", "(C,(D)->E)", "(F,(G)->H)->I"]))])
        
        // Unicode characters and accents
        assertParsedPathComponents("functionName->((Å,(𝔹,©),Δ),(∃,⨍),𝄞)", [("functionName", .typeSignature(parameterTypes: nil, returnTypes: ["(Å,(𝔹,©),Δ)", "(∃,⨍)", "𝄞"]))])
        assertParsedPathComponents("functionName-((Å,(𝔹,©),Δ),(∃,⨍),𝄞)", [("functionName", .typeSignature(parameterTypes: ["(Å,(𝔹,©),Δ)", "(∃,⨍)", "𝄞"], returnTypes: nil))])
        assertParsedPathComponents("functionName->((Å)->𝔹,(©,(Δ)->∃),(⨍,(𝄞)->ℌ)->𝓲)", [("functionName", .typeSignature(parameterTypes: nil, returnTypes: ["(Å)->𝔹", "(©,(Δ)->∃)", "(⨍,(𝄞)->ℌ)->𝓲"]))])
    }
    
    // MARK: Test helpers
    
    private func makeSymbolGraph(
        moduleName: String,
        platformName: String? = nil,
        symbols: [(identifier: String, language: SourceLanguage, pathComponents: [String], kindID: SymbolGraph.Symbol.KindIdentifier)],
        relationships: [SymbolGraph.Relationship] = []
    ) -> SymbolGraph {
        return SymbolGraph(
            metadata: SymbolGraph.Metadata(formatVersion: .init(major: 0, minor: 5, patch: 3), generator: "unit-test"),
            module: SymbolGraph.Module(name: moduleName, platform: .init(operatingSystem: platformName.map { .init(name: $0) })),
            symbols: symbols.map { identifier, language, pathComponents, kindID in
                SymbolGraph.Symbol(
                    identifier: .init(precise: identifier, interfaceLanguage: language.id),
                    names: .init(title: "SymbolName", navigator: nil, subHeading: nil, prose: nil), // names doesn't matter for path disambiguation
                    pathComponents: pathComponents,
                    docComment: nil,
                    accessLevel: .public,
                    kind: .init(parsedIdentifier: kindID, displayName: "Kind Display Name"), // kind display names doesn't matter for path disambiguation
                    mixins: [:]
                )
            },
            relationships: relationships
        )
    }
    
    private func assertFindsPath(_ path: String, in tree: PathHierarchy, asSymbolID symbolID: String, file: StaticString = #file, line: UInt = #line) throws {
        do {
            let symbol = try tree.findSymbol(path: path)
            XCTAssertEqual(symbol.identifier.precise, symbolID, file: file, line: line)
        } catch PathHierarchy.Error.notFound {
            XCTFail("Symbol for \(path.singleQuoted) not found in tree", file: file, line: line)
        } catch PathHierarchy.Error.unknownName {
            XCTFail("Symbol for \(path.singleQuoted) not found in tree. Only part of path is found.", file: file, line: line)
        } catch PathHierarchy.Error.unknownDisambiguation {
            XCTFail("Symbol for \(path.singleQuoted) not found in tree. Unknown disambiguation.", file: file, line: line)
        } catch PathHierarchy.Error.lookupCollision(_, _, let collisions) {
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
        } catch PathHierarchy.Error.unknownName {
            // For the purpose of this assertion, this also counts as "not found".
        } catch PathHierarchy.Error.unknownDisambiguation {
            // For the purpose of this assertion, this also counts as "not found".
        } catch PathHierarchy.Error.lookupCollision(_, _, let collisions) {
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
        } catch PathHierarchy.Error.unknownName {
            XCTFail("Symbol for \(path.singleQuoted) not found in tree. Only part of path is found.", file: file, line: line)
        } catch PathHierarchy.Error.unknownDisambiguation {
            XCTFail("Symbol for \(path.singleQuoted) not found in tree. Unknown disambiguation.", file: file, line: line)
        } catch PathHierarchy.Error.lookupCollision(_, _, let collisions) {
            let sortedCollisions = collisions.sorted(by: \.disambiguation)
            XCTAssertEqual(sortedCollisions.count, expectedCollisions.count, file: file, line: line)
            for (actual, expected) in zip(sortedCollisions, expectedCollisions) {
                XCTAssertEqual(actual.node.symbol?.identifier.precise, expected.symbolID, file: file, line: line)
                XCTAssertEqual(actual.disambiguation, expected.disambiguation, file: file, line: line)
            }
        }
    }
    
    private func assertPathRaisesErrorMessage(_ path: String, in tree: PathHierarchy, context: DocumentationContext, expectedErrorMessage: String, file: StaticString = #file, line: UInt = #line, _ additionalAssertion: (TopicReferenceResolutionErrorInfo) -> Void = { _ in }) throws {
        XCTAssertThrowsError(try tree.findSymbol(path: path), "Finding path \(path) didn't raise an error.",file: file,line: line) { untypedError in
            let error = untypedError as! PathHierarchy.Error
            let referenceError = error.makeTopicReferenceResolutionErrorInfo() { context.linkResolver.localResolver.fullName(of: $0, in: context) }
            XCTAssertEqual(referenceError.message, expectedErrorMessage, file: file, line: line)
            additionalAssertion(referenceError)
        }
    }
    
    private func assertParsedPathComponents(_ path: String, _ expected: [(String, PathHierarchy.PathComponent.Disambiguation?)], file: StaticString = #file, line: UInt = #line) {
        let (actual, _) = PathHierarchy.PathParser.parse(path: path)
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (actualComponents, expectedComponents) in zip(actual, expected) {
            XCTAssertEqual(String(actualComponents.name), expectedComponents.0, "Incorrect path component", file: file, line: line)
            switch (actualComponents.disambiguation, expectedComponents.1) {
            case (.kindAndHash(let actualKind, let actualHash), .kindAndHash(let expectedKind, let expectedHash)):
                XCTAssertEqual(actualKind, expectedKind, "Incorrect kind disambiguation", file: file, line: line)
                XCTAssertEqual(actualHash, expectedHash, "Incorrect hash disambiguation", file: file, line: line)
            case (.typeSignature(let actualParameters, let actualReturns), .typeSignature(let expectedParameters, let expectedReturns)):
                XCTAssertEqual(actualParameters, expectedParameters, "Incorrect parameter type disambiguation", file: file, line: line)
                XCTAssertEqual(actualReturns, expectedReturns, "Incorrect return type disambiguation", file: file, line: line)
            case (nil, nil):
                continue
            default:
                XCTFail("Incorrect type of disambiguation", file: file, line: line)
            }
        }
    }
}

extension PathHierarchy {
    func findNode(path rawPath: String, onlyFindSymbols: Bool, parent: ResolvedIdentifier? = nil) throws -> PathHierarchy.Node {
        let id = try find(path: rawPath, parent: parent, onlyFindSymbols: onlyFindSymbols)
        return lookup[id]!
    }
    
    func findSymbol(path rawPath: String, parent: ResolvedIdentifier? = nil) throws -> SymbolGraph.Symbol {
        return try findNode(path: rawPath, onlyFindSymbols: true, parent: parent).symbol!
    }
}

private extension TopicReferenceResolutionErrorInfo {
    var solutions: [SimplifiedSolution] {
        self.solutions(referenceSourceRange: SourceLocation(line: 0, column: 0, source: nil)..<SourceLocation(line: 0, column: 0, source: nil)).map { solution in
            SimplifiedSolution(summary: solution.summary, replacements: solution.replacements.map {
                (
                    $0.replacement,
                    start: $0.range.lowerBound.column,
                    end: $0.range.upperBound.column
                )
            })
        }
    }
}

private struct SimplifiedSolution: Equatable {
    let summary: String
    let replacements: [(String, start: Int, end: Int)]
    
    static func == (lhs: SimplifiedSolution, rhs: SimplifiedSolution) -> Bool {
        return lhs.summary == rhs.summary
            && lhs.replacements.elementsEqual(rhs.replacements, by: ==)
    }
}
