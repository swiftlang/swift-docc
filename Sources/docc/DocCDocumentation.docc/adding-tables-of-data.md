# Adding Tables of Data

Arrange information into rows and columns.

## Overview

To add a table to your documentation, start a new paragraph and add the following required elements, each on its own line:

* A table header, with the heading text of each column, separated by pipes (`|`)
* A separator row, with at least 3 hyphens (`-`) for each column, separated by pipes
* One or more rows of table cells, separating each cell of formatted content by a pipe
 
```md
Sloth speed  | Description                          
------------ | ------------------------------------- 
`slow`       | Moves slightly faster than a snail  
`medium`     | Moves at an average speed           
`fast`       | Moves faster than a hare            
`supersonic` | Moves faster than the speed of sound
```

The example markup above defines the table that's shown below. Each column is only as wide as its widest cell and the table is only as wide as the sum of its columns.

Sloth speed  | Description                          
------------ | ------------------------------------- 
`slow`       | Moves slightly faster than a snail  
`medium`     | Moves at an average speed           
`fast`       | Moves faster than a hare            
`supersonic` | Moves faster than the speed of sound

You don't need to pad the cells to align the column separators (`|`). However, it might make your table _markup_ easier to read, especially for large or complex tables. 

You can also define the same table with the markup that's shown below. All other examples will use padded cells for readability.

```md
Sloth speed|Description
---|---
`slow`|Moves slightly faster than a snail
`medium`|Moves at an average speed
`fast`|Moves faster than a hare
`supersonic`|Moves faster than the speed of sound
```

You can add leading and/or trailing pipes (`|`) if you find that table markup easier to read. This doesn't affect the rendered table on the page. The leading and trailing pipes _can_ be applied inconsistently for each row, but doing so may make it harder to discern the structure of the table. 

```md
| Sloth speed  | Description                          |                         
| ------------ | ------------------------------------ |
| `slow`       | Moves slightly faster than a snail   | 
| `medium`     | Moves at an average speed            |  
| `fast`       | Moves faster than a hare             |
| `supersonic` | Moves faster than the speed of sound |
```

The content of a table cell supports the same style attributes as other text and supports links to other content, including symbols. If a table cell's content includes a pipe (`|`) you need to escape the pipe character by preceding it with a backslash 
(`\`). For more information about styling text, see [Format Text in Bold, Italics, and Code Voice](doc:formatting-your-documentation-content#Format-Text-in-Bold,-Italics,-and-Code-Voice).

> Note: A table cell can only contain a single line of formatted content. Lists, asides, code blocks, headings, and directives are not supported inside a table cell. 

### Aligning content in a column

By default, all table columns align their content to the leading edge. To change the horizontal alignment for a column, modify the table's separator row to add a colon (`:`) around the hyphens (`-`) for that column, either before the hyphens for leading alignment, before _and_ after the hyphens for center alignment, or after the hyphens for trailing alignment.

Leading  | Center   | Trailing 
:------- | :------: | --------:
`:-----` | `:----:` | `-----:` 
![Four different rectangular blocks with their left edges aligned](table-align-leading) | ![Four different rectangular blocks with their centers horizontally aligned](table-align-center) | ![Four different rectangular blocks with their right edges aligned](table-align-trailing) 

### Spanning cells across columns

By default, each table cell is one column wide and one row tall. To span a table cell across multiple columns, place two or more column separators (`|`) next to each other after the cell's content. If the spanning cell is the last or only element of a row, you need to add the extra trailing pipe (`|`) for that row, otherwise DocC interprets the row as having an additional empty cell at the end. For example:

@Row {
  @Column {
    ```md
    First | Second | Third |
    ----- | ------ | ----- |
    One           || Two   |
    Three | Four          ||
    Five                 |||
    ```  
  }
  @Column {
    First | Second | Third |
    ----- | ------ | ----- |
    One           || Two   |
    Three | Four          ||
    Five                 |||
  }
}

> Tip: You might find it easier to discern the structure of your table from its markup if you use trailing pipes consistently when spanning cells.  

A spanning cell determines its horizontal alignment from the left-most column that it spans. Going from left to right in the example below:

 - Cells "One" and "Five" use leading alignment because they both span the first column
 - Cell "Four" uses center alignment because it spans the second column
 - Cell "Two" uses trailing alignment because it spans the third column

@Row {
  @Column {
    ```md
    Leading | Center | Trailing |
    :------ | :----: | -------: |
    One             || Two      |
    Three   | Four             ||
    Five                      |||
    ```  
  }
  @Column {
    Leading | Center | Trailing |
    :------ | :----: | -------: |
    One             || Two      |
    Three   | Four             ||
    Five                      |||
  }
}

### Spanning cells across rows

To span a table cell across multiple rows, write the cell's content in the first row and a single caret (`^`) in one or more cells below it. For example:

@Row {
  @Column {
    ```md
    First | Second | Third | Fourth 
    ----- | ------ | ----- | ------
    One   | Two    | Three | Four
    ^     | Five   | ^     | Six
    Seven | ^      | ^     | Eight
    ```
  }
  @Column {
    First | Second | Third | Fourth 
    ----- | ------ | ----- | ------
    One   | Two    | Three | Four
    ^     | Five   | ^     | Six
    Seven | ^      | ^     | Eight
  }
}

A table cell can span both columns and rows by combining the syntax for both. For example:

@Row {
  @Column {
    ```md
    First | Second | Third 
    ----- | ------ | ----- 
    One           || Two   
    ^             || Three 
    ```  
  }
  @Column {
    First | Second | Third 
    ----- | ------ | ----- 
    One           || Two   
    ^             || Three 
  }
}

<!-- Copyright (c) 2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->
