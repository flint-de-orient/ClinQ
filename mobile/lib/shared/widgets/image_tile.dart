import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// An image-led navigation tile.
///
/// The reference healthcare apps this was measured against all navigate with
/// pictures rather than with rows of text: a photograph or an illustration
/// fills the tile and the label sits on it behind a scrim. That is most of why
/// they look expensive, and it was the single biggest thing this app did not
/// do — every route into a section was a line of text in a box.
///
/// The scrim is not optional. A label over artwork is unreadable on the light
/// parts and invisible on the dark ones; a gradient from transparent to near
/// black across the bottom third makes the caption legible whatever the
/// picture behind it is doing.
class ImageTile extends StatelessWidget {
  const ImageTile({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    this.onTap,
    this.height = 132,
  });

  /// Asset path for the artwork.
  final String image;

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: subtitle == null ? title : '$title. $subtitle',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  image,
                  fit: BoxFit.cover,
                  // Decoded at roughly the width it is drawn at. The art is
                  // 360px and a tile is about 170 — without this every tile
                  // holds a full-size bitmap for no visible gain.
                  cacheWidth:
                      (MediaQuery.sizeOf(context).width *
                              MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  filterQuality: FilterQuality.medium,
                  errorBuilder:
                      (_, _, _) => const ColoredBox(color: Color(0xFF13284F)),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xCC02060F)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
