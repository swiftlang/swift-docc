# ``DocC/DocumentationExtension``

Defines whether the content in a documentation extension file amends or replaces in-source documentation.

- Parameters:
    - mergeBehavior: A value of `append` or `override`, denoting whether an extension file's content amends or replaces the in-source documentation. **(required)**

## Overview

Swift framework and package APIs are typically documented using comments that reside in-source, alongside the APIs themselves. In some cases, you may wish to supplement or replace in-source documentation with content from dedicated documentation extension files. To learn about this process, see <doc:adding-supplemental-content-to-a-documentation-catalog>.

Place the `DocumentationExtension` directive within a `Metadata` directive in a documentation extension file. Set the `mergeBehavior` parameter to `append` or `override` to indicate whether the extension file's content amends or replaces the in-source documentation.

```
# ``SlothCreator/Sloth``

@Metadata {
    @DocumentationExtension(mergeBehavior: append)
}

## Sleeping Habits

Sloths sleep in trees by curling into a ball and hanging by their claws.
````

### Containing Elements

The following items can include a documentation extension element:

- ``Metadata``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
