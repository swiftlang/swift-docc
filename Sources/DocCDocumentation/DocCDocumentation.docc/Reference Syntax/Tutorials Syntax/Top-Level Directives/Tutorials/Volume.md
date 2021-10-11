# ``DocC/Volume``

Organizes related chapters into a volume on a tutorial's table of contents page.

- Parameters:
    - name: The name of the volume. **(required)**

## Overview

If you need a second level of organization on a table of contents page, use `Volume` directives to organize related chapters into volume groupings. For each volume, use the `name` parameter to specify a volume name, and provide some descriptive text. Then, insert ``Chapter`` directives for the chapters each volume contains. Optionally, use an ``Image`` directive to show an image for a volume.

```
@Tutorials(name: "SlothCreator") {
    @Intro(title: "Meet SlothCreator") {
        
        ...
    }
    
    @Volume(name: "Getting Started") {
        Building sloths, caring for them, and interacting with them.
        
        @Chapter(name: "SlothCreator Essentials") {
            ...
        }
        
        @Chapter(name: "Basic Sloth Care") {
            ...
        }
        
        @Chapter(name: "Basic Sloth Interaction") {
            ...
        }
    }
    
    @Volume(name: "Climbing Higher") {
        Taking your sloths to the next level.
        
        @Chapter(name: "Powering Up") {
            ...
        }
    
        ...
    }
    
   ...
}
````

### Contained Elements

A volume can contain the following items:

- term ``Chapter``: A chapter containing one or more tutorial pages. A volume must contain at least one chapter. **(optional)**
- term ``Image``: An image that represents the volume's content. **(optional)**

### Containing Elements

The following pages can include volumes:

* ``Tutorials``

## Topics

### Referencing Chapters

- ``Chapter``

### Displaying an Image

- ``Image``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
