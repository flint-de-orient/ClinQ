import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// How the avatar should look, driven by clinical state rather than by scroll
/// position or a timeline.
///
/// This is the whole argument for drawing it rather than shipping an animation:
/// a canned clip plays the same way whatever is happening to the patient. This
/// one cannot be wrong about the mood, because the mood *is* the data.
enum Mood {
  /// Everything in range, nothing waiting.
  calm(1.0),

  /// Worth a look, not worth alarm — a check-in due, a dose missed.
  watchful(0.5),

  /// Out of range, or an alert is open.
  concerned(0.0);

  const Mood(this.value);

  /// 0 concerned → 1 calm. Interpolated, so the face blends between states
  /// rather than snapping.
  final double value;
}

/// A small drawn face whose expression follows the data.
///
/// No asset and no animation package: it is a CustomPainter, so it costs
/// nothing in the APK — which matters in an app whose release build we halved
/// on purpose — and it can sit at any size without a second export.
///
/// Deliberately minimal. This is a clinic used by elderly patients, several
/// with impaired vision; a detailed cartoon would read as a toy and lose its
/// shape at 40px. Two eyes, two brows and a mouth carry the whole expression,
/// and the brows do most of the work.
class MoodAvatar extends StatefulWidget {
  const MoodAvatar({
    super.key,
    required this.mood,
    this.size = 56,
    this.tone,
  });

  final Mood mood;
  final double size;

  /// Overrides the face colour. Defaults to the brand blue.
  final Color? tone;

  @override
  State<MoodAvatar> createState() => _MoodAvatarState();
}

class _MoodAvatarState extends State<MoodAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    // One controller drives both the blink and the breath. A blink is a brief
    // event inside a long cycle, so it is read off the same clock rather than
    // given a timer of its own.
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // "Remove animations" is an accessibility setting, and a face that blinks
    // and breathes is exactly what someone with vestibular sensitivity turned
    // it off for. The expression still changes; only the idle motion stops.
    final still = MediaQuery.disableAnimationsOf(context);
    final tone = widget.tone ?? AppColors.primary;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.mood.value),
      duration: still
          ? Duration.zero
          : const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, mood, _) {
        if (still) {
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _FacePainter(mood: mood, tone: tone, phase: 0, blink: 0),
          );
        }
        return AnimatedBuilder(
          animation: _idle,
          builder: (context, _) {
            final t = _idle.value;
            // A blink in the last 6% of the cycle, closing and opening again.
            final blink = t > 0.94 ? math.sin((t - 0.94) / 0.06 * math.pi) : 0.0;
            return CustomPaint(
              size: Size.square(widget.size),
              painter: _FacePainter(
                mood: mood,
                tone: tone,
                phase: t,
                blink: blink,
              ),
            );
          },
        );
      },
    );
  }
}

class _FacePainter extends CustomPainter {
  const _FacePainter({
    required this.mood,
    required this.tone,
    required this.phase,
    required this.blink,
  });

  /// 0 concerned → 1 calm.
  final double mood;
  final Color tone;

  /// 0→1 through the idle cycle.
  final double phase;

  /// 0 open → 1 shut.
  final double blink;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    // A breath: barely a pixel at 56px, which is the point. Motion you notice
    // on a clinical screen is motion in the way.
    final bob = math.sin(phase * math.pi * 2) * s * 0.008;
    final c = Offset(s / 2, s / 2 + bob);
    final r = s * 0.46;

    // --- head ------------------------------------------------------------
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [
            Color.lerp(tone, Colors.white, 0.82)!,
            Color.lerp(tone, Colors.white, 0.62)!,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.028
        ..color = tone.withValues(alpha: 0.55),
    );

    final ink = Paint()
      ..color = tone
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round;

    // --- eyes -------------------------------------------------------------
    final eyeY = c.dy - r * 0.14;
    final eyeDx = r * 0.40;
    final open = (1 - blink).clamp(0.0, 1.0);
    // Concern narrows the eyes a little; calm opens them.
    final eyeH = s * 0.085 * open * (0.82 + mood * 0.18);

    for (final dx in [-eyeDx, eyeDx]) {
      final e = Offset(c.dx + dx, eyeY);
      if (eyeH < s * 0.012) {
        // Shut: a line, not a squashed circle.
        canvas.drawLine(
          Offset(e.dx - s * 0.06, e.dy),
          Offset(e.dx + s * 0.06, e.dy),
          ink,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: e, width: s * 0.115, height: eyeH * 2),
          Paint()..color = tone,
        );
      }
    }

    // --- brows ------------------------------------------------------------
    // The brows carry the expression, and their direction is the whole
    // difference between two very different faces. Raised INNER ends read as
    // worry; lowered inner ends read as anger. An app that frowns at a patient
    // because their sugar is high would be unforgivable, so the inner end goes
    // up and the tilt is kept gentle.
    final browY = eyeY - r * 0.42 + (1 - mood) * r * 0.06;
    final tilt = (1 - mood) * s * 0.055;
    final browHalf = s * 0.10;

    for (final side in [-1.0, 1.0]) {
      final x = c.dx + side * eyeDx;
      // side == 1 is the right eye, so `x - browHalf * side` is its inner end.
      canvas.drawLine(
        Offset(x - browHalf * side, browY - tilt),
        Offset(x + browHalf * side, browY + tilt * 0.3),
        ink,
      );
    }

    // --- mouth ------------------------------------------------------------
    // One arc. Its control point crosses the baseline as mood falls, so the
    // same curve is a smile, a flat line and a frown.
    final mouthY = c.dy + r * 0.36;
    final half = r * 0.34;
    // Shallower on the downturn than the up: a slight frown reads as
    // concern, a deep one reads as disappointment.
    final curve = (mood - 0.5) * 2 * r * (mood < 0.5 ? 0.20 : 0.30);

    canvas.drawPath(
      Path()
        ..moveTo(c.dx - half, mouthY)
        ..quadraticBezierTo(c.dx, mouthY + curve, c.dx + half, mouthY),
      ink,
    );
  }

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.mood != mood ||
      old.tone != tone ||
      old.phase != phase ||
      old.blink != blink;
}
