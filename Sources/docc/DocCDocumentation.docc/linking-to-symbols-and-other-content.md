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
@objc(TLASloth) public class Sloth: NSObject {
    @objc public init(name: String, color: Color, power: Power) {
        self.name = name
        self.color = color
        self.power = power
    }
}
```

You can write a symbol link to the Sloth initializer using the symbol path in either source language.

**Swift name**

```markdown
``Sloth/init(name:color:power:)``
```

**Objective-C name**

```markdown
``TLASloth/initWithName:color:power:``
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

```markdown
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

```markdown
### (1) "Example": Sloth's diet.
```

A link to this heading can either include all the punctuation characters from the heading text or remove some or all of the punctuation characters.

```markdown
<doc:OtherPage#(1)-"Example":-Sloth's-diet.>
<doc:OtherPage#1-Example-Sloths-diet>
```

> Note:
> Links to headings or task groups on symbol pages use `<doc:>` syntax. 

To add a link to heading or task group on the current page, use a `<doc:>` link that starts with the name of the heading. If you prefer you can include the hash (`#`) prefix before the heading name. For example, both these links resolve to a heading named "Some heading title" on the current page:

```markdown
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
