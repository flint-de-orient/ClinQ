import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'glass_surface.dart';

/// A navigation bar that looks like it floats and behaves like it does not.
///
/// It was briefly a real frosted bar over `extendBody`, and that was a mistake
/// worth writing down. Once content runs underneath, every bottom-anchored
/// thing in every shell becomes a special case: four FloatingActionButtons
/// went behind it, and — worse — the chat composers in two of the five patient
/// tabs, so a text field a patient was meant to type into sat under the bar.
/// A navigation bar is not the place to spend that.
///
/// So: side margins, a full radius and a soft shadow give the floating
/// appearance, the Scaffold reserves the whole height so nothing can hide
/// behind it, and the BackdropFilter is gone — with the body ending above the
/// bar there was nothing left to blur, and it was costing a saveLayer per
/// frame to prove it.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<GlassNavItem> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      // Floating, not seated. The gap is what makes the content behind it
      // visible, which is the entire point of frosting the thing.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.viewPaddingOf(context).bottom * 0.35,
      ),
      child: Container(
        height: 68,
        // The same specular pass the cards get, so the bar is made of the same
        // material rather than merely the same colour.
        foregroundDecoration: GlassSurface.sheen(
          radius: AppSpacing.sheetRadius + 8,
        ),
        decoration: BoxDecoration(
          // Translucent, not transparent — pure glass leaves the labels
          // fighting whatever is behind them — and graded rather than flat so
          // the pill reads as a slab with thickness.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (isDark ? const Color(0xFF10161F) : Colors.white).withValues(
                alpha: isDark ? 0.72 : 0.86,
              ),
              (isDark ? const Color(0xFF10161F) : Colors.white).withValues(
                alpha: isDark ? 0.58 : 0.70,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius + 8),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.85),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _Tab(
                  item: items[i],
                  selected: i == currentIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone =
        selected ? AppColors.accentOn(context) : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? item.selectedIcon : item.icon,
              size: 23,
              color: tone,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
