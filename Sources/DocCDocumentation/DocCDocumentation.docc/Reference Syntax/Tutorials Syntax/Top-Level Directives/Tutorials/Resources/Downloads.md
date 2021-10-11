# ``DocC/Downloads``

Displays a set of related download links in the resources section of a tutorial's table of contents page.

- Parameters:
    - destination: A URL to a page of related downloads. **(required)**

## Overview

Use the `Downloads` directive to add links to related downloads in the resources section at the bottom of your tutorial's table of contents page.

DocC renders the URL you specify in the `destination` parameter as a "View downloads" link at the bottom of the downloads section. Within the directive, add descriptive text and, optionally, use standard Markdown syntax to provide links to one or more more specific downloads or download pages.

A single "View downloads" link:

```
@Tutorials(name: "SlothCreator") {
    
    ...
    
    @Resources {
        Explore more resources for learning about sloths.

        @Downloads(destination: "https://www.example.com/sloth-downloads/") {
            Download resources that make sloth development even more fun.
        }

    }

}
````

A "View downloads" link with additional specific download links: 

```
@Tutorials(name: "SlothCreator") {
    
    ...
    
    @Resources {
        Explore more resources for learning about sloths.

        @Downloads(destination: "https://www.example.com/sloth-downloads/") {
            Download resources that make sloth development even more fun.

            - [Sloth Wallpaper](https://www.example.com/sloth-downloads/wallpaper/)
            - [Sloth Coloring Pages](https://www.example.com/sloth-downloads/coloring/)
            - [Sloth Apps](https://www.example.com/sloth-downloads/apps/)
        }

    }

}
````

You can include downloads alongside other types of resources, like ``Documentation``,  ``Forums``, ``SampleCode``, and ``Videos``.

### Containing Elements

The following items can contain download resources:

* ``Resources``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
