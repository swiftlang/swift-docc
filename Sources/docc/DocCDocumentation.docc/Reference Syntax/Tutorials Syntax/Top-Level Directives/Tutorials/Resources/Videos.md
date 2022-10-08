# ``DocC/Videos``

Displays a set of video links in the resources section of a tutorial's table of contents page.

- Parameters:
    - destination: A URL to a page of related videos. **(required)**

## Overview

Use the `Videos` directive to add links to related videos in the Resources section at the bottom of your tutorial's table of contents page.

DocC renders the URL you specify in the `destination` parameter as a "Watch videos" link at the bottom of the sample code section. Within the directive, add descriptive text and, optionally, use standard Markdown syntax to provide links to one or more more specific videos.


A single "Watch videos" link:

```
@Tutorials(name: "SlothCreator") {
    
    ...
    
    @Resources {
        Explore more resources for learning about sloths.

        @Videos(destination: "https://www.example.com/sloth-videos/") {
            Watch cute videos of sloths climbing, eating, and sleeping.
        }
    }
}
````

A "Watch videos" link with additional specific video links: 

```
@Tutorials(name: "SlothCreator") {
        
    ...
    
    @Resources {
        Explore more resources for learning about sloths.

        @Videos(destination: "https://www.example.com/sloth-videos/") {
            Watch cute videos of sloths climbing, eating, and sleeping.

            - [Treetop Breakfast](https://www.example.com/sloth-videos/breakfast/)
            - [Slow Ascent](https://www.example.com/sloth-videos/climb/)
            - [Rest Time](https://www.example.com/sloth-videos/snoozing/)
        }
    }
}
````

You can include video links alongside other types of resources, like ``Documentation``,  ``Downloads``, ``Forums``, and ``SampleCode``.

### Containing Elements

The following items can contain video resources:

* ``Resources``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
