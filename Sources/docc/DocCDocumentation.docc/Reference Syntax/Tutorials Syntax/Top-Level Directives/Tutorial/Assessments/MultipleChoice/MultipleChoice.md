# ``DocC/MultipleChoice``

Defines a single question and multiple possible answers to include in the Assessments section of a tutorial page.

## Overview

Use the `MultipleChoice` directive to define a descriptive question that assesses the reader's knowledge after they complete the steps in a tutorial. Multiple choice questions appear in the assessments section of a tutorial  page. Provide a question and several choices.

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

            @Choice(isCorrect: true) {
                A `VStack` with trailing padding.

                @Justification(reaction: "That's right!") {
                    A `VStack` arranges views in a vertical line.
                }
            }

            @Choice(isCorrect: false) {
              
              ...
              
            }
        }  
    }
}
```

### Contained Elements

A multiple choice question contains the following items:

- term ``Choice``: A possible correct or incorrect answer to the question. It's a good idea to include 2-4 choices. **(optional)**

### Containing Elements

The following items include multiple choice questions:

- ``Assessments``

## Topics

### Offering Choices

- ``Choice``

## See Also

- ``Tutorial``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
