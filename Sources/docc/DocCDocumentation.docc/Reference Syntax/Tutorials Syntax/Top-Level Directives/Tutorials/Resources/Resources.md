# ``DocC/Resources``

Displays a set of links to related resources, like downloads, sample code, and videos.

## Overview

Use the `Resources` directive to include a Resources section at the bottom of a tutorial's table of contents page. This optional section can offer links to helpful material for continued learning. Provide some text for the top of the section, then add directives,  for example``Documentation``, ``Downloads``, ``Forums``, ``SampleCode``, and ``Videos`) for the resource types you want to share.

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

        @Downloads(destination: "https://www.example.com/images/sloth-wallpaper/") {
            Download the cutest sloth wallpaper for your iPhone, iPad, or Mac.
        }
    }
}
````

### Contained Elements

A Resources section can contain the following items:

- term ``Documentation``: Displays one or more links to related documentation. **(optional)**
- term ``Downloads``: Displays one or more links to related downloads. **(optional)**
- term ``Forums``: Displays one or more links to related forums. **(optional)**
- term ``SampleCode``: Displays one or more links to related sample code. **(optional)**
- term ``Videos``: Displays one or more links to related videos. **(optional)**

### Containing Elements

The following pages can include a Resources section:

* ``Tutorials``

## Topics

### Displaying Resources

- ``Documentation``
- ``Downloads``
- ``Forums``
- ``SampleCode``
- ``Videos``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
