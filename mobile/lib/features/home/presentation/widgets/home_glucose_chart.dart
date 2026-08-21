import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/providers/preferences_provider.dart';
import '../../../glucose/domain/glucose_trends.dart';

/// The general adult target band, 70–180 mg/dL.
///
/// `GET /glucose/trends` does not publish a per-patient band, so this is drawn
/// purely as a visual reference and labelled as such on the chart. The
/// authoritative judgement on any single reading is still the server's
/// `flag`, which is what every status word on this screen is derived from —
/// the shading never decides whether a reading was in range.
const double kTargetLowMgdl = 70;
const double kTargetHighMgdl = 180;

/// The patient's trend, drawn to be read at a glance rather than studied.
///
/// Every choice here is a subtraction from what fl_chart does by default:
/// five horizontal rules instead of one every 50, six date labels at even
/// *time* intervals instead of one per reading, no vertical grid, no legend.
/// The previous chart printed a label per point, so a fortnight of daily
/// readings collided into an unreadable grey band along the bottom and the
/// same date appeared three times in a row.
class HomeGlucoseChart extends StatelessWidget {
  const HomeGlucoseChart({super.key, required this.points, required this.unit});

  final List<GlucoseTrendPoint> points;
  final GlucoseUnit unit;

  /// Rounds [v] out to the next multiple of [step], away from zero.
  static double _snap(double v, double step, {required bool up}) =>
      up ? (v / step).ceilToDouble() * step : (v / step).floorToDouble() * step;

  String _tick(double v) =>
      unit == GlucoseUnit.mgdl ? v.round().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    // Only points with a timestamp can be placed on a time axis. A reading
    // with no `at` is real data, but it has no position — dropping it is
    // honest; inventing one would not be.
    final dated =
        points.where((p) => p.at != null).toList()
          ..sort((a, b) => a.at!.compareTo(b.at!));
    if (dated.length < 2) return const SizedBox.shrink();

    final spots = [
      for (final p in dated)
        FlSpot(p.at!.millisecondsSinceEpoch.toDouble(), unit.fromMgdl(p.value)),
    ];

    final lowT = unit.fromMgdl(kTargetLowMgdl);
    final highT = unit.fromMgdl(kTargetHighMgdl);

    // The band is always fully visible even when every reading sits above it:
    // a target you cannot see is not a reference.
    final ys = spots.map((s) => s.y);
    final step = unit == GlucoseUnit.mgdl ? 50.0 : 2.0;
    var lo = _snap(
      [
        ys.reduce((a, b) => a < b ? a : b),
        lowT,
      ].reduce((a, b) => a < b ? a : b),
      step,
      up: false,
    );
    var hi = _snap(
      [
        ys.reduce((a, b) => a > b ? a : b),
        highT,
      ].reduce((a, b) => a > b ? a : b),
      step,
      up: true,
    );
    if (lo < 0) lo = 0;
    if (hi - lo < step * 4) hi = lo + step * 4;

    final minX = spots.first.x;
    final maxX = spots.last.x;
    // Several readings logged inside the same minute collapse the domain to a
    // single instant. Dividing by that produced NaN intervals, and fl_chart
    // given NaN draws a path with no bounds at all — which is how a stray blue
    // line ended up above the card. There is no trend in a zero-length window
    // to draw anyway.
    if (maxX <= minX || hi <= lo) return const SizedBox.shrink();

    // Six labels, evenly spaced in time — so the gaps between dates mean
    // something, and no date can print twice.
    final xInterval = (maxX - minX) / 5;

    final axisStyle = T.label.copyWith(
      fontSize: 11,
      letterSpacing: 0,
      fontWeight: FontWeight.w500,
      color: T.inkFaint,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: T.s1),
          child: Text(unit.label, style: axisStyle),
        ),
        const SizedBox(height: T.s1),
        SizedBox(
          height: 168,
          child: Stack(
            children: [
              LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: lo,
                  maxY: hi,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: (hi - lo) / 4,
                    getDrawingHorizontalLine:
                        (_) => const FlLine(
                          color: Color(0xFFEDF1F7),
                          strokeWidth: 1,
                        ),
                  ),
                  rangeAnnotations: RangeAnnotations(
                    horizontalRangeAnnotations: [
                      HorizontalRangeAnnotation(
                        y1: lowT,
                        y2: highT,
                        color: T.success.withValues(alpha: 0.10),
                      ),
                    ],
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: (hi - lo) / 4,
                        getTitlesWidget:
                            (v, _) => Padding(
                              padding: const EdgeInsets.only(right: T.s1),
                              child: Text(
                                _tick(v),
                                textAlign: TextAlign.right,
                                style: axisStyle,
                              ),
                            ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: xInterval,
                        getTitlesWidget: (v, _) {
                          final at = DateTime.fromMillisecondsSinceEpoch(
                            v.round(),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(top: T.s2),
                            child: Text(
                              DateFormat('d MMM').format(at),
                              style: axisStyle,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => T.ink,
                      getTooltipItems:
                          (touched) => [
                            for (final t in touched)
                              LineTooltipItem(
                                '${_tick(t.y)} ${unit.label}\n'
                                '${DateFormat('d MMM, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(t.x.round()))}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      // Above ~0.2 an overshoot between two distant readings
                      // can dip the curve below values never recorded, which
                      // on a glucose chart would read as a hypo that did not
                      // happen.
                      curveSmoothness: 0.2,
                      preventCurveOverShooting: true,
                      color: T.primary,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: spots.length <= 40,
                        getDotPainter:
                            (spot, _, _, _) => FlDotCirclePainter(
                              radius: 3,
                              color:
                                  spot.y < lowT || spot.y > highT
                                      ? T.primary
                                      : Colors.white,
                              strokeWidth: 2,
                              strokeColor: T.primary,
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            T.primary.withValues(alpha: 0.14),
                            T.primary.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Sits inside the shaded band at the right-hand edge, which is
              // the only spot on the plot the line reliably does not reach.
              Positioned(
                right: 0,
                top: 0,
                bottom: 24,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment(
                      1,
                      // Convert the middle of the band into the -1..1 the
                      // Alignment axis wants, flipped because y grows upward
                      // on the chart and downward on the screen. Clamped: the
                      // band can sit outside the drawn range, and an unclamped
                      // Alignment puts the label off the widget entirely.
                      (1 - 2 * (((lowT + highT) / 2) - lo) / (hi - lo)).clamp(
                        -1.0,
                        1.0,
                      ),
                    ),
                    child: Text(
                      'Target range',
                      style: T.label.copyWith(
                        fontSize: 10,
                        letterSpacing: 0,
                        color: T.success,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
