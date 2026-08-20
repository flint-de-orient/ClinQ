import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Soft, extruded surfaces — neumorphism with the accessibility put back in.
///
/// Real neumorphism differentiates an element from its background *only* by
/// shadow: same fill, same colour, no edge. Low contrast is the definition of
/// the style rather than a mistake in applying it. Reduced contrast sensitivity
/// is a primary symptom of diabetic retinopathy, which is the complication this
/// app exists to catch, so the pure form is off the table.
///
/// What survives is the part worth having: a light source above-left, a soft
/// dark shadow below-right, and a fill that sits proud of the page. The
/// hairline border is the concession, and it is not negotiable — it is what
/// keeps the card's edge findable for someone who cannot see the shadow.
class SoftSurface {
  const SoftSurface._();

  /// Raised: cards, tiles, anything sitting on the page.
  static BoxDecoration raised(
    BuildContext context, {
    double? radius,
    Color? fill,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: fill ?? scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(radius ?? AppSpacing.sheetRadius),
      border: Border.all(
        color: scheme.outlineVariant.withValues(alpha: dark ? 0.45 : 0.55),
      ),
      boxShadow: [
        // The light. Above-left, and white on a light theme is the whole trick —
        // it is what makes the top edge read as catching a highlight.
        BoxShadow(
          color:
              dark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.90),
          offset: const Offset(-3, -3),
          blurRadius: 8,
        ),
        // The shadow. Brand-tinted rather than black — a neutral grey under a
        // blue-white page reads as dirt.
        BoxShadow(
          color: AppColors.primary.withValues(alpha: dark ? 0.28 : 0.07),
          offset: const Offset(4, 5),
          blurRadius: 16,
        ),
      ],
    );
  }

  /// Pressed: the soft well an icon or a control sits inside.
  ///
  /// A true inset needs a shader; this is the honest approximation — a tinted
  /// fill with the border darkened on the top edge, which reads as recessed at
  /// the sizes it is used at.
  static BoxDecoration pressed(
    BuildContext context, {
    double? radius,
    Color? tint,
    bool circle = false,
  }) {
    final base = tint ?? AppColors.primary;
    return BoxDecoration(
      color: base.withValues(alpha: 0.07),
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius:
          circle
              ? null
              : BorderRadius.circular(radius ?? AppSpacing.cardRadius),
      border: Border.all(color: base.withValues(alpha: 0.12)),
    );
  }
}

/// A card on a soft raised surface. Replaces a plain Container so the same
/// depth is not re-derived slightly differently on every screen.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      decoration: SoftSurface.raised(context, radius: radius),
      padding: padding,
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius ?? AppSpacing.sheetRadius),
        onTap: onTap,
        child: box,
      ),
    );
  }
}
