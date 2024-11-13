# Documenting API with Different Language Representations

Create documentation for API that's callable from more than one source language.

## Overview

When a symbol has representations in more than one source language, DocC adds a source language toggle to the symbol's page so that the reader can select which language's representation of the symbol to view.  

The documentation you write for the symbol---both in-source, alongside its declaration, and in a documentation extension file---is displayed in all language versions of that symbol's page. 

### Linking to Symbols with Different Language Representations

You can use either source language's spelling of the symbol path to refer to the symbol in a symbol link. 
For example, consider a `Sloth` class with `@objc` attributes:

```swift
@objc(TLASloth) public class Sloth: NSObject {
    @objc public init(name: String, color: Color, power: Power) {
        self.name = name
        self.color = color
        self.power = power
    }
}
```

Both ` ``Sloth/init(name:color:power:)`` ` and ` ``TLASloth/initWithName:color:power:`` ` refer to the same Sloth initializer. 

Regardless of which source language's spelling you use in the symbol link, DocC matches the on-page link text to the symbol name in the source language version of the page that the reader selected. If the symbol doesn't have a representation in the source language that the reader selected, the link text will use the symbol name in the language that declared the symbol.

For more information about linking to symbols, see <doc:linking-to-symbols-and-other-content>.

### Document Language Specific Parameters and Return Values

When a symbol has different parameters or return values in different source language representations, DocC hides the documentation for the parameters or return values that don't apply to the source language version of the page that the reader selected. For example, consider an Objective-C method with an `error` parameter and a `BOOL` return value that correspond to a throwing function without a return value in Swift:

**Objective-C definition**

```objc
/// - Parameters:
///   - someValue: Some description of this parameter.
///   - error: On output, a pointer to an error object that describes why "doing something" failed, or `nil` if no error occurred.
/// - Returns: `YES` if "doing something" was successful, `NO` if an error occurred.
- (BOOL)doSomethingWith:(NSInteger)someValue
                  error:(NSError **)error;
```

**Generated Swift interface**

```swift
func doSomething(with someValue: Int) throws
```

Because the Swift representation of this method only has the "someValue" parameter and no return value, DocC hides the "error" parameter documentation and the return value documentation from the Swift version of this symbol's page.

You don't need to document the Objective-C representation's "error" parameter or the Objective-C specific return value for methods that correspond to throwing functions in Swift.
DocC automatically adds a generic description for the "error" parameter for the Objective-C version of that symbol's page. 

When the Swift representation returns `Void`---which corresponds to a `BOOL` return value in Objective-C (like in the example above)---DocC adds a generic description of the `BOOL` return value to the Objective-C version of that symbol's page. 

When the Swift representation returns a value---which corresponds to a `nullable` return value in Objective-C---DocC extends your return value documentation, for the Objective-C version of that symbol's page, to describe that the methods returns `nil` if an error occurs unless your documentation already covers this behavior. 
For example, consider this throwing function in Swift and its corresponding Objective-C interface:

**Swift definition**

```swift
/// - Parameters:
///   - someValue: Some description of this parameter.
/// - Returns: Some description of this return value.
@objc func doSomething(with someValue: Int) throws -> String
```

**Generated Objective-C interface**

```objc
- (nullable NSString *)doSomethingWith:(NSInteger)someValue
                                 error:(NSError **)error;
```

For the Swift representation, with one parameter and a non-optional return value,
DocC displays the "someValue" parameter documentation and return value documentation as-is.
For the Objective-C representation, with two parameters and a nullable return value,
DocC displays the "someValue" parameter documentation, generic "error" parameter documentation, and extends the return value documentation with a generic description about the Objective-C specific `nil` return value when the method encounters an error. 

If you want to customize this documentation you can manually document the "error" parameter and return value.
Doing so won't change the Swift version of that symbol's page.
DocC will still hide the parameter and return value documentation that doesn't apply to each source language's version of that symbol's page.

If your return value documentation already describes the `nil` return value, DocC won't extent it with the generic `nil` value description.

> Note:
> If you document the Objective-C specific `nil` return value for a method that correspond to a throwing function in Swift, 
> DocC will display that documentation as-is on the Swift version of that page where is has a non-optional return type.

<!-- Copyright (c) 2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->
