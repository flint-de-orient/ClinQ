# Character art

Drop illustrated character images in here and the app picks them up. No code
change is needed — `CharacterAvatar` looks for a file by name and falls back to
the drawn figure when it is not there.

## Naming

    {role}_{gender}_{mood}.png

    role    doctor | dietician | patient
    gender  male | female | neutral
    mood    calm | watchful | concerned

So the full set for a doctor is six files:

    doctor_male_calm.png       doctor_female_calm.png
    doctor_male_watchful.png   doctor_female_watchful.png
    doctor_male_concerned.png  doctor_female_concerned.png

Partial sets are fine. Anything missing falls back to the drawn figure for that
combination alone, so you can add one role at a time.

`neutral` is used when the account has no gender set, or has it as `other` /
`undisclosed`. Provide it if you can — otherwise those users get the drawing.

## What the art should be

- **Square**, transparent background.
- **512×512** is plenty. The avatar renders at 56–96 px, so 2x of the largest
  use is more than enough, and every extra pixel is APK weight in an app whose
  release build was deliberately halved.
- **PNG-8 or heavily compressed PNG-24.** Aim for under 40 KB each. Eighteen
  files at 40 KB is ~700 KB, which is the whole budget this is worth.
- **Head and shoulders**, centred, with a little headroom. The image is drawn
  inside a circle in some places, so keep anything important away from the
  corners.
- Match the app's blues where you can. `#003399` is the brand.

## Where they appear

- Patient Home — mood from the patient's own latest reading
- Doctor dashboard — mood from open alerts, then drift and pending reviews

The mood is always chosen from live clinical data, never from scroll position
or a timer.
