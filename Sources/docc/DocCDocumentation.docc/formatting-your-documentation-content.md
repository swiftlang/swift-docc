# Formatting Your Documentation Content

Enhance your content's presentation with special formatting and styling for text, links, and other page elements.

## Overview

Use [Markdown](https://daringfireball.net/projects/markdown/syntax), a 
lightweight markup language, to give structure and style to your documentation. 
DocC includes a custom dialect of Markdown, documentation markup, which 
extends Markdown's syntax to include features like symbol linking, improved 
image support, term lists, and asides.

To ensure consistent structure and styling, use DocC's documentation markup for 
all of the documentation you write.

### Add a Page Title and Section Headers

To add a page title, precede the text you want to use with a hash (`#`) and a 
space. For the page title of an article or API collection, use plain text only.

```markdown
# Getting Started with Sloths
```

> Important: Page titles must be the first line of content in a documentation 
file. One or more empty lines can precede the page title.

For the page title of a framework landing page or extension file, use a _symbol 
link_. To create a symbol link, wrap the framework's name, or the symbol's name 
(including its hierarchy within the framework, when necessary), within a set of 
double backticks (\`\`).

```markdown
# ``SlothCreator``
# ``SlothCreator/CareSchedule/Event``
```

Augment every page title with a short and concise single-sentence abstract or 
summary that provides additional information about the content. Add the summary 
using a new paragraph directly below the page title.

```markdown
# Getting Started with Sloths

Create a sloth and assign personality traits and abilities.
```  

To add a header for an Overview or a Discussion section, use a double hash 
(`##`) and a space, and then include either term in plain text.

```markdown
## Overview
```

For all other section headers, use a triple hash (`###`) and a space, and then 
add the title of the header in plain text.

```markdown
### Create a Sloth
```

Use this type of section header in framework landing pages, top-level pages, 
articles, and occasionally in symbol reference pages where you need to 
provide more detail.

### Format Text in Bold, Italics, and Code Voice

DocC provides three ways to format the text in your documentation. You can 
apply bold or italic styling, or you can use code voice, which renders the 
specified text in a monospace font.

To add bold styling, wrap the text in a pair of double asterisks (`**`) or you can wrap it in a pair of double underscores (`__`) .
Alternatively, use double underscores (`__`).

The following example uses bold styling for the names of the sloths:

```markdown
**Super Sloth**: Likes to eat sticks.
__Silly Sloth__: Prefers twigs for breakfast.
```

Use italicized text to introduce new or alternative terms to the reader. To add 
italic styling, wrap the text in a set of single underscores (`_`) or single 
asterisks (`*`).

The following example uses italics for the words _metabolism_ and _habitat_: 

```markdown
A sloth's _metabolism_ is highly dependent on its *habitat*.
```

Use code voice to refer to symbols inline, or to include short code fragments, 
such as class names or method signatures.  To add code voice, wrap the text in 
a set of backticks (\`).

In the following example, DocC renders the words _ice_, _fire_, _wind_, and 
_lightning_ in a monospace font:

```markdown
If your sloth possesses one of the special powers: `ice`, `fire`, 
`wind`, or `lightning`.
```

> Note: To include multiple lines of code, use a code listing instead. For more 
information, see <doc:formatting-your-documentation-content#Add-Code-Listings>.

When referencing symbols that appear within your Swift framework or 
package, use symbol links. To create a symbol link, wrap the symbol 
name in a set of double backticks (\`\`).

In the following example, DocC renders the referenced methods in a monospace 
font and wraps them in links to the corresponding documentation pages:

```markdown
You can increase the sloth's energy level by asking them to 
``eat(_:quantity:)`` or ``sleep(in:for:)``.
```

For more information, see  
<doc:formatting-your-documentation-content#Link-to-Symbols-and-Other-Content>.

### Add Code Listings

DocC includes support for code listings, or fenced code blocks, which allow you 
to go beyond the basic declaration sections you find in symbol reference pages, 
and to provide more complete code examples for adopters of your framework. You can 
include code listings in your in-source symbol documentation, in extension 
files, and in articles and tutorials.

To create a code listing, start a new paragraph and add three backticks 
(\`\`\`). Then, directly following the backticks, add the name of the 
programming language in lowercase text. Add one or more lines of code, and then 
add a new line and terminate the code listing by adding another three backticks:

    ```swift
    struct Sightseeing: Activity {
        func perform(with sloth: inout Sloth) -> Speed {
            sloth.energyLevel -= 10
            return .slow
        }
    }
    ```

> Important: When formatting your code listing, use spaces to indent lines 
instead of tabs so that DocC preserves the indentation when compiling your 
documentation.

DocC uses the programming language you specify to apply the correct syntax 
color formatting. For the example above, DocC generates the following:

```swift
struct Sightseeing: Activity {
    func perform(with sloth: inout Sloth) -> Speed {
        sloth.energyLevel -= 10
        return .slow
    }
}
 ```

 The following table lists the names of programming languages that can be used
 to specify the syntax highlighting for a given code listing. Each one may have
 aliases that can also be used to specify the same language.

| Name       | Aliases                                                |
| ---------- | ------------------------------------------------------ |
| bash       | sh, zsh                                                |
| c          | h                                                      |
| cpp        | cc, c++, h++, hpp, hh, hxx, cxx                        |
| css        |                                                        |
| diff       | patch                                                  |
| http       | https                                                  |
| java       | jsp                                                    |
| javascript | js, jsx, mjs, cjs                                      |
| json       |                                                        |
| llvm       |                                                        |
| markdown   | md, mkdown, mkd                                        |
| objectivec | mm, objc, obj-c                                        |
| perl       | pl, pm                                                 |
| php        |                                                        |
| python     | py, gyp, ipython                                       |
| ruby       | rb, gemspec, podspec, thor, irb                        |
| scss       |                                                        |
| shell      | console, shellsession                                  |
| swift      |                                                        |
| xml        | html, xhtml, rss, atom, xjb, xsd, xsl, plist, wsf, svg |

### Link to Symbols and Other Content

DocC supports the following link types to enable navigation between pages:

| Type | Usage |
| --- | --- |
| Symbol | Links to a symbol's reference page in your documentation. |
| Article | Links to an article or API collection in your documentation catalog. |
| Tutorial | Links to a tutorial in your documentation catalog. |
| Web | Links to an external URL. |

To add a link to a symbol, wrap the symbol's name in a set of double backticks 
(\`\`).

```markdown
``SlothCreator``
```

For nested symbols, include the entire path to the symbol in the link.

```markdown
``SlothCreator/Sloth/eat(_:quantity:)``
```

DocC resolves symbol links relative to the context they appear in. For example, 
a symbol link that appears inline in the `Sloth` class, and targets a 
symbol in that class, can omit the `SlothCreator/Sloth/` portion of the symbol 
path.

In some cases, a symbol's path isn’t unique, such as with overloaded methods in 
Swift. For example, consider the `Sloth` structure, which has multiple 
`update(_:)` methods.

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
identifier instead of its name to disambiguate.

```markdown
### Updating Sloths
- ``Sloth/update(_:)-4ko57``
- ``Sloth/update(_:)-jixx``
```

In the example above, both symbol paths are identical, regardless of text case. 
However, another scenario where you need to provide more context to DocC about 
the symbol you're linking is when the case-insensitive nature of symbol paths 
comes into play. For example, consider the `Sloth` structure, which has a nested 
`Color` enumeration and a `color` property.

```swift
public struct Sloth {
    public enum Color { }
    
    public var color: Color
}
```

Because symbol paths are case-insensitive, both symbols resolve to the same path. 
To address this issue, add the suffix for the target's type to the linked symbol path .

```markdown
``Sloth/Color.swift-enum``
```

DocC supports the following symbol types for use in symbol links:

| Symbol type | Suffix |
| ----------- | ------ |
| Enumeration | `-swift.enum` |
| Enumeration case | `-swift.enum.case` |
| Protocol | `-swift.protocol` |
| Operator | `-swift.func.op` |
| Typealias | `-swift.typealias` |
| Function | `-swift.func` |
| Structure | `-swift.struct` |
| Class | `-swift.class` |
| Type property | `-swift.type.property` |
| Type method | `-swift.type.method` |
| Type subscript | `-swift.type.subscript` |
| Property | `-swift.property` |
| Initializer | `-swift.init` |
| Deinitializer | `-swift.deinit` |
| Method | `-swift.method` |
| Subscript | `-swift.subscript` |


To add a link to an article, use the less-than symbol (`<`), the `doc` keyword, 
a colon (`:`), the name of the article, and a greater-than symbol 
(`>`). Don't include the article's file extension in the name. 

```
<doc:GettingStarted>
```

When DocC resolves the link, it uses the article's page title as the link's 
text, and the article's filename as the link's URL. Links to tutorials follow 
the same format, except you must add the `/tutorials/` prefix to the path. 

```
<doc:/tutorials/SlothCreator>
```

> Tip: You can also link to symbols using the `<doc:>` syntax. Just insert the 
symbol's path between the colon (`:`) and the terminating greater-than 
symbol (`>`).

To include a regular web link, add a set of square brackets (`[]`) and 
a set of parentheses (`()`). Then add the link's text between the square brackets, and 
add the link's URL destination within the parentheses. 

```markdown
[Apple](https://www.apple.com)
```

### Add Images to Your Content

DocC extends Markdown's image support so you can provide appearance and 
display scale-aware versions of an image. You use specific components to create image filenames, and DocC  uses the most appropriate version of the image when displaying your documentation.

![An image of a filename that's split into four labeled sections to highlight the individual components. From left to right, the components are the image name, the apperance mode, the display scale, and the file extension.](docc-image-filename)

| Component | Description |
| --- | --- |
| Image name | **Required**. Identifies the image within the documentation catalog. The name must be unique across all images in the catalog, even if you store them in separate folders. |
| Appearance | **Optional**. Identifies the appearance mode in which DocC uses the image. Add `~dark` directly after the image name to identify the image as a dark appearance mode variant. |
| Display scale | **Optional**. Identifies the display scale at which DocC uses the image. Possible values are `@1x`, `@2x`, and `@3x`. When specifying a display scale, add it directly before the file extension. |
| File extension | **Required**. Identifies the type of image, such as .png or .jpeg. |

For example, the following are all valid DocC image filenames:

- term `sloth.png`: An image that's independent of all appearance modes and display scales.
- term `sloth~dark.png`: An image that's specific to a dark appearance mode, but is display-scale independent.
- term `sloth~dark@2x.png`: An image that's specific to a dark appearance mode and the 2x display scale.

> Important: You must store images you include in your documentation in a 
documentation catalog. For more information, see <doc:documenting-a-swift-framework-or-package>.

To add an image, use an exclamation mark (`!`), a set of square brackets 
(`[]`), and a set of parentheses (`()`).

Add a description of what the image shows between the square brackets. Screen 
readers read this text aloud. Provide enough detail to 
allow people with impaired vision to understand what the image shows. 

Within the parentheses, include only the image name. Omit the appearance, 
display scale, and file extension components. Don't include the path to the 
image, even if you store the image in a folder in the documentation catalog.

```markdown
![A photograph of a sloth hanging off a tree.](sloth)
```

### Add Bulleted, Numbered, and Term Lists

DocC supports the following list types:

| Type | Usage |
| --------- | ----------- |
| Bulleted list | Groups items that can appear in any order. |
| Numbered list | Delineates a sequence of events in a particular order. |
| Term list | Defines a series of term-definition pairs. | 

> Important: Don't add images or code listings between list items. Bulleted and 
numbered lists must contain two or more items.

To create a bulleted list, precede each of the list's items with an asterisk (`*`) and a 
space. Alternatively, use a dash (`-`) or a plus sign (`+`) instead of an asterisk (`*`); the list markers are interchangeable.

```markdown
* Ice
- Fire
* Wind
+ Lightning
```

To create a numbered list, precede each of the list's items with the number of the step, then a period (`.`) and a space. 

```markdown
1. Give the sloth some food.
2. Take the sloth for a walk.
3. Read the sloth a story.
4. Put the sloth to bed.
```

To create a term list, precede each term with a dash (`-`) and a 
space, the `term` keyword, and another space. Then add a colon (`:`), a space, and the definition after the term. 

```markdown
- term Ice: Ice sloths thrive below freezing temperatures.
- term Fire: Fire sloths thrive at boiling temperatures.
- term Wind: Wind sloths thrive at soaring altitudes.
- term Lightning: Lightning sloths thrive in stormy climates.
```

A list item's text, including terms and their definitions, can use the same 
style attributes as other text, and include links to other content, including 
symbols.

### Add Tables of Data

DocC includes support for tables, which you can use to organize information.

To create a table, start a new paragraph and use dashes (`-`) to define 
columns, and pipes (`|`) as column separators. Construction of a table requires 
at least three rows: 

* A row that contains the column names.
* A row with cells that contain only dashes (`-`); three or more for each 
column.
* One or more rows of content.

```markdown
| Sloth speed  | Description                           |
| ------------ | ------------------------------------- | 
| `slow`       | Moves slightly faster than a snail.   |
| `medium`     | Moves at an average speed.            |
| `fast`       | Moves faster than a hare.             |
| `supersonic` | Moves faster than the speed of sound. |
```
There's no need to impose a column width. A column determines its width 
using the contents of its widest cell. You can also omit the leading 
and trailing pipes.

```markdown
Sloth speed | Description
--- | ---
`slow` | Moves slightly faster than a snail.
`medium` | Moves at an average speed.
`fast` | Moves faster than a hare.
`supersonic` | Moves faster than the speed of sound.
```

Both examples result in the same output:

| Sloth speed | Description |
| ---: | :--- |
| `slow` | Moves slightly faster than a snail. |
| `medium` | Moves at an average speed. |
| `fast` | Moves faster than a hare. |
| `supersonic` | Moves faster than the speed of sound. |

> Note: Table cells don't support multiple paragraphs, lists, or code 
listings.

The text of a table cell can use the same style attributes as other text, and 
include links to other content, including symbols. 

### Add Notes and Other Asides

There may be circumstances when you want to get the reader's attention to 
provide additional advice, or to warn them about common errors or requisite 
configuration. For those situations, use an aside. 

DocC supports the following types of asides:

| Type | Usage |
| ----- | ------ |
| Note | General information that applies to some users. |
| Important | Important information, such as a requirement. |
| Warning | Critical information, like potential data loss or an irrecoverable state. |
| Tip | Helpful information, such as shortcuts, suggestions, or hints. |
| Experiment | Instructional information to reinforce a learning objective, or to encourage developers to try out different parts of your framework. |

To create an aside, begin a new line with a greater-than symbol (`>`), add a space, 
the type of the aside, a colon (`:`), and the content of the aside.

```markdown
> Tip: Sloths require sustenance to perform activities.
```

For the example above, DocC renders the following aside:

> Tip: Sloths require sustenance to perform activities.

The text of an aside can use the same style attributes as other text, and 
include links to other content, including symbols.

### Include Special Characters in Text

To escape one or more special characters, precede each with a backslash 
(`\`). 

For example, to display an asterisk (`*`) at the beginning of a line and prevent 
DocC from converting it into a bulleted list item, place a backslash immediately before it.

```
\* Not a bulleted list item.
```

If you use single (`*`) or double (`**`) asterisks to apply italic or bold 
styling, respectively, you can escape any asterisks that the text contains so 
DocC doesn't prematurely terminate the styling. 

```
*Sloths require sustenance\* to perform activities.*

**Sloths require sustenance\*\* to perform activities.**
```

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
