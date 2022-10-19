# Adding Structure to Your Documentation Pages

Arrange symbols into groups and collections that make them easy to find.

## Overview

By default, when DocC generates documentation for a project, it creates a 
top-level page that lists all public symbols, and groups them by their 
kind. You can then provide additional context to 
explain how your framework works and how different symbols relate to each 
other. For a more tailored learning experience, use one or more of the 
following approaches:

* Customize the main landing page for your documentation catalog to introduce 
your framework and organize its top-level symbols.
* Add symbol-specific extension files that organize nested symbols, such as 
methods and properties.
* Use collections to group multiple symbols and introduce hierarchy to 
the navigation of your documentation pages.

For more information, see
 <doc:writing-symbol-documentation-in-your-source-files>.

### Customize Your Documentation's Landing Page

A landing page provides an overview of your framework, introduces important 
terms, and organizes the resources within your documentation catalog to ease 
the reader's learning path. It's an opportunity for you to discuss key features 
of your framework and offer motivation for when the reader might want to use 
it.

For projects that don't include a documentation catalog, DocC generates a 
basic landing page that provides an entry point to your framework's symbol 
documentation. However, by adding a documentation catalog, you can include a 
custom landing page that provides a rich and engaging experience for adopters 
of your framework. 

![A screenshot showing a customized landing page that includes rendered DocC content and a color graphic.](2_docs)

If you need to manually add a landing page to your documentation catalog, use your text editor to create a file to match the name of the framework. For example, for the 
`SlothCreator` framework, the filename is `SlothCreator.md`.

The first line of content in a landing page is the name of the framework, which 
you precede with a single hash (`#`) and encapsulate in a set of double backticks (\`\`).

```markdown
# ``SlothCreator``
```

> Important: The name you use must match the compiled framework's product name.

Follow the page title with a blank line to create a new paragraph. Then add 
a single sentence or sentence fragment, which DocC uses as the page's abstract 
or summary.

```markdown
# ``SlothCreator``

Catalog sloths you find in nature and create new adorable virtual sloths.
```

After the summary, add another blank line and then one or more paragraphs that 
introduce your framework to form the Overview section of the landing 
page. Keep the Overview brief — typically less than a screen's worth of 
content. Avoid detailing every feature in your framework. Instead, 
provide content that helps the reader understand what problems the framework 
solves.

Write your Overview using _documentation markup_; a lightweight markup language 
that allows you to include images, lists, and links to 
symbols and other content. For more information, see 
<doc:formatting-your-documentation-content>. 

In addition to presenting rich content, a custom landing page provides organization of the top-level symbols and other content in your 
documentation hierarchy.

### Arrange Top-Level Symbols Using Topic Groups

By default, DocC arranges the symbols in your framework according to their 
kind. For example, the compiler generates topic groups for classes, structures, 
protocols, and so forth. You then add information to explain the relationships 
between those symbols.

To help readers more easily navigate your framework, arrange symbols into 
groups with meaningful names. Place important symbols higher on the page, and 
nest supporting symbols inside other symbols. Use group names that are unique, 
mutually exclusive, and have clear meaning. Experiment with different 
arrangements to find what works best for you.

![A screenshot showing the rendered documentation containing two topic groups: Essentials and Creating Sloths.](4_topics_1)

To override the default organization and manually arrange the top-level symbols 
in your framework, add a _Topics_ section to your framework's landing page. 
Below any content already in the Markdown file, add a double hash (`##`), a 
space, and the `Topics` keyword. 

```markdown
## Topics
```

After the Topics header, create a named section for each group using a triple 
hash (`###`), and add one or more top-level symbols to each section. 
Precede each symbol with a dash (`-`) and encapsulate it in a pair of double 
backticks (\`\`) .

```markdown
## Topics

### Creating Sloths

- ``SlothGenerator``
- ``NameGenerator``
- ``Habitat``

### Caring for Sloths

- ``Activity``
- ``CareSchedule``
- ``FoodGenerator``
- ``Sloth/Food``
```

DocC uses the double backtick format to create symbol links, and to add the 
symbol's type information and summary. For more information, see 
<doc:formatting-your-documentation-content>.

When you rebuild your documentation, the documentation viewer reflects these 
organizational changes in the navigation pane and on the framework's 
landing page, as the image above shows.

### Arrange Nested Symbols in Extension Files

Not all public symbols appear at the top-level of a framework. For example, 
classes and structures define methods and properties, and in some cases, nested 
classes or structures introduce additional levels of hierarchy.

As with the framework's landing page, DocC generates default topic groups for 
nested symbols according to their type. Use extension files to override this 
default organization and provide a more appropriate structure for your symbols.

![A screenshot showing the rendered documentation containing three topic groups: Creating a Sloth, Activities, and Schedule.](4_topics_2)

To add an extension file to your documentation catalog for a specific symbol, use a text editor to create a new file named `Extension.md`.

In the `Extension.md` file, replace the `Symbol` placeholder 
with the name of the symbol you're organizing and rename the file accordingly.

```markdown
# ``SlothCreator/Sloth``
```

> Important: You must use the symbol's absolute path for the page title of an 
extension file and include the name of the framework or package. DocC doesn't 
support relative symbol paths in this context.

The Extension File template includes a `Topics` section with a single named 
group, ready for you to fill out. Alternatively, if your documentation catalog 
already contains an extension file for a specific symbol, add a `Topics` 
section to it by following the steps in the previous section.

As with the landing page, create named sections for each topic group 
using a triple hash (`###`), and add the necessary symbols to each section 
using the double backtick (\`\`) syntax.

```markdown
# ``SlothCreator/Sloth``

## Topics

### Creating a Sloth

- ``init(name:color:power:)``
- ``SlothGenerator``

### Activities

- ``eat(_:quantity:)``
- ``sleep(in:for:)``

### Schedule

- ``schedule``
```

> Tip: Use a symbol's full path to include it from elsewhere in the 
documentation hierarchy.

After you arrange nested symbols in an extension file, use DocC to compile your changes and review them in your browser.

### Incorporate Hierarchy in Your Navigation

Much like you organize symbols on a landing page or in an extension file, you 
can create collections of symbols to add hierarchy to your documentation or 
to group symbols that have relationships other than those you define in your 
framework's type hierarchy.  For more information, see  
<doc:adding-supplemental-content-to-a-documentation-catalog>.

Collections are almost identical to articles, except for two things:

* A collection contains a Topics section, which instructs 
DocC to treat what would otherwise be an article as a collection.
* A collection rarely has enough descriptive content to warrant sections. 
Include a summary and an Overview section. If the Overview becomes long, 
consider turning it into an article and linking to it from one of the 
collection's topic groups.

To link to a collection, use the less-than symbol (<), the `doc` keyword, a 
colon (:), the name of the collection, and the greater-than symbol 
(>). Don’t include the collection's file extension in the name. 

```markdown
### Creating Sloths

- <doc:SlothGenerators>
```

DocC uses the collection's filename for its URL, and its page title as the link 
text.

Collections are an important tool for bringing order to your documentation, but 
they can also confuse a reader if you create too many levels of hierarchy. 
Avoid using a collection when a topic group at a higher level can achieve the 
same result.

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
