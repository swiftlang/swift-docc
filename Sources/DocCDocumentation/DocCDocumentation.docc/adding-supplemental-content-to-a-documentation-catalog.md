# Adding Supplemental Content to a Documentation Catalog

Include articles and extension files to extend your source documentation comments or provide supporting conceptual content.

## Overview

A documentation catalog contains files that enrich your source documentation
comments. Two types of files that documentation catalogs can contain are
articles and extension files.

Typically, documentation comments in source code describe how specific APIs
work, but often don't explain how all the pieces in a project fit together at a
conceptual level. Adding an article to your documentation catalog is one way to
include this conceptual content. Articles are markup files that contain
information that doesn't relate to a specific symbol. Use articles to:

* Provide a landing page that includes an overview of your package or framework
* Craft a learning path for readers to understand how to use your code base, such
  as with a getting started guide or a tutorial
  
Extension files are markup files that complement source documentation
 comments. Use extension files to:

* Organize properties and methods that a symbol contains
* Provide additional content beyond source documentation comments
* Override source documentation comments

For details about adding a landing page and organizing symbols using extension
files, see
<doc:adding-structure-to-your-documentation-pages>.

The process of crafting great documentation is an art. Your
content is unique; you know which elements, beyond source
documentation comments, provide the most value to your readers. For 
information about adding documentation to your code base and creating a
documentation catalog, see
<doc:documenting-a-swift-framework-or-package>.

### Add Articles to Explain Concepts or Describe Tasks

Adding articles to your documentation catalog helps readers understand how
the types and methods in your code base work as a system. They let you
explain how to complete a task, or discuss a broader concept that doesn't fit
into an Overview section for a specific symbol.

![A screenshot showing the rendered documentation of an article titled Getting Started with Sloths. The article contains an abstract and an overview with a diagram associating a sloth's color with a power.](5_article)

The structure of an article is similar to symbol files or a top-level landing
page, with the exception that the first level 1 header is regular content instead
of a symbol reference. For example, the Getting Started with Sloths article
contains the following title, single-sentence abstract or summary, and overview section:

```markdown
# Getting Started with Sloths

Create a sloth and assign personality traits and abilities.

## Overview

Sloths are complex creatures that require careful creation and a suitable
habitat.
...
````

To add an article to your documentation catalog, use a text editor and create a file with an appropriate title and add a `.md` extension.

After the overview section, additional sections and subsections use a double
hash (##) for a level 2 header, and a triple hash (###) for a level 3 header.
Follow the hashes with a space, and then the title for that section or
subsection.

> Tip: To help readers perform a specific task, use sections to guide them
  through the steps necessary to complete the task. For larger concepts, consider
  adding a series of articles that build on each other.

When you add an article to a documentation catalog, DocC includes a link to it
on the project's top-level page. To choose a different location for the
article, add a link to it from a group or collection. When DocC renders a link to
 an article, it uses the article's title for the text of the link. For more information
about organizing your code base's documentation, see
<doc:adding-structure-to-your-documentation-pages>. 
 
### Add Extension Files to Append to or Override Source Documentation Comments

Although writing documentation comments in source files has many benefits, in some
circumstances it makes more sense to separate the content from the source
files, such as:

* When you include thorough code listings or numerous images that increase the
  size of your documentation and make source files difficult to manage
* When your source documentation comments focus on the implementation of your
  code, and aren't appropriate for external documentation

In cases like these, DocC supports supplementing or completely replacing source
documentation comments with content in extension files. To add an extension file to your
documentation catalog, create a file within the documentation catalog, then modify the first line of the file to identify the symbol that the file relates to.

> Important: You must use the symbol's absolute path for the page title of an 
extension file and include the name of the framework or package. DocC doesn't 
support relative symbol paths in this context.

If the symbol already has source documentation comments, add a
`DocumentationExtension` directive to specify whether the content of the
extension file appends to or overrides the source documentation comments. Add
the `DocumentationExtension` after the first line of the file that specifies
the symbol, using the following format:

````markdown
@Metadata {
    @DocumentationExtension(mergeBehavior: [append or override])
}
````

The `mergeBehavior` parameter determines whether DocC adds the extension file's
content to the bottom of the source documentation comments, or replaces
the source documentation comments entirely.

To add the extension file's content to source documentation comments, use
`append` for the `mergeBehavior`. For example, to add a section
about the sleeping habits of sloths to the `Sloth` type, the extension file
contains the following:

```markdown
# ``SlothCreator/Sloth``

@Metadata {
    @DocumentationExtension(mergeBehavior: append)
}

## Sleeping Habits

Sloths sleep in trees by curling into a ball and hanging by their claws.
````

Alternatively, to completely replace the source documentation comments, use
`override`. In this case, you add content after the directive that DocC uses
when generating documentation. For example, to replace the source documentation
comments of the `Sloth` type in SlothCreator, the extension file contains the following:

```markdown
# ``SlothCreator/Sloth``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

This overrides the in-source summary.

## Overview

This content overrides in-source content.
````

For additional details about `Metadata` and other directives, see
<doc:Metadata>.

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
