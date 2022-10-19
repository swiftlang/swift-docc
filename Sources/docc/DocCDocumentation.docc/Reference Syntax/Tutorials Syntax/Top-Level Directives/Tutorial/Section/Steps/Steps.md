# ``DocC/Steps``

Defines a set of tasks the reader performs on a tutorial page.

## Overview

Use the `Steps` directive to define a set of tasks the reader performs on a tutorial page.

![A screenshot showing three steps on a tutorial page.](3)

Each individual step contains instructional text along with either a code listing, an image , or a video.

```
@Tutorial(time: 30) {
    
    ...
    
    @Section(title: "Create a Swift Package") {
        @ContentAndMedia(layout: "horizontal") {

            ...

        }
        
        @Steps {
            @Step {
                Create a new directory named `SwiftPackage`.
                
                @Code(name: "CreateDirectory.sh", file: 01-create-dir.sh) {
                    @Image(source: preview-01-create-directory.png, alt: "A screenshot from the command-line showing creating the directory using the `mkdir SwiftPackage` command.")
                }
            }    

        @Step {
            Change into the new directory.
            
            @Code(name: "ChangeDirectory.sh", file: 02-change-directory.sh) {
                @Image(source: preview-02-change-directory.png, alt: "A screenshot from the command-line showing changing into the directory using the `cd SwiftPackage` command.")
            }
        }    

            @Step {
                Create a new Swift Package.
                
                @Code(name: "Package.swift", file: 03-create-package.sh) {
                    @Image(source: preview-03-create-package.png, alt: "A screenshot from the command-line showing Swift Package creation using the `swift package init` command.")
                }
            }    
            
            ...

        }
    }
}
````

### Contained Elements

A set of steps can contain one or more of the following items:

- term ``Step``: An individual task the reader performs. **(optional)**

### Containing Elements

The following items can include a set of steps:

- ``Section``

## Topics

### Adding Individual Steps

- ``Step``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
