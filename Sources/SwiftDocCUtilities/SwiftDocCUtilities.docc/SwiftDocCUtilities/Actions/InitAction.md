# ``SwiftDocCUtilities/InitAction``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
}

An action that generates a documentation catalog from a template seed.

## Overview

Generates a DocC catalog from one of the two available templates:
- `articleOnly`: A template designed for authoring article-only reference documentation.
- `tutorial`: A template designed for authoring tutorials, consisting of a catalog that contains a table of contents and a chapter.
ommit
Use `docc init` to quickly start authoring your content without having to manually add boilerplate content to get the DocC documentation catalog working.

## Templates

There are two available templates to start from, depending on the type of content the author wants to write.

### Article-Only Template

###### ArticleOnly.md
```
# ArticleOnly Template

<!--- Metadata configuration to make appear this documentation page as a top-level page -->

@Metadata {
  @TechnologyRoot
}

Add a single sentence or sentence fragment, which DocC uses as the page’s abstract or summary.

## Overview

Add one or more paragraphs that introduce your content overview.
```

With the structure:
```
⎯ ArticleOnly.docc
    ├ ArticleOnly.md
    ⎣ Resources
```

### Tutorial Template

###### table-of-contents.tutorial
```
@Tutorials(name: "\(title)") {
    @Intro(title: "Tutorial Introduction") {
        Add one or more paragraphs that introduce your tutorial.
    }
    @Chapter(name: "Chapter Name") {
        @Image(source: "add-your-chapter-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
        @TutorialReference(tutorial: "doc:page-01")
    }
}
```

###### Chapter01/page-01.tutorial
```
@Tutorial() {
    @Intro(title: "Tutorial Page Title") {
        Add one paragraph that introduce your tutorial.
    }
    @Section(title: "Section Name") {
        @ContentAndMedia {
            Add text that introduces the tasks that the reader needs to follow.
            @Image(source: "add-your-section-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
        }
        @Steps {
            @Step {
                This is a step with code.
                @Code(name: "", file: "")
            }
            @Step {
                This is a step with an image.
                @Image(source: "", alt: "")
            }
        }
    }
}
```

With the structure:
```
⎯ Tutorial.docc
    ├ table-of-contents.tutorial
    ├ Chapter01
    ⎜   ├ page-01.tutorial
    ⎜   ⎣ Resources
    ⎣ Resources
```


<!-- Copyright (c) 2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->
