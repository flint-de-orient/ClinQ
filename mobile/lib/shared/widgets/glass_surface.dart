import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Glass surfaces, and the ground that makes them glass.
///
/// The two go together and that is the whole point. A frosted card on a flat
/// grey page is a slightly grey card — there is nothing behind it to show
/// through, so the effect costs a frame and returns nothing. [GlassGround]
/// paints the colour that [GlassSurface.card] then reveals.
///
/// Blur is off by default, and it is worth being precise about why rather than
/// treating it as a compromise. A backdrop blur only *looks* like anything over
/// detailed content — a photograph, dense text, a busy pattern. Over a smooth
/// gradient there is nothing to smear, so translucency alone gives the identical
/// result. The ground here is smooth by design, so the cards are translucent and
/// free, and the blur is reserved for the two places with real detail behind
/// them: a chip on a meal photograph, and the bar over scrolling content.
///
/// One rule is kept from the earlier soft surfaces: every card holds a bright
/// hairline. A translucent panel's edge is its weakest feature, and an edge you
/// cannot find is the accessibility failure this style is known for.
///
/// There is deliberately no grain. Frosted glass scatters and wants texture;
/// Liquid Glass does not — it is optically clean, and its whole character comes
/// from how it handles light at the edges rather than across the face. A speckle
/// over it reads as a dirty screen, which is precisely how it looked when it was
/// tried here.
///
/// What the material actually needs is three things, and all three are edges:
/// a body that graduates so the slab has thickness, a bright specular line
/// where light catches the top rim, and a shade along the bottom where the slab
/// is deepest.
class GlassSurface {
  const GlassSurface._();

  /// A translucent card, grained, with the thickness of a slab.
  ///
  /// The fill is a gradient rather than one flat alpha, and that is what makes
  /// it read as glass with depth instead of a sheet of tracing paper: light
  /// enters at the top, travels through the body, and the underside sits
  /// fractionally darker where the slab is thickest.
  static BoxDecoration card(
    BuildContext context, {
    double? radius,
    double opacity = 0.40,
    bool bordered = true,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = dark ? const Color(0xFF121A26) : Colors.white;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          // Transparent enough that the ground reads through the panel. Below
          // about 0.5 the colour behind starts to show and the thing becomes
          // glass; above it, it is a white card with a border, which is what
          // it was.
          tint.withValues(alpha: dark ? 0.46 : (opacity + 0.16).clamp(0, 1)),
          tint.withValues(alpha: dark ? 0.38 : opacity),
          tint.withValues(alpha: dark ? 0.32 : (opacity - 0.08).clamp(0, 1)),
        ],
        stops: const [0, 0.55, 1],
      ),
      borderRadius: BorderRadius.circular(radius ?? AppSpacing.sheetRadius),
      // The header reads as congested with an edge on it: it is a short bar
      // holding a round photo and a round button, and a hard outline around
      // that is one line too many. The sheen still gives it a lit top.
      border:
          bordered
              ? Border.all(
                color: Colors.white.withValues(alpha: dark ? 0.14 : 0.85),
                width: 1.2,
              )
              : null,
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: dark ? 0.30 : 0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// The specular pass: a rim of light on the top edge, a shade on the bottom.
  ///
  /// Painted as a foreground so it sits *on* the glass rather than under the
  /// content — which is the whole illusion, since real glass catches light on
  /// its surface, not behind whatever is printed on it.
  ///
  /// Both ends are tight. The highlight is gone by 7% of the height and the
  /// shade does not start until 93%, so the middle of the card — where all the
  /// text is — is untouched. A sheen that reaches the text washes it, and this
  /// is a clinical app before it is a pretty one.
  static BoxDecoration sheen({double? radius}) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius ?? AppSpacing.sheetRadius),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: 0.75),
        Colors.white.withValues(alpha: 0.14),
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0),
        const Color(0xFF0B1B3A).withValues(alpha: 0.05),
      ],
      stops: const [0, 0.035, 0.07, 0.93, 1],
    ),
  );

  /// The well an icon sits in, on glass.
  static BoxDecoration well(BuildContext context, {Color? tint}) {
    final base = tint ?? AppColors.primary;
    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          base.withValues(alpha: 0.16),
        ],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
    );
  }
}

/// The ground the whole app stands on.
///
/// It used to be three saturated blooms on a deep tint, and over a short hero
/// that looked rich. Over a long scrolling page it competed with the content:
/// every card had a different colour behind it, so no two cards looked like
/// the same component, and the eye kept being pulled to the background instead
/// of the readings printed on top of it.
///
/// So it is now a very light blue-grey with a single, almost imperceptible
/// warm-to-cool tilt down the page. White cards do the contrast work. A
/// background on a clinical dashboard has one job — to make the cards legible —
/// and the moment it is interesting it has stopped doing that job.
class GlassGround extends StatelessWidget {
  const GlassGround({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors:
              dark
                  ? const [Color(0xFF0A0F1A), Color(0xFF070C16)]
                  // ~2 points of lightness between the ends. Enough that the
                  // page is not a flat fill, far too little to read as a
                  // gradient, which is exactly the amount wanted.
                  : const [Color(0xFFEFF3FA), Color(0xFFF5F7FC)],
        ),
      ),
      child: child,
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius,
    this.blur = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? radius;

  /// Only for a card with detail behind it. See the note on [GlassSurface].
  final bool blur;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppSpacing.sheetRadius;
    Widget box = Container(
      width: double.infinity,
      decoration: GlassSurface.card(context, radius: r),
      foregroundDecoration: GlassSurface.sheen(radius: r),
      padding: padding,
      child: child,
    );
    if (blur) {
      box = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: box,
        ),
      );
    }
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(r),
        onTap: onTap,
        child: box,
      ),
    );
  }
}
