/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// This is the header corresponding to the symbol graph files 
// generated in this catalog.

#import <Foundation/Foundation.h>

const NSErrorDomain MyErrorDomain;

// This generates a Swift-only struct for MyError which automatically
// curates a multi-language enumeration for `MyError.Code` / `MyError`.

typedef NS_ERROR_ENUM(MyErrorDomain, MyError) {
    MyErrorUnknown = 1,
};

@end
