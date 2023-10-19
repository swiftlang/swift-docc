# Other Formatting Options

Improve the presentation and structure of your content by incorporating special page elements.

## Overview

DocC offers support for various types of elements such as tables, notes, asides, and special characters.

### Add Tables of Data

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

<!-- Copyright (c) 2023 Apple Inc and the Swift Project authors. All Rights Reserved. -->
