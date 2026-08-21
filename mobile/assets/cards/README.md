# Card artwork

## consult.jpg — the patient home hero

The blue "All clear" card on the patient's Home tab uses this as its
background, anchored to the **right** edge behind a left-weighted blue scrim.

**To change it, drop a file in at `assets/cards/consult.jpg` and rebuild.**
There is no code change and no pubspec change — `assets/cards/` is already
declared as an asset directory.

What the slot wants:

| | |
|---|---|
| Shape | roughly 12:5 landscape (e.g. 1200×500). It is cropped to a 208px-tall card, so anything close works. |
| Composition | the people on the **right third**. The left half is covered by the scrim and carries the headline, so faces placed there are hidden. |
| Subject | a doctor and a patient in consultation, warm and unposed. |
| Weight | under ~120 KB. It ships in the APK. |

If the file is absent the card falls back to `consult.png` (a drawn
consultation scene), and if that is missing too, to a plain blue gradient — so
a missing photograph never shows a broken image on a patient's home screen.

### Sourcing one

Pexels and Unsplash both allow commercial use with no attribution. Search
"doctor patient consultation". Download, crop to put the people on the right,
export as JPEG at ~80% quality, save here as `consult.jpg`.

## consult.png, clear.png, dose.png, steth.png

Drawn vector artwork, generated from SVG. `consult.png` is the hero's
fallback; the others are unused by the current Home layout and kept for the
illustrated tiles elsewhere.
