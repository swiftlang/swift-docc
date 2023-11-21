# Linking to Symbols and Other Content

Facilitate navigation between pages using links.

## Overview

DocC supports the following link types to enable navigation between pages:

| Type | Usage |
| --- | --- |
| Symbol | Links to a symbol's reference page in your documentation. |
| Article | Links to an article or API collection in your documentation catalog. |
| Tutorial | Links to a tutorial in your documentation catalog. |
| Web | Links to an external URL. |

### Navigate to a Symbol

To add a link to a symbol, wrap the symbol's name in a set of double backticks 
(\`\`).

```markdown
``SlothCreator``
```

For nested symbols, include the path to the symbol in the link.

```markdown
``SlothCreator/Sloth/eat(_:quantity:)``
```

DocC resolves symbol links relative to the context they appear in. For example, 
a symbol link that appears inline in the `Sloth` class, and targets a 
symbol in that class, can omit the `SlothCreator/Sloth/` portion of the symbol 
path.

In some cases, a symbol's path isn't unique, such as with overloaded methods in 
Swift. For example, consider the `Sloth` structure, which has multiple 
`update(_:)` methods:

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
In this scenario, and to ensure uniqueness, DocC uses the symbol's unique 
identifier instead of its name to disambiguate. DocC's warnings about ambiguous
symbol links suggests one disambiguation for each of the symbols that match the
ambiguous symbol path.

```markdown
### Updating Sloths
- ``Sloth/update(_:)-4ko57``
- ``Sloth/update(_:)-jixx``
```

In the example above, both symbols are functions, so you need the unique 
identifiers to disambiguate the `Sloth/update(_:)` link. 

Unique identifiers aren't the only way to disambiguate symbol links. If a symbol
has a different type from the other symbols with the same symbol path, you can 
use that symbol's type suffix to disambiguate the link and make the link refer 
to that symbol. For example, consider a `Color` structure with `red`, `green`, 
and `blue` properties for color components and static properties for a handful 
of predefined color values:

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

Both the `red` property and the `red` static property have a symbol path of 
`Color/red`. Because these are different types of symbols you can disambiguate 
`Color/red` with symbol type suffixes instead of the symbols' unique identifiers.

The following example shows a symbol link to the `red` property:

```markdown
``Color/red-property``
```

The following example shows a symbol link to the `red` static property:

```markdown
``Color/red-type.property``
```

DocC supports the following symbol types for use in symbol links:

| Symbol type       | Suffix            |
|-------------------|-------------------|
| Enumeration       | `-enum`           |
| Enumeration case  | `-enum.case`      |
| Protocol          | `-protocol`       |
| Operator          | `-func.op`        |
| Typealias         | `-typealias`      |
| Function          | `-func`           |
| Structure         | `-struct`         |
| Class             | `-class`          |
| Type property     | `-type.property`  |
| Type method       | `-type.method`    |
| Type subscript    | `-type.subscript` |
| Property          | `-property`       |
| Initializer       | `-init`           |
| Deinitializer     | `-deinit`         |
| Method            | `-method`         |
| Subscript         | `-subscript`      |
| Instance variable | `-ivar`           |
| Macro             | `-macro`          |
| Module            | `-module`         |

Symbol type suffixes can include a source language identifier prefix — for 
example,  `-swift.enum` instead of `-enum`. However, the language 
identifier doesn't disambiguate the link.

Symbol paths are case-sensitive, meaning that symbols with the same name in
different text casing don't need disambiguation. 

Symbols that have representations in both Swift and Objective-C can use
symbol paths in either source language. For example, consider a `Sloth` 
class with `@objc` attributes:

```swift
@objc public class Sloth: NSObject {
    @objc public init(name: String, color: Color, power: Power) {
        self.name = name
        self.color = color
        self.power = power
    }
}
```

A symbol link to the Sloth initializer can be written using the symbol 
path in either source language.

**Swift name**

```markdown
``Sloth/init(name:color:power:)``
```

**Objective-C name**

```markdown
``Sloth/initWithName:color:power:``
```

### Navigate to an Article

To add a link to an article, use the less-than symbol (`<`), the `doc` keyword, 
a colon (`:`), the name of the article, and a greater-than symbol 
(`>`). Don't include the article's file extension in the name. 

```
<doc:GettingStarted>
```

When DocC resolves the link, it uses the article's page title as the link's 
text, and the article's filename as the link's URL. Links to tutorials follow 
the same format, except you must add the `/tutorials/` prefix to the path: 

```
<doc:/tutorials/SlothCreator>
```

> Tip: You can also link to symbols using the `<doc:>` syntax. Just insert the 
symbol's path between the colon (`:`) and the terminating greater-than 
symbol (`>`).
`<doc:Sloth/init(name:color:power:)>`

### Include web links

To include a regular web link, add a set of brackets (`[]`) and 
a set of parentheses (`()`). Then add the link's text between the brackets, and 
add the link's URL within the parentheses. 

```markdown
[Apple](https://www.apple.com)
```

<!-- Copyright (c) 2023 Apple Inc and the Swift Project authors. All Rights Reserved. -->
