import 'package:flutter/material.dart';

import 'mood_avatar.dart';

/// Who the figure is. Decides the props: a stethoscope, a leaf, or neither.
enum CareRole { doctor, dietician, patient }

/// A character whose role, gender and expression all come from real state.
///
/// Reads `assets/characters/{role}_{gender}_{mood}.png` and falls back to the
/// drawn [MoodAvatar] when that file is not there. That fallback is the whole
/// design of this widget: art can be added one file at a time, a missing
/// combination degrades to a face rather than to a broken image, and replacing
/// the whole set later — better illustrations, or frames exported from Rive —
/// is a drop-in with no code change. See assets/characters/README.md.
///
/// The mood is chosen by the caller from clinical data. Nothing here animates
/// on a timer or on scroll position: a character that looks worried should mean
/// something is worth worrying about.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.role,
    required this.mood,
    this.gender,
    this.size = 56,
  });

  final CareRole role;
  final Mood mood;

  /// The account's gender string. Anything that is not male or female — unset,
  /// `other`, `undisclosed` — takes the neutral art rather than being guessed
  /// into one of the two.
  final String? gender;

  final double size;

  static String _genderSlug(String? g) => switch (g?.toLowerCase()) {
    'male' => 'male',
    'female' => 'female',
    _ => 'neutral',
  };

  String get _asset =>
      'assets/characters/${role.name}_${_genderSlug(gender)}_${mood.name}.png';

  @override
  Widget build(BuildContext context) {
    final drawn = MoodAvatar(mood: mood, size: size);

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedSwitcher(
        // A crossfade rather than a cut, so a reading that moves someone from
        // calm to concerned does not blink at them.
        duration:
            MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 400),
        child: Image.asset(
          _asset,
          // Keyed by the asset path: without this the switcher treats every
          // mood as the same child and never crossfades.
          key: ValueKey(_asset),
          width: size,
          height: size,
          fit: BoxFit.contain,
          // Decode at the size actually drawn. The art is 256px and this is
          // usually 56 — without it every avatar holds a full-size bitmap.
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          filterQuality: FilterQuality.medium,
          // No art for this combination yet: show the face, not a grey box.
          errorBuilder: (_, _, _) => drawn,
        ),
      ),
    );
  }
}
