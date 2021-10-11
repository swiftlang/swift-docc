# ``DocC/Forums``

Displays a set of forum links in the resources section of a tutorial's table of contents page.

- Parameters:
    - destination: A URL to a page of related forums. **(required)**

## Overview

Use the `Forums` directive to add links to related forums in the Resources section at the bottom of your tutorial's table of contents page.

DocC renders the URL you specify in the `destination` parameter as a "View forums" link at the bottom of the forums section. Within the directive, add descriptive text and, optionally, use standard Markdown syntax to provide links to one or more more specific forums.

A single "View forums" link:

```
@Tutorials(name: "SlothCreator") {
    
    ...
    
    @Resources {
        Explore more resources for learning about sloths.

        @Forums(destination: "https://www.example.com/sloth-forums/") {
            Get support for your sloths and connect with others.
        }
    }
}
````

A "View forums" link with additional specific forum links: 

```
@Tutorials(name: "SlothCreator") {
    
    ...
    
    @Resources {
        Explore more resources for learning about sloths.

        @Forums(destination: "https://www.example.com/sloth-forums/") {
            Get support for your sloths and connect with others.

            - [SlothCreator Help: Get Assistance with Sloth Development.](https://www.example.com/sloth-forums/help/)
            - [Sloth Talk: Meet Others Who Like Sloths Too](https://www.example.com/sloth-forums/speedy/)
        }
    }
}
````

You can include forum links alongside other types of resources, like ``Documentation``,  ``Downloads``, ``SampleCode``, and ``Videos``.

### Containing Elements

The following items can contain forum resources:

* ``Resources``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
