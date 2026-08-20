import 'dart:ui';

import 'package:flutter/material.dart';

/// A small translucent badge that sits on top of imagery.
///
/// This is how the reference apps actually use glass: never as the card, never
/// behind body text — as a little pill floating on a photograph or a coloured
/// panel. A rating on a hero card, a reading annotating a scan, a timestamp on
/// a meal. It works because there is something rich underneath to show
/// through, which is exactly why frosting a white card on a grey page does
/// nothing.
///
/// [blur] is off by default, and that is an engineering decision rather than a
/// stylistic one. A real BackdropFilter costs a saveLayer and a framebuffer
/// read-back per instance; at chip size, over a photograph, a translucent fill
/// with a bright hairline is visually almost indistinguishable from a frosted
/// one. So a rail of five meal photos gets five cheap chips, and the single
/// badge on the focal card — where it is large enough to read as glass — gets
/// the real thing.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.blur = false,
    this.onDark = true,
  });

  final String label;
  final IconData? icon;
  final bool blur;

  /// True when the chip sits on a photo or a dark panel, which is the usual
  /// case. False tints it for a light surface instead.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : const Color(0xFF0B1B3A);

    final body = Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon == null ? 10 : 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: (onDark ? Colors.white : Colors.black).withValues(
          alpha: onDark ? 0.22 : 0.06,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (onDark ? Colors.white : Colors.black).withValues(
            alpha: onDark ? 0.42 : 0.10,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );

    if (!blur) return body;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: body,
      ),
    );
  }
}
