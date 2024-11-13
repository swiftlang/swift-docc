# Linking to Symbols and Other Content

Facilitate navigation between pages using links.

## Overview

DocC supports the following link types to enable navigation between pages:

| Type     | Usage 
| -------- | ----- 
| Symbol   | Links to a symbol's reference page in your documentation.
| Article  | Links to an article or API collection in your documentation catalog.
| Tutorial | Links to a tutorial in your documentation catalog.
| Web      | Links to an external URL.

### Navigate to a Symbol

To add a link to a symbol in your module, wrap the symbol's name in a set of double backticks (\`\`):

```markdown
``Sloth``
```

For links to member symbols or nested types, include the path to the symbol in the link:

```markdown
``Sloth/eat(_:quantity:)``
``Sloth/Food``
```

DocC resolves symbol links relative to the context that the link appears in.
This allows links in a type's documentation comment to omit the type's name from the symbol path when referring to its members.
For example, in the `Sloth` structure below, the `init(name:color:power:)` symbol link omits the `Sloth/` portion of the symbol path:

```swift
/// ...
/// You can create a sloth using ``init(name:color:power:)``.
public struct Sloth { //           ╰──────────┬──────────╯
    /// ...           //                      ╰─────refers-to────╮
    public init(name: String, color: Color, power: Power) { // ◁─╯ 
        /* ... */ 
    }         
}
```

If DocC can't resolve a link in the current context, it gradually expands the search to the containing scope.
This allows links from one member to another member of the same type to omit the containing type's name from the symbol path.
For example, in the `Sloth` structure below, 
the `eat(_:quantity:)` symbol link in the `energyLevel` property's documentation comment omits the `Sloth/` portion of the symbol path:

```swift
/// ...
public struct Sloth {
    /// ... 
    /// Restore the sloth's energy using ``eat(_:quantity:)``.
    public var energyLevel = 10 //         ╰───────┬──────╯       
                                //                 │ 
    /// ...                     //                 ╰──────refers-to─────╮
    public mutating func eat(_ food: Food, quantity: Int) -> Int { // ◁─╯ 
        /* ... */
    }
}
```

> Note:
If you prefer absolute symbol links you can prefix the symbol path with a leading slash followed by the name of the module that symbol belongs:
>
> ```markdown
> ``/SlothCreator/Sloth``
> ``/SlothCreator/Sloth/eat(_:quantity:)``
> ``/SlothCreator/Sloth/Food``
> ```
>
> DocC resolves absolute symbol links from the module's scope instead of the context that the link appears in.  

Symbol paths are case-sensitive, meaning that symbols with the same name in different text casing are unambiguous.
For example, consider a `Sloth` structure with both a `color` property and a `Color` enumeration type:

```swift
public struct Sloth {
    public var color: Color 

    public enum Color {
        /* ... */
    }
}
```

A ` ``Sloth/color`` ` symbol link unambiguously refers to the `color` property and a ` ``Sloth/Color`` ` symbol link unambiguously refers to the inner `Color` type.

#### Symbols with Multiple Language Representations

Symbol links to symbols that have representations in more than one programming language can use symbol paths in either source language. 
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

You can write a symbol link to the Sloth initializer using the symbol path in either source language:

**Swift name**

```markdown
``Sloth/init(name:color:power:)``
```

**Objective-C name**

```markdown
``TLASloth/initWithName:color:power:``
```

#### Ambiguous Symbol Links

In some cases a symbol's path isn't unique.
This makes it ambiguous what specific symbol a symbol link refers to. 
For example, consider a `Color` structure with `red`, `green`, and `blue` properties for color components and static properties for a handful of predefined color values:

```swift
public struct Color {
    public var red, green, blue: Double
}

extension Color {
    public static let red    = Color(red: 1.0, green: 0.0, blue: 0.0)
    public static let purple = Color(red: 0.5, green: 0.0, blue: 0.5)
    public static let blue   = Color(red: 0.0, green: 0.0, blue: 1.0)
}
```

Both the `red` property and the `red` static property have a symbol path of `Color/red`. 
Because these are different types of symbols you can disambiguate ` ``Color/red`` ` with a suffix indicating the symbol's type.

The following example shows a symbol link to the `red` property:

```markdown
``Color/red-property``
```

The following example shows a symbol link to the `red` static property:

```markdown
``Color/red-type.property``
```

DocC supports the following symbol types as disambiguation in symbol links:

| Symbol type       | Suffix            |
|-------------------|-------------------|
| Enumeration       | `-enum`           |
| Enumeration case  | `-enum.case`      |
| Protocol          | `-protocol`       |
| Typealias         | `-typealias`      |
| Associated Type   | `-associatedtype` |
| Structure         | `-struct`         |
| Class             | `-class`          |
| Function          | `-func`           |
| Operator          | `-func.op`        |
| Property          | `-property`       |
| Type property     | `-type.property`  |
| Method            | `-method`         |
| Type method       | `-type.method`    |
| Subscript         | `-subscript`      |
| Type subscript    | `-type.subscript` |
| Initializer       | `-init`           |
| Deinitializer     | `-deinit`         |
| Global variable   | `-var`            |
| Instance variable | `-ivar`           |
| Macro             | `-macro`          |
| Module            | `-module`         |
| Namespace         | `-namespace`      |
| HTTP Request      | `-httpRequest`    |
| HTTP Parameter    | `-httpParameter`  |
| HTTP Response     | `-httpResponse`   |
| HTTPBody          | `-httpBody`       |
| Dictionary        | `-dictionary`     |
| Dictionary Key    | `-dictionaryKey`  |

You can discover these symbol type suffixes from DocC's warnings about ambiguous symbol links.
DocC suggests one disambiguation for each of the symbols that match the ambiguous symbol path.

Symbol type suffixes can include a source language identifier prefix---for example, `-swift.enum` instead of `-enum`. 
However, the language identifier doesn't disambiguate the link.


In the example above, both symbols that match the ambiguous symbol path were different types of symbol.
If the symbols that match the ambiguous symbol path have are the same type of symbol, 
such as with overloaded methods in Swift, a symbol type suffix won't disambiguate the link.
In this scenario, DocC uses information from the symbols' type signatures to disambiguate.
For example, consider the `Sloth` structure---from the SlothCreator example---which has two different `update(_:)` methods:

```swift
/// Updates the sloth's power.
///
/// - Parameter power: The sloth's new power.
mutating public func update(_ power: Power) {
    self.power = power
}

/// Updates the sloth's energy level.
///
/// - Parameter energyLevel: The sloth's new energy level.
mutating public func update(_ energyLevel: Int) {
    self.energyLevel = energyLevel
}
```

Both methods have an identical symbol path of `SlothCreator/Sloth/update(_:)`. 
In this example there's only one parameter and its type is `Power` for the first overload and `Int` for the second overload. 
DocC uses this parameter type information to suggest adding `(Power)` and `(Int)` to disambiguate each respective overload.

The following example shows a topic group with disambiguated symbol links to both `Sloth/update(_:)` methods:

```markdown
### Updating Sloths

- ``Sloth/update(_:)-(Power)``
- ``Sloth/update(_:)-(Int)``
```

If there are more overloads with more parameters and return values, 
DocC may suggest a combination of parameter types and return value types to uniquely disambiguate each overload. 
For example consider a hypothetical weather service with these three overloads---with different parameter types and different return types---for a `forecast(for:at:)` method:

```swift
public func forecast(for days: DateInterval, at location: Location) -> HourByHourForecast     { /* ... */ }
public func forecast(for day:  Date,         at location: Location) -> MinuteByMinuteForecast { /* ... */ }
public func forecast(for day:  Date,         at location: Location) -> HourByHourForecast     { /* ... */ }
```

The first overload is the only one with where the first parameter has a `DateInterval` type. 
The second parameter type isn't necessary to disambiguate the overload, and is the same in all three overloads, 
so DocC suggests to add `(DateInterval,_)` to disambiguate the it.

The second overload is the only one with where the return value has a `MinuteByMinuteForecast` type, 
so DocC suggests to add `‑>MinuteByMinuteForecast` to disambiguate the it.

The third overload has the same parameter types as the second overload and the same return value as the first overload, 
so DocC neither parameter types or return types alone can uniquely disambiguate this overload.
In this scenario, DocC considers a combination of parameter types and return types to disambiguate the overload.
The first parameter type is different from the first overload and the return type is different from the second overload.
Together this information uniquely disambiguates the third overload, 
so DocC suggests to add `(Date,_)‑>HourByHourForecast` to disambiguate the it.

You can discover the minimal combination of parameter types and return types for each overload from DocC's warnings about ambiguous symbol links.

The following example shows a topic group with disambiguated symbol links to the three `forecast(for:at:)` methods from before:

```markdown
### Requesting weather forecasts

- ``forecast(for:at:)-(DateInterval,_)``
- ``forecast(for:at:)->MinuteByMinuteForecast``
- ``forecast(for:at:)->(Date,_)->HourByHourForecast``
```

> Earlier Versions:
> Before Swift-DocC 6.1, disambiguation using parameter types or return types isn't supported.

If DocC can't disambiguate the symbol link using either a symbol type suffix or a combination parameter type names and return type names, 
it will fall back to using a short hash of each symbol's unique identifier to disambiguate the symbol link. 
You can discover these hashes from DocC's warnings about ambiguous symbol links.
The following example shows the same topic group with symbol links to the three `forecast(for:at:)` methods as before, 
but using each symbols unique identifier hash for disambiguation:

```markdown
### Requesting weather forecasts

- ``forecast(for:at:)-3brnk``
- ``forecast(for:at:)-4gcpg``
- ``forecast(for:at:)-7f3u``
```

### Navigate to an Article

To add a link to an article, use the less-than symbol (`<`), the `doc` keyword, 
a colon (`:`), the article's file name without file extension, and a greater-than symbol 
(`>`).  

```markdown
<doc:GettingStarted>
```

If the article's file name contains whitespace characters, replace each consecutive sequence of whitespace characters with a dash. 
For example, the link to an article with a file name "Getting Started.md" is

```
<doc:Getting-Started>
```

When DocC resolves the link, it uses the article's page title as the link's 
text. Links to tutorials follow the same format. 

```markdown
<doc:SlothCreator>
```

If you have an article file and a tutorial file with the same base name, DocC will resolve the `<doc:BaseName>` link to the article. To refer to the tutorial instead you can add a leading `tutorials` component to the path, with or without a leading slash: 

```markdown
<doc:tutorials/BaseName>
<doc:/tutorials/BaseName>
```

> Tip: You can also link to symbols using the `<doc:>` syntax. Just insert the 
symbol's path between the colon (`:`) and the terminating greater-than 
symbol (`>`).
`<doc:Sloth/init(name:color:power:)>`

### Navigate to a Heading or Task Group

To add a link to heading or task group on another page, use a `<doc:>` link to the page and end the link with a hash (`#`) followed by the name of the heading. 
If the heading text contains whitespace or punctuation characters, replace each consecutive sequence of whitespace characters with a dash and optionally remove the punctuation characters. 

For example, consider this level 3 heading with a handful of punctuation characters:

```
### (1) "Example": Sloth's diet.
```

A link to this heading can either include all the punctuation characters from the heading text or remove some or all of the punctuation characters.

```
<doc:OtherPage#(1)-"Example":-Sloth's-diet.>
<doc:OtherPage#1-Example-Sloths-diet>
```

> Note:
> Links to headings or task groups on symbol pages use `<doc:>` syntax. 

To add a link to heading or task group on the current page, use a `<doc:>` link that starts with the name of the heading. If you prefer you can include the hash (`#`) prefix before the heading name. For example, both these links resolve to a heading named "Some heading title" on the current page:

```
<doc:#Some-heading-title>
<doc:Some-heading-title>
```

If a task group is empty or none of its links resolve successfully, it's not possible to link to that task group because it will be omitted from the rendered page. Linking to generated per-symbol-kind task groups is not supported.

> Earlier Versions:
> Before Swift-DocC 6.0, links to task groups isn't supported. The syntax above only works for links to general headings.
>
> Before Swift-DocC 5.9, links to same-page headings don't support a leading hash (`#`) character.

### Include web links

To include a regular web link, add a set of brackets (`[]`) and 
a set of parentheses (`()`). Then add the link's text between the brackets, and 
add the link's URL within the parentheses. 

```markdown
[Apple](https://www.apple.com)
```

<!-- Copyright (c) 2023-2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->
