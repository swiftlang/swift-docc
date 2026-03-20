# Other Formatting Options

Improve the presentation and structure of your content by incorporating special page elements.

## Overview

DocC offers support for various types of elements such as [tables](doc:adding-tables-of-data), notes, and asides.

### Add Notes and Other Asides

There may be circumstances when you want to get the reader's attention to 
provide additional advice, or to warn them about common errors or requisite 
configuration. For those situations, use an aside. 

DocC supports the following types of asides:

> Note: General information that applies to some users.

> Important: Important information, such as a requirement.

> Warning: Critical information, like potential data loss or an irrecoverable state.

> Tip: Helpful information, such as shortcuts, suggestions, or hints.

> Experiment: Instructional information to reinforce a learning objective, or to encourage developers to try out different parts of your framework.

DocC supports two syntax alternatives for asides; one using Markdown's list syntax and the other using Markdown's block quote syntax.

For short single-line asides, these syntax alternatives differ only by their first character
---either a hyphen (`-`), asterisk (`*`), or plus sign (`+`) for the list syntax or a greater-than sign (`>`) for the quote syntax---
followed by a space, the type of aside (case insensitive), a colon, and the formatted content of the aside.
These examples below are all equivalent:

```md
- Note: Some information 
* Note: Some information 
+ Note: Some information 
> Note: Some information 
```

The text of an aside can use the same style attributes as other text, and include links to other content, including symbols. 

> Tip: DocC automatically capitalizes the first word of the aside's content unless that word already includes a capitalized letter. 

If you want to include more than one paragraph of content in the aside---or include lists, code blocks, or images---then the two syntax alternatives differ in how they extend to cover those paragraphs, lists, code blocks, or images: 

- For the list item syntax (with a `-`, `*`, or `+` prefix), you need to indent additional paragraphs, and other types of content, as far as the start of the containing list item so that the first character of that content lines up with the first letter of the type of aside.
- For the block quote syntax (with a `-`, `*`, or `+` prefix), you need to start each line---*including* blank lines between paragraphs, and other types of content---with a greater-than sign (`>`).

If you prefer, both these multi-element syntaxes can sometimes be more clear when the first paragraph, after the type of tag and colon, is also on a new line:

@TabNavigator {
    @Tab("First paragraph on the same line as the tag") {
        @Row {
            @Column {
                ```
                - Note: The first paragraph.
                 
                  The second paragraph.
                ```
            }
            @Column {
                ```
                > Note: The first paragraph.
                >                
                > The second paragraph.
                ```
            }
        }
    }
    @Tab("First paragraph on a new line") {
        @Row {
            @Column {
                ```
                - Note: 
                  The first paragraph.
                 
                  The second paragraph.
                ```
            }
            @Column {
                ```
                > Note: 
                > The first paragraph.
                >                
                > The second paragraph.
                ```
            }
        }
    }
}

> Tip: 
> If you have much information to provide about a subtopic, consider using a subsection rather than a multi-paragraph aside. 
> This can help with the flow of the text and make the information appear less visually heavy on the page.

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

DocC also supports the translation of hex codes and HTML entities. For example, using the hex code `\&#xa9;`
will render as the copyright sign (&#xa9;).

<!-- Copyright (c) 2023-2025 Apple Inc and the Swift Project authors. All Rights Reserved. -->
