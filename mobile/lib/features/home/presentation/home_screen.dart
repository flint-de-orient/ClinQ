import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/character_avatar.dart';
import '../../../shared/widgets/glass_chip.dart';
import '../../../shared/widgets/mood_avatar.dart';
import '../../../shared/widgets/status_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../glucose/domain/glucose_trends.dart';
import '../../glucose/presentation/glucose_providers.dart';
import '../../glucose/presentation/log_glucose_sheet.dart';
import '../../glucose/presentation/widgets/glucose_stats_row.dart';
import '../../glucose/presentation/widgets/glucose_trend_chart.dart';
import '../../labtests/domain/lab_tests.dart';
import '../../labtests/presentation/lab_tests_providers.dart';
import '../../medications/presentation/medications_providers.dart';
import '../../medications/domain/medication.dart';
import '../domain/care_summary.dart';
import 'home_providers.dart';

/// The patient's home: their care as the clinic has set it out.
///
/// Read-only by design. This is the answer to "what am I supposed to be doing",
/// and every action it implies — logging a meal, ticking off a dose, asking a
/// question — already has a tab of its own. A second place to do those things
/// would be a second place to keep them in sync.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  Timer? _poll;

  /// The home screen shows what the clinic has decided — a new prescription, a
  /// diet plan the dietician just sent, a fresh HbA1c. None of that is the
  /// patient's own doing, so waiting for them to pull-to-refresh means showing
  /// them yesterday's care and giving no sign there is anything newer.
  static const _pollInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(_pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the background is the likeliest moment for something to
    // have changed, so check at once rather than waiting out the timer.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    ref.invalidate(careSummaryProvider);
    // Also the source the on-device reminders are built from: a dose the doctor
    // has just retimed should move on this screen *and* stop ringing at the old
    // hour, without waiting for the app to be backgrounded and reopened.
    ref.invalidate(medicationsListProvider);
    // Today's doses too, so a dose ticked off in the Medicines tab moves this
    // screen's progress bar the moment the patient comes back to it.
    ref.invalidate(todayScheduleProvider);
    // And the lab reports: a report uploaded from the Profile tab, or an
    // analysis that finished on the server a minute after the upload, both have
    // to land here without the patient knowing to come back and pull down.
    ref.invalidate(labTestsProvider);
    // The glucose chart and the "Current glucose" tile above it both read this,
    // so a reading logged from anywhere in the app shows on both at once.
    ref.invalidate(glucoseTrendsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final asyncCare = ref.watch(careSummaryProvider);
    // Read the last value during a background refresh: .when would drop the
    // whole screen to a spinner every thirty seconds.
    final loaded = asyncCare.valueOrNull;
    final async = loaded != null ? AsyncData<CareSummary>(loaded) : asyncCare;

    return Scaffold(
      backgroundColor: scheme.surfaceContainer,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: async.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (_, _) => ListView(
                        children: [
                          const SizedBox(height: 140),
                          const Center(
                            child: Text('Could not load your care summary'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Center(
                            child: OutlinedButton(
                              onPressed:
                                  () => ref.invalidate(careSummaryProvider),
                              child: const Text('Retry'),
                            ),
                          ),
                        ],
                      ),
                  // Zero padding on the list so the hero can run to both
                  // edges; everything after it is padded individually. A
                  // colour that stops short of the screen edge reads as a
                  // card, not as the ground the screen is standing on.
                  data:
                      (care) => ListView(
                        padding: const EdgeInsets.only(bottom: 110),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.md,
                              AppSpacing.md,
                              0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Greeting(
                                  mood: switch (ref
                                      .watch(glucoseTrendsProvider)
                                      .valueOrNull
                                      ?.series
                                      .lastOrNull
                                      ?.flag) {
                                    'severe_low' ||
                                    'low' ||
                                    'severe_high' ||
                                    'high' => Mood.concerned,
                                    null => Mood.watchful,
                                    _ => Mood.calm,
                                  },
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _FocalCard(care: care),
                                const SizedBox(height: AppSpacing.md),
                                const _SectionLabel('Health overview'),
                                const SizedBox(height: AppSpacing.sm),
                                _HealthOverview(care: care),
                                const SizedBox(height: AppSpacing.lg),
                                const _SectionLabel('Quick access'),
                                const SizedBox(height: AppSpacing.sm),
                                const _QuickAccess(),
                                const SizedBox(height: AppSpacing.lg),

                                const SizedBox(height: AppSpacing.md),
                                const _GlucoseCard(),

                                // Condition, next visit, measurements. Real
                                // information, but not what anyone opens the
                                // app to find — so it sits under the four
                                // blocks rather than among them.
                                const SizedBox(height: AppSpacing.md),
                                _FactGrid(care: care),

                                // Directly under glucose: both answer "what do my numbers
                                // say", and an ordered test sitting undone is the thing on
                                // this screen most likely to be holding up the next
                                // consultation.
                                const SizedBox(height: AppSpacing.md),
                                const _LabReports(),

                                if (care.profile.allergies.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  _Allergies(items: care.profile.allergies),
                                ],

                                if (care.dietPlan != null) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  _DietPlanCard(plan: care.dietPlan!),
                                ],

                                // Each section now carries its own heading inside its
                                // card, so the spacing between them is uniform and the
                                // page reads as one stack rather than headings and
                                // content taking turns.
                                // Medicines and food logs are gone from Home.
                                // Each is an entire tab, each is one tap away
                                // from Quick access, and the next dose is
                                // already the subject of the focal card — so
                                // showing the full list here was the same
                                // content in a third place.
                              ],
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Glucose monitoring ---------------------------------------------------

/// The patient's own glucose trend on their home — the same picture the clinic
/// watches, so "how am I doing?" has an answer right here — with the one
/// low-friction place to add a reading, since forgetting to check in is the
/// thing that quietly breaks continuous monitoring.
class _GlucoseCard extends ConsumerWidget {
  const _GlucoseCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppColors.accentOn(context);
    final trends = ref.watch(glucoseTrendsProvider);

    return _HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.monitor_heart_rounded,
            title: 'Your glucose',
            actionLabel: 'Add',
            actionIcon: Icons.add_rounded,
            onAction: () => showLogGlucoseSheet(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          trends.when(
            loading:
                () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
            error:
                (_, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'Could not load your readings.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
            data: (t) {
              if (t.series.length < 2) return _CheckInPrompt(accent: accent);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlucoseStatsRow(stats: t.stats),
                  const SizedBox(height: AppSpacing.md),
                  GlucoseTrendChart(trends: t),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Shown when there are too few readings to draw a trend — a friendly first
/// check-in nudge in place of an empty chart.
class _CheckInPrompt extends StatelessWidget {
  const _CheckInPrompt({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Log a glucose reading every few days and your trend builds here — the same one your doctor sees.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => showLogGlucoseSheet(context),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add your first reading'),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              minimumSize: const Size.fromHeight(46),
            ),
          ),
        ),
      ],
    );
  }
}

// ---- Facts ----------------------------------------------------------------

class _FactGrid extends ConsumerWidget {
  const _FactGrid({required this.care});

  final CareSummary care;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = care.profile;
    final hba1c = care.latestHba1c;
    // Facts, not widgets: the grid decides afterwards whether each one is drawn
    // as a square tile or, when it is the odd one out at the end, as a wide bar.
    final facts = <_Fact>[
      if (p.conditionLabel != null) _Fact('Condition', p.conditionLabel!),
      // The doctor's next-visit instruction — arguably the most useful single
      // thing on this screen: "when do I come back?".
      // Next visit, BMI, blood pressure and the latest glucose are all on
      // the four blocks above. Repeating them here made the same fact appear
      // twice on one screen, which reads as the app not knowing what it has
      // already told you.
      // One measurement per tile. Crammed into a single "BMI / Wt / Ht" cell the
      // value wrapped onto a second line, which made that row taller than the
      // one beside it and broke the grid — and three numbers separated by
      // slashes is a thing to decode rather than read.
      if (p.weightKg != null) _Fact('Weight', '${p.weightKg} kg'),
      if (p.heightCm != null) _Fact('Height', '${p.heightCm} cm'),
      if (p.reviewLabel != null) _Fact('Food-log review', p.reviewLabel!),
      // The newest reading, beside the numbers it belongs with. The chart below
      // shows the shape of the last month; this answers the simpler question a
      // patient asks first — where am I right now.
      if (hba1c != null)
        _Fact(
          'Last HbA1c',
          '${hba1c.percentage}%${hba1c.isHigh ? ' (High)' : ''}',
          // Coloured only when it is above this patient's own target — a red
          // number they cannot act on tonight is alarm without information, so
          // it stays plain when the result is where the doctor wants it.
          color: hba1c.isHigh ? AppColors.danger : null,
        ),
    ];

    if (facts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < facts.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          // Which facts the record holds decides how many there are, so the
          // count is odd as often as it is even. A lone tile stretched across
          // the full width reads as a mistake; the same fact laid along that
          // width — label left, value right — reads as a summary line, which is
          // what it is.
          if (i + 1 >= facts.length)
            _FactCard(fact: facts[i], wide: true)
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _FactCard(fact: facts[i])),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _FactCard(fact: facts[i + 1])),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// One fact on the grid: what it is, what it says, and whether that value is
/// outside the target the clinic set.
class _Fact {
  const _Fact(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;
}

class _FactCard extends StatelessWidget {
  const _FactCard({required this.fact, this.wide = false});

  final _Fact fact;

  /// Label and value side by side across the full width, for the odd tile at
  /// the end of the grid.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final label = Text(
      fact.label,
      style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
    );
    final value = Text(
      fact.value,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: fact.color ?? scheme.onSurface,
      ),
    );

    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child:
          wide
              ? Row(
                children: [
                  Expanded(child: label),
                  const SizedBox(width: AppSpacing.sm),
                  value,
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [label, const SizedBox(height: 4), value],
              ),
    );
  }
}

class _Allergies extends StatelessWidget {
  const _Allergies({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerBgOn(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.dangerOn(context).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dangerous_outlined,
                size: 21,
                color: AppColors.dangerOn(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Allergies & Intolerances',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dangerOn(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final item in items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dangerOn(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- Diet plan ------------------------------------------------------------

class _DietPlanCard extends StatelessWidget {
  const _DietPlanCard({required this.plan});

  final PatientDietPlan plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Keeps its accent wash rather than the plain card the others use — this is
    // the one section on the screen written by a person for this patient, and it
    // should not look like another read-out.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentSoftOn(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentOn(context).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.restaurant_rounded,
            title: 'Current Diet Plan',
            trailing:
                plan.sharedAt == null
                    ? null
                    : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Text(
                        'Sent ${DateFormat('d MMM').format(plan.sharedAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
          ),
          if (plan.goal.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Goal: ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: plan.goal),
                ],
              ),
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ],
          if (plan.meals.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < plan.meals.length; i += 2) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _MealCard(meal: plan.meals[i])),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child:
                          i + 1 < plan.meals.length
                              ? _MealCard(meal: plan.meals[i + 1])
                              : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (plan.avoid.isNotEmpty || plan.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed:
                    () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _FullPlanSheet(plan: plan),
                    ),
                child: Text(
                  'View full plan',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentOn(context),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});

  final PlanMeal meal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meal.time.isEmpty ? meal.name : '${meal.name} • ${meal.time}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meal.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The whole plan, including the avoid list and any closing note. Shown as a
/// sheet rather than a PDF: there is no document to open, and a link that
/// promised one would be a link that breaks.
class _FullPlanSheet extends StatelessWidget {
  const _FullPlanSheet({required this.plan});

  final PatientDietPlan plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder:
          (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              const Text(
                'Your diet plan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              if (plan.dieticianName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'From ${plan.dieticianName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (plan.goal.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  plan.goal,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
              for (final meal in plan.meals) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  meal.time.isEmpty ? meal.name : '${meal.name} · ${meal.time}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                for (final item in meal.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '•  $item',
                      style: const TextStyle(fontSize: 14, height: 1.45),
                    ),
                  ),
                if (meal.notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      meal.notes,
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
              if (plan.avoid.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Best avoided',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final item in plan.avoid)
                      Chip(
                        label: Text(item),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              if (plan.notes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  plan.notes,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
    );
  }
}

// ---- Medicines ------------------------------------------------------------

// ---- Food logs ------------------------------------------------------------

/// Lab reports: what the doctor has asked for, and what came back.
///
/// The tests live under Profile, which is where a patient goes to *manage*
/// them. But an ordered test the patient has not had done yet is one of the few
/// things on this screen they are actually expected to act on, and a result that
/// has come back is one of the few that changes what happens next. Both belong
/// where they will be seen.
class _LabReports extends ConsumerWidget {
  const _LabReports();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(labTestsProvider);

    // Read the last value through a refresh: this sits mid-page, and dropping it
    // to a spinner every thirty seconds would make the screen twitch.
    final view = async.valueOrNull;

    return _HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.biotech_rounded,
            title: 'Lab Reports',
            actionLabel: 'Upload',
            actionIcon: Icons.file_upload_outlined,
            onAction: () => context.push('/profile/tests'),
          ),
          const SizedBox(height: AppSpacing.sm),

          if (view == null && async.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else if (view == null)
            Text(
              'Could not load your reports.',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            )
          else
            ..._body(context, scheme, view),
        ],
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    ColorScheme scheme,
    LabTestsView view,
  ) {
    // A test the doctor advised and the patient has not uploaded anything for.
    // Matched on name because that is all the advice carries — the prescription
    // records a test name, not an id.
    final uploaded =
        view.results.map((r) => r.testName.trim().toLowerCase()).toSet();
    final pending =
        view.advised
            .where((t) => !uploaded.contains(t.trim().toLowerCase()))
            .toList();
    final recent = view.results.take(3).toList();

    if (pending.isEmpty && recent.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No reports yet.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 0),
              Text(
                'Upload a photo or PDF of a lab report and your doctor sees the results here.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      if (pending.isNotEmpty) _AdvisedTests(tests: pending),
      if (pending.isNotEmpty && recent.isNotEmpty)
        const SizedBox(height: AppSpacing.md),
      for (var i = 0; i < recent.length; i++) ...[
        if (i > 0)
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 8, bottom: 8),
            child: Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        _LabResultRow(result: recent[i]),
      ],
      if (view.results.length > recent.length) ...[
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.push('/profile/tests'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentOn(context),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: Text('View all ${view.results.length} reports'),
          ),
        ),
      ],
    ];
  }
}

/// Tests the doctor ordered that have not come back yet.
class _AdvisedTests extends StatelessWidget {
  const _AdvisedTests({required this.tests});

  final List<String> tests;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOn(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tests.length == 1
                      ? 'Your doctor has asked for 1 test'
                      : 'Your doctor has asked for ${tests.length} tests',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final t in tests.take(6))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Text(
                    t,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (tests.length > 6)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '+${tests.length - 6} more',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One uploaded report: what it was, when, and what came of it.
class _LabResultRow extends StatelessWidget {
  const _LabResultRow({required this.result});

  final LabResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppColors.accentOn(context);
    final abnormal = result.abnormal.length;
    final status = result.analysisStatus;

    // Red only for a value actually outside its range. "Still being read" and
    // "could not be read" are states of the app, not of the patient's health,
    // and colouring them like a bad result would be a false alarm.
    final (String label, Color fg, Color bg)? chip = switch (status) {
      'done' when abnormal > 0 => (
        abnormal == 1 ? '1 out of range' : '$abnormal out of range',
        AppColors.dangerOn(context),
        AppColors.dangerOn(context).withValues(alpha: 0.10),
      ),
      'done' => (
        'All in range',
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      ),
      'pending' => (
        'Being read',
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      ),
      'failed' || 'unsupported' => (
        'Not read',
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      ),
      _ => null,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.description_rounded, size: 17, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.testName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (result.createdAt != null)
                    Text(
                      DateFormat('d MMM yyyy').format(result.createdAt!),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (result.createdAt != null && chip != null)
                    Text(
                      '  ·  ',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (chip != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: chip.$3,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        chip.$1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: chip.$2,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The card every section on this screen sits in.
///
/// The screen used to speak three visual languages at once: glucose and the
/// diet plan were self-contained cards with their heading inside, while
/// medicines and food logs were a bare heading floating above loose content.
/// Scrolling it felt like scrolling two different screens. One shell, used by
/// all of them, is what makes it read as one page.
///
/// Matches `PanelCard` in the doctor's panel — same radius, same hairline, same
/// shadow — so a patient and their doctor are looking at the same product.
class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.child});

  final Widget child;

  /// Fixed. It was configurable only for the food rail, which bled its cards
  /// to the card wall — and that rail now lives in the Dietician tab.
  static const EdgeInsetsGeometry padding = EdgeInsets.all(AppSpacing.md);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1B33).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A section heading inside a card: the icon on its tinted plate, the title, and
/// an optional action on the right.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// A badge instead of a button — used where the right-hand slot carries a
  /// fact rather than something to tap.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOn(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null)
          trailing!
        // The icon is drawn only where it says something the word does not —
        // "+" for Add, an upload mark for Upload. "View all" was getting a
        // generic arrow purely because the slot existed, and a decoration
        // nobody asked for is what makes a section look cheap.
        else if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (actionIcon != null) ...[
                  Icon(actionIcon, size: 18),
                  const SizedBox(width: 4),
                ],
                Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The four blocks Home opens on.
//
// Measured directly against the reference: a greeting row, one dark focal
// card, a metric strip and a row of soft circular shortcuts. Four blocks, and
// the restraint is the design — the same screen with nine sections reads as a
// list of everything the app can do rather than as a page about today.
// ---------------------------------------------------------------------------

/// Avatar, greeting, name. Small and quiet — the focal card below is the
/// subject, not the header.
class _Greeting extends ConsumerWidget {
  const _Greeting({required this.mood});

  final Mood mood;

  static String _partOfDay() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).user;
    final name = (user?.name ?? '').trim();

    return Row(
      children: [
        GestureDetector(
          onTap: () => context.go('/profile'),
          child: StatusAvatar(
            name: name,
            avatarUrl: user?.avatarUrl,
            role: CareRole.patient,
            gender: user?.gender,
            mood: mood,
            size: 52,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _partOfDay(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name.isEmpty ? 'Welcome' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        // Where the brand bar's bell and avatar used to be. One row now does
        // the job both were doing, and the page starts 66px higher.
        _RoundIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: () => context.push('/profile/notifications'),
        ),
      ],
    );
  }
}

/// The one dark card on the screen, and therefore the thing the eye lands on.
///
/// It carries whichever of two facts is actually pressing: the next dose due
/// today, or — when the day's doses are done — the next clinic visit. A card
/// this prominent has to earn it by being the most useful sentence on the
/// page, not by being the prettiest.
class _FocalCard extends ConsumerWidget {
  const _FocalCard({required this.care});

  final CareSummary care;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots =
        ref.watch(todayScheduleProvider).valueOrNull?.slots ??
        const <MedicationScheduleSlot>[];
    final next = slots.where((s) => s.status == 'pending').firstOrNull;

    final String eyebrow;
    final String headline;
    final String detail;
    // The artwork follows the state. A card that says "all clear" beside a
    // picture of a pill is a card arguing with itself.
    final String art;
    if (next != null) {
      eyebrow = 'Next dose';
      headline = next.time;
      detail = '${next.name}  •  ${next.dose}';
      art = 'dose';
    } else if (care.followUpOn != null) {
      eyebrow = 'Next visit';
      headline = DateFormat('d MMM').format(care.followUpOn!);
      detail = DateFormat('EEEE').format(care.followUpOn!);
      art = 'steth';
    } else {
      eyebrow = 'Today';
      headline = 'All clear';
      detail = 'Nothing due right now';
      art = 'clear';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3E86), Color(0xFF0B1B3A)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassChip(
                  label: eyebrow.toUpperCase(),
                  icon:
                      next != null
                          ? Icons.schedule_rounded
                          : Icons.check_circle_outline_rounded,
                  // The one chip large enough, and on a rich enough panel, for
                  // a real frost to be worth its saveLayer.
                  blur: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 32,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.80),
                  ),
                ),
              ],
            ),
          ),
          // Illustrative rather than decorative: it names the state before
          // the words are read. Crossfaded, so a dose being ticked off does
          // not make the card flicker.
          AnimatedSwitcher(
            duration:
                MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
            child: Image.asset(
              'assets/cards/$art.png',
              key: ValueKey(art),
              width: 96,
              height: 96,
              errorBuilder: (_, _, _) => const SizedBox(width: 96, height: 96),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three numbers, in a row, with nothing else in the card.
class _HealthOverview extends ConsumerWidget {
  const _HealthOverview({required this.care});

  final CareSummary care;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final trends = ref.watch(glucoseTrendsProvider).valueOrNull;
    final latest = (trends?.series ?? const <GlucoseTrendPoint>[]).lastOrNull;
    final bp = care.profile.bloodPressure;

    final items = <({IconData icon, Color tone, String value, String label})>[
      (
        icon: Icons.water_drop_rounded,
        tone: AppColors.danger,
        value: latest == null ? '—' : '${latest.value.round()}',
        label: 'Glucose',
      ),
      (
        icon: Icons.favorite_rounded,
        tone: AppColors.primary,
        value: bp == null ? '—' : '${bp.systolic}/${bp.diastolic}',
        label: 'Blood pressure',
      ),
      (
        icon: Icons.monitor_weight_rounded,
        tone: AppColors.success,
        value: care.profile.bmi == null ? '—' : '${care.profile.bmi}',
        label: 'BMI',
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          for (final it in items) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: it.tone.withValues(alpha: 0.10),
                    ),
                    child: Icon(it.icon, size: 20, color: it.tone),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    it.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    it.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (it != items.last)
              Container(
                width: 1,
                height: 56,
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
          ],
        ],
      ),
    );
  }
}

/// Four shortcuts as line icons in soft circles.
///
/// Illustrated tiles were tried here first and were wrong: the reference uses
/// quiet icons for navigation and spends its pictures elsewhere. Four pieces
/// of artwork at the top of a clinical screen is a poster wall, and it pushed
/// the actual care below the fold.
class _QuickAccess extends StatelessWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <({IconData icon, String label, VoidCallback tap})>[
      (
        icon: Icons.add_chart_rounded,
        label: 'Log sugar',
        tap: () => showLogGlucoseSheet(context),
      ),
      (
        icon: Icons.medication_rounded,
        label: 'Medicines',
        tap: () => context.go('/medications'),
      ),
      (
        icon: Icons.restaurant_menu_rounded,
        label: 'Nutrition',
        tap: () => context.go('/food-log'),
      ),
      (
        icon: Icons.biotech_rounded,
        label: 'Lab tests',
        tap: () => context.push('/profile/tests'),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: Semantics(
                button: true,
                label: it.label,
                child: GestureDetector(
                  onTap: it.tap,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.08),
                        ),
                        child: Icon(
                          it.icon,
                          size: 24,
                          color: AppColors.accentOn(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        it.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The small heading above a card. The reference labels each block, and it is
/// what lets the eye skip to the one it wants instead of reading all of them.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
  );
}

/// A quiet circular icon button, sized for a thumb.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: AppSpacing.minTapTarget,
          height: AppSpacing.minTapTarget,
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerLowest,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Icon(icon, size: 21, color: scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
