# Directives

Use structured, semantic, documentation elements authored in markup.

## Overview

Besides having a custom init to initialize all required properties, most directives are easily created out of markup source. Each directive has a name, expected parameter list, and content expectations.

For example ``ContentAndMedia`` requires at least one `Image` or `Video` directive in its enclosed content:

```markdown
@ContentAndMedia {
    Add the `EmailValidator` code.
         
    @Image(source: code.png,
           alt: "EmailValidator(string: email.stringValue).validate()")
}
```

## Topics

### Semantic Elements

- ``Semantic``
- ``SemanticVisitor``
- ``SemanticWalker``
- ``MarkupContainer``
- ``MarkupConvertible``
- ``DirectiveConvertible``
- ``TechnologyBound``

### Technology Directives

- ``Technology``
- ``Volume``
- ``Chapter``
- ``TutorialReference``
- ``Resources``
- ``Tile``
- ``Article``

### Tutorials Directives

- ``Tutorial``
- ``XcodeRequirement``
- ``TutorialSection``
- ``Code``
- ``Step``
- ``Steps``
- ``Assessments``
- ``MultipleChoice``
- ``Choice``
- ``Justification``
- ``Intro``
- ``Landmark``
- ``Stack``
- ``TutorialArticle``
- ``MarkupLayout``


### Symbol Reference Directives

- ``DeprecationSummary``
- ``PlatformName``
- ``Symbol``

### Metadata Directives

- ``DocumentationExtension``
- ``Metadata``
- ``TechnologyRoot``

### Common Directives

- ``ImageMedia``
- ``Media``
- ``VideoMedia``
- ``Comment``
- ``ContentAndMedia``
- ``Layout``
- ``Redirect``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
