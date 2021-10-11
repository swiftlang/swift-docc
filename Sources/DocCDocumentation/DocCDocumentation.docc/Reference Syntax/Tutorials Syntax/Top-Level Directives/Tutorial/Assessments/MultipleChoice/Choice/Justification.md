# ``DocC/Justification``

Displays text that explains why a chosen multiple-choice answer is either correct or incorrect. 

- Parameters:
    - reaction: Text that clearly and succinctly indicates whether the answer is correct or incorrect, for example "Correct!" or "Sorry, try again." **(required)**

## Overview

Use the `Justification` directive to display a response when the reader chooses an answer in a multiple-choice assessment question in a tutorial. Use the `reaction` parameter to briefly indicate whether the choice is correct or incorrect. Then, provide some more descriptive text that explains why. In the case of an incorrect answer, consider also providing a hint so the reader can try again. 

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

### Containing Elements

The following items must include a justification:

- ``Choice``

## See Also

- ``Assessments``
- ``Tutorial``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
