# ``DocC/TutorialReference``

Adds an individual tutorial page link to a chapter on a table of contents page.

- Parameters:
    - tutorial: A link to a tutorial page, in the format *`<doc:[TutorialPageFileName]>`*. For example, *`<doc:Creating-Custom-Sloths>`*.  **(required)**

## Overview

Use the `TutorialReference` directive in a chapter on a table of contents page to link to a specific tutorial page. Include one `TutorialReference` per chapter. For each, use the `tutorial` parameter to reference the page by name, preceded by the doc: prefix.

```
@Tutorials(name: "SlothCreator") {
    
    ...
    
    @Chapter(name: "SlothCreator Essentials") {
        @Image(source: chapter1-slothcreatorEssentials.png, alt: "A wireframe of an app interface that has an outline of a sloth and four buttons below the sloth. The buttons display the following symbols, from left to right: snowflake, fire, wind, and lightning.")
        
        Create custom sloths and edit their attributes and powers using SlothCreator.
        
        @TutorialReference(tutorial: "doc:Creating-Custom-Sloths")
    }

    ...
    
}
````

### Containing Elements

The following items can include tutorial page references:

* ``Chapter``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
