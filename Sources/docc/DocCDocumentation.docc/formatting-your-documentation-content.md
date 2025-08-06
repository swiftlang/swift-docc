# Formatting Your Documentation Content

Enhance your content's presentation with special formatting and styling for text and lists.

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

For the page title of a landing page, enter a symbol link by wrapping the framework's 
module name within a set of double backticks (\`\`).

```markdown
# ``SlothCreator``
```

For a documentation extension file, enter a symbol link by wrapping the path to the symbol 
within double backticks (\`\`). The path may start with the framework's module name
or with the name of a top-level symbol in the module.

The following example shows a documentation extension link starting with a framework module name:

```markdown
# ``SlothCreator/CareSchedule/Event``
```

The following example shows a documentation extension link to the same symbol starting with a top-level symbol name:

```markdown
# ``CareSchedule/Event``
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

To add bold styling, wrap the text in a pair of double asterisks (`**`). 
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

#### Formatting Code Listings

You can add a copy-to-clipboard button to a code listing by including the copy
option after the name of the programming language for the code listing:

```swift, copy
struct Sightseeing: Activity {
    func perform(with sloth: inout Sloth) -> Speed {
        sloth.energyLevel -= 10
        return .slow
    }
}
```

This renders a copy button in the top-right cotner of the code listing in
generated documentation. When clicked, it copies the contents of the code
block to the clipboard.

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

The following table lists the names of the programming languages you can specify
to enable syntax highlighting for a particular code listing. Each language may
have one or more aliases.

| Name        | Aliases                                                |
| ----------  | ------------------------------------------------------ |
| bash        | sh, zsh                                                |
| c           | h                                                      |
| cpp         | cc, c++, h++, hpp, hh, hxx, cxx                        |
| css         |                                                        |
| diff        | patch                                                  |
| http        | https                                                  |
| java        | jsp                                                    |
| javascript  | js, jsx, mjs, cjs                                      |
| json        |                                                        |
| llvm        |                                                        |
| markdown    | md, mkdown, mkd                                        |
| objective-c | mm, objc, obj-c, objectivec                            |
| perl        | pl, pm                                                 |
| php         |                                                        |
| python      | py, gyp, ipython                                       |
| ruby        | rb, gemspec, podspec, thor, irb                        |
| scss        |                                                        |
| shell       | console, shellsession                                  |
| swift       |                                                        |
| xml         | html, xhtml, rss, atom, xjb, xsd, xsl, plist, wsf, svg |
| yaml        | yml                                                    |

### Add Bulleted, Numbered, and Term Lists

DocC supports the following list types:

| Type          | Usage                                                  |
| ------------- | ------------------------------------------------------ |
| Bulleted list | Groups items that can appear in any order.             |
| Numbered list | Delineates a sequence of events in a particular order. |
| Term list     | Defines a series of term-definition pairs.             | 

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

<!-- Copyright (c) 2021-2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->
