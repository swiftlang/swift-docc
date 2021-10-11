# ``DocC/Choice``

Defines a single choice for a multiple-choice question in the assessments section of a tutorial page.

- Parameters:
    - isCorrect: A Boolean `true` or `false` value that denotes whether this choice is a correct or incorrect answer. **(required)**

## Overview

Use the `Choice` directive to define a single possible answer for a multiple-choice assessment question in a tutorial. Use the `isCorrect` parameter to denote whether the choice is a correct or incorrect answer. Then, use the ``Justification`` directive to explain why. Optionally, you can display an image for a choice.

```
@Tutorial(time: 30) {
    
    ...

    @Assessments {
        @MultipleChoice {
            What element did you use to add space around and between your views?

            @Choice(isCorrect: false) {
                A state variable.

                @Justification(reaction: "Try again!") {
                    Remember, it's something you used to arrange views vertically.
                }
            }

            ...
           
        }
    }
}
```

### Contained Elements

A choice can contain the following items:

- term ``Justification``: Text that explains why the choice is either correct or incorrect. **(required)**
- term ``Image``: An image that accompanies the choice. **(optional)**

### Containing Elements

The following items must include a choice:

- ``MultipleChoice``

## Topics

### Responding to the Choice

- ``Justification``

### Displaying an Image

- ``Image``

## See Also

- ``Assessments``
- ``Tutorial``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
