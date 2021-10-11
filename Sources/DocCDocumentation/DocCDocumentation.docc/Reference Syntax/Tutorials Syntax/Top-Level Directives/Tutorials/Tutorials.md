# ``DocC/Tutorials``

Displays a table of contents page for readers to navigate the pages of an interactive tutorial.

- Parameters:
    - name: The name of your tutorial. This typically matches the name of the Swift framework or package you're documenting. **(required)**

## Overview

The `Tutorials` directive defines the structure of the table of contents page readers navigate to access individual tutorial pages.

Use a text editor to add a tutorial table of contents file to your documentation catalog. Ensure the filename ends with `.tutorial`, then copy and paste the template below into your editor. Replace the placeholder content provided with custom content.

``` 
@Tutorials(name: "SlothCreator") {
    @Intro(title: "Meet SlothCreator") {
        Create, catalog, and care for sloths using SlothCreator. 
        Get started with SlothCreator by building the demo app _Slothy_.
        
        @Image(source: "slothcreator-intro.png", alt: "An illustration of 3 iPhones in portrait mode, displaying the UI of finding, creating, and taking care of a sloth in Slothy — the sample app that you build in this collection of tutorials.")
    }
    
    @Chapter(name: "SlothCreator Essentials") {
        @Image(source: "chapter1-slothcreatorEssentials.png", alt: "A wireframe of an app interface that has an outline of a sloth and four buttons below the sloth. The buttons display the following symbols, from left to right: snowflake, fire, wind, and lightning.")
        
        Create custom sloths and edit their attributes and powers using SlothCreator.
        
        @TutorialReference(tutorial: "doc:Creating-Custom-Sloths")
    }
}
````

Use the `name` parameter to specify the name of your overall tutorial. This appears throughout the tutorial and in the tutorial's URL when published on the web. Next, use the ``Intro`` directive to introduce the reader to your tutorial through engaging text and imagery. Then, use ``Chapter`` directives to reference the step-by-step pages. Chapters can also include images.

### Group Related Chapters

Use the ``Volume`` directive to group related chapters together if you need another level of organization. Volumes can also include images.

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

### Offer Resources for Continued Learning

If your tutorial has related resources, use the ``Resources`` directive to share them.

```
@Tutorials(name: "SlothCreator") {
    @Intro(title: "Meet SlothCreator") {
        
        ...
    }
    
    @Chapter(name: "SlothCreator Essentials") {
        ...
    }
    
    @Chapter(name: "Basic Sloth Care") {
        ...
    }
    
    @Chapter(name: "Basic Sloth Interaction") {
        ...
    }

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

To walk through the creation of a simple tutorial project from start to finish, see <doc:building-an-interactive-tutorial>.

### Contained Elements

A table of contents page can contain the following items:

- term ``Intro``: Engaging introductory text and an image or video to display at the top of the table of contents page. **(required)**
- term ``Chapter``: A chapter of a tutorial. This links to individual tutorial pages. A table of contents page must include at least one chapter. **(optional)**
- term ``Resources``: A section that contains links to related resources, like downloads, sample code, and videos. **(optional)**
- term ``Volume``: A group of related chapters. **(optional)**

## Topics

### Providing an Introduction

- ``Intro``

### Organizing Content

- ``Chapter``
- ``Volume``

### Sharing Resources

- ``Resources``

## See Also

- <doc:building-an-interactive-tutorial>

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
