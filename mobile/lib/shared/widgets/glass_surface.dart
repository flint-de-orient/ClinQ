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
/// Every glass surface also carries a grain. Flat translucency reads as plastic
/// — real frosted glass scatters, and the eye knows the difference even when it
/// cannot name it. See [GlassSurface.grain] for why the opacity is what it is;
/// it was set by compositing the texture over the real card colour at four
/// levels and looking, not by picking a number that sounded subtle.
class GlassSurface {
  const GlassSurface._();

  /// The grain. One AssetImage, so Flutter caches a single decoded copy
  /// however many surfaces ask for it.
  ///
  /// Opacity lives here and nowhere else. The first version set it to 3% on a
  /// texture whose own alpha already topped out at 28%, and the two multiplied
  /// to about 0.8% — completely invisible. The texture is fully opaque now, so
  /// this number is the whole of it.
  ///
  /// 0.06, set on the device rather than in a preview. A flat composite
  /// suggested 0.08 and the fine tile argued for more, so 0.10 shipped — and
  /// on a real screen it read as a dirty display rather than as frosted glass,
  /// which is the exact failure this was meant to avoid. Grain should be felt
  /// and not seen; at 0.06 it is.
  static const DecorationImage grain = DecorationImage(
    image: AssetImage('assets/textures/noise.png'),
    repeat: ImageRepeat.repeat,
    opacity: 0.06,
    filterQuality: FilterQuality.none,
  );

  /// A translucent card, grained.
  static BoxDecoration card(
    BuildContext context, {
    double? radius,
    double opacity = 0.66,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      image: grain,
      color: (dark ? const Color(0xFF121A26) : Colors.white).withValues(
        alpha: dark ? 0.52 : opacity,
      ),
      borderRadius: BorderRadius.circular(radius ?? AppSpacing.sheetRadius),
      border: Border.all(
        color: (dark ? Colors.white : Colors.white).withValues(
          alpha: dark ? 0.10 : 0.75,
        ),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: dark ? 0.30 : 0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// The well an icon sits in, on glass.
  static BoxDecoration well(BuildContext context, {Color? tint}) {
    final base = tint ?? AppColors.primary;
    return BoxDecoration(
      shape: BoxShape.circle,
      image: grain,
      color: base.withValues(alpha: 0.12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
    );
  }
}

/// The coloured ground the glass sits on.
///
/// Three soft blooms on a tinted base — smooth on purpose, so translucent cards
/// reveal colour rather than noise, and so no card needs a real blur to read as
/// glass. Painted with positioned circles rather than a shader: three of them
/// cost nothing, and a fragment shader costs a pipeline compile on the first
/// frame, which is the worst moment to spend it.
class GlassGround extends StatelessWidget {
  const GlassGround({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF070C16) : const Color(0xFFEAF0FA);

    Widget bloom(Color c, double opacity, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            c.withValues(alpha: dark ? opacity * 1.6 : opacity),
            c.withValues(alpha: 0),
          ],
          stops: const [0, 0.72],
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(color: base),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -90,
            child: bloom(AppColors.primary, 0.30, 340),
          ),
          Positioned(
            top: 180,
            right: -130,
            child: bloom(AppColors.accent, 0.26, 320),
          ),
          Positioned(
            bottom: -140,
            left: 20,
            child: bloom(const Color(0xFF38BDF8), 0.20, 360),
          ),
          child,
        ],
      ),
    );
  }
}

/// A card on glass. One definition, so the panels cannot drift apart.
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
