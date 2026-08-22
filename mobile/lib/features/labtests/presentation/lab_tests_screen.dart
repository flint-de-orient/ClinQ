import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/data/upload_repository.dart';
import '../../../shared/widgets/authed_image.dart';
import '../../../shared/widgets/auto_refresh.dart';
import '../data/lab_tests_repository.dart';
import '../../chat/domain/chat_message.dart';
import '../../chat/presentation/widgets/chat_document_card.dart';
import '../domain/lab_tests.dart';
import 'lab_tests_providers.dart';

/// The tests the doctor advised and the reports the patient uploads against
/// them. A report is a photo of the printed result.
class LabTestsScreen extends ConsumerStatefulWidget {
  const LabTestsScreen({super.key});

  @override
  ConsumerState<LabTestsScreen> createState() => _LabTestsScreenState();
}

/// Where a report came from. A PDF is the common case — labs email them — and
/// it was the one route the screen did not offer.
enum _Source { document, camera, gallery }

class _LabTestsScreenState extends ConsumerState<LabTestsScreen> {
  final _picker = ImagePicker();
  String? _uploading;

  /// Upload against a test the doctor advised: source, then send.
  ///
  /// One sheet, because the test is already known — this is the row's own
  /// Upload button, not the general one.
  Future<void> _upload(String testName) async {
    final picked = await _pickFile();
    if (picked == null) return;
    await _send(
      testName: testName,
      path: picked.path,
      filename: picked.filename,
    );
  }

  /// Choose a file, from wherever the patient has it. Returns null when they
  /// backed out — nothing has been sent at this point.
  Future<({String path, String filename})?> _pickFile() async {
    final source = await _pickSource();
    if (source == null) return null;

    if (source == _Source.document) {
      // Most lab reports arrive as a PDF by email or WhatsApp. Photographing a
      // phone screen to upload one was the only route before this, and it lost
      // every number on the page.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: false,
      );
      final file = result?.files.singleOrNull;
      if (file?.path == null) return null;
      return (path: file!.path!, filename: file.name);
    }

    final x = await _picker.pickImage(
      source:
          source == _Source.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (x == null) return null;
    return (path: x.path, filename: x.name);
  }

  /// Send the chosen file, tagged with the test it answers.
  Future<void> _send({
    required String testName,
    required String path,
    required String filename,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _uploading = testName);
    try {
      final asset = await ref
          .read(uploadRepositoryProvider)
          .uploadImage(path: path, filename: filename);
      await ref
          .read(labTestsRepositoryProvider)
          .upload(testName: testName, photo: asset.id);
      ref.invalidate(labTestsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('$testName report uploaded')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<_Source?> _pickSource() {
    return showModalBottomSheet<_Source>(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text('PDF or document'),
                  subtitle: const Text('The report your lab emailed you'),
                  onTap: () => Navigator.pop(ctx, _Source.document),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(ctx, _Source.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(ctx, _Source.gallery),
                ),
              ],
            ),
          ),
    );
  }

  /// Removes a report uploaded by mistake — the wrong photo, the wrong
  /// person's report, the same page twice. Confirmed first, because the values
  /// the clinic read off it go with it.
  Future<void> _delete(LabResult r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Delete this ${r.testName} report?'),
            content: const Text(
              'It is removed from your record, along with any readings the clinic '
              'took from it. You can upload the correct file afterwards.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(labTestsRepositoryProvider).delete(r.id);
      ref.invalidate(labTestsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Report deleted')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Upload a report the doctor did not specifically advise.
  ///
  /// File first, then name it. It used to ask "which test?" in a dialog, then
  /// open a second sheet for the source — two hurdles before anything happened,
  /// and the name was demanded before the patient had even found the file.
  ///
  /// Nothing is sent until the name is confirmed. Uploading first and tagging
  /// afterwards would be fewer taps, but a patient who backs out at the tag
  /// leaves a file on the server belonging to no test, and nobody ever goes
  /// looking for those.
  Future<void> _uploadOther() async {
    final picked = await _pickFile();
    if (picked == null || !mounted) return;

    final name = await _askTestName(picked.filename);
    if (name == null || name.trim().isEmpty) return;

    await _send(
      testName: name.trim(),
      path: picked.path,
      filename: picked.filename,
    );
  }

  /// The test name, asked once, with the doctor's advised list one tap away.
  ///
  /// Most uploads answer a test the doctor already asked for, so those are
  /// chips rather than something to spell — and a lab report's name is exactly
  /// the sort of thing that gets typed three different ways.
  Future<String?> _askTestName(String filename) {
    final controller = TextEditingController();
    final advised =
        ref.read(labTestsProvider).valueOrNull?.advised ?? const <String>[];

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (ctx) => Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.lg,
            ),
            child: StatefulBuilder(
              builder:
                  (ctx, setSheet) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Which test is this?',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // The chosen file, named. Confirms the right one was picked
                      // before it goes anywhere.
                      Row(
                        children: [
                          Icon(
                            Icons.insert_drive_file_outlined,
                            size: 16,
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              filename,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    Theme.of(ctx).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (advised.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'ASKED FOR BY YOUR DOCTOR',
                          style: _label(Theme.of(ctx).colorScheme),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final t in advised)
                              ActionChip(
                                label: Text(t),
                                onPressed: () => Navigator.pop(ctx, t),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: controller,
                        autofocus: advised.isEmpty,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setSheet(() {}),
                        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
                        decoration: const InputDecoration(
                          labelText: 'Or type the test name',
                          hintText: 'e.g. HbA1c, Lipid profile',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed:
                              controller.text.trim().isEmpty
                                  ? null
                                  : () => Navigator.pop(
                                    ctx,
                                    controller.text.trim(),
                                  ),
                          child: const Text('Upload'),
                        ),
                      ),
                    ],
                  ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(labTestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My tests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadOther,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Upload report'),
      ),
      // A freshly uploaded report says "Reading your report…" while the server
      // transcribes it. Without a poll that line stayed there until the patient
      // thought to pull down — which is exactly when they would conclude it had
      // not worked.
      body: AutoRefresh(
        onTick: (ref) => ref.invalidate(labTestsProvider),
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(labTestsProvider),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (_, _) => ListView(
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                    const Center(child: Text('Could not load your tests')),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: OutlinedButton(
                        onPressed: () => ref.invalidate(labTestsProvider),
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
            data:
                (view) => ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    // Clears the extended FAB (48) plus its margin (16) with
                    // room left for the label growing under a large text
                    // scale — at 96 the last row sat under the button.
                    128,
                  ),
                  children: [
                    Text('ADVISED BY YOUR DOCTOR', style: _label(scheme)),
                    const SizedBox(height: AppSpacing.sm),
                    if (view.advised.isEmpty)
                      _note(
                        scheme,
                        'No tests advised yet. Your doctor will add them when they prescribe.',
                      )
                    else
                      Container(
                        decoration: _cardBox(scheme),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < view.advised.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              _AdvisedRow(
                                test: view.advised[i],
                                done: view.hasResultFor(view.advised[i]),
                                uploading: _uploading == view.advised[i],
                                onUpload: () => _upload(view.advised[i]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    Text('UPLOADED REPORTS', style: _label(scheme)),
                    const SizedBox(height: AppSpacing.sm),
                    if (view.results.isEmpty)
                      _note(
                        scheme,
                        'Reports you upload appear here — your doctor and dietician can see them.',
                      )
                    else
                      for (final r in view.results) ...[
                        _ResultCard(result: r, onDelete: () => _delete(r)),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                  ],
                ),
          ),
        ),
      ),
    );
  }

  TextStyle _label(ColorScheme scheme) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: scheme.onSurfaceVariant,
  );

  BoxDecoration _cardBox(ColorScheme scheme) => BoxDecoration(
    color: scheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
  );

  Widget _note(ColorScheme scheme, String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: _cardBox(scheme),
    child: Text(
      text,
      style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
    ),
  );
}

class _AdvisedRow extends StatelessWidget {
  const _AdvisedRow({
    required this.test,
    required this.done,
    required this.uploading,
    required this.onUpload,
  });

  final String test;
  final bool done;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.biotech_outlined,
            size: 20,
            color: done ? AppColors.success : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              test,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          if (uploading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 16,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: onUpload,
              child: Text(done ? 'Re-upload' : 'Upload'),
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onDelete});

  final LabResult result;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only a picture gets a thumbnail. Drawing a PDF through the image
          // loader is what produced the broken-thumbnail box; documents get a
          // file card below instead.
          if (result.hasFile && result.isImage)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: AuthedImage(
                path: result.photoUrl!,
                width: 56,
                height: 56,
                radius: 10,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        result.testName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (result.createdAt != null)
                      Text(
                        DateFormat('d MMM').format(result.createdAt!),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    // Uploading the wrong page is easy and, once read, it moves
                    // the patient's own record — so removing it has to be as
                    // easy as adding it was.
                    IconButton(
                      tooltip: 'Delete this report',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.only(left: 4),
                      constraints: const BoxConstraints(),
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (result.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(result.note, style: const TextStyle(fontSize: 14)),
                ],
                // What the clinic read off the report. Shown to the patient in
                // the report's own words, never as advice — the numbers go to
                // their record, the meaning comes from their doctor.
                if (result.isReading) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reading your report…',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ] else if (result.analysisSummary?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          result.couldNotRead
                              ? AppColors.warningBgOn(context)
                              : AppColors.accentSoftOn(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      result.analysisSummary!,
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                  if (result.abnormal.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Flagged on the report: ${result.abnormal.join(', ')}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warningOn(context),
                      ),
                    ),
                  ],
                ],
                // PDFs, Word files, anything that is not a picture. The same
                // card the chat uses, so it downloads with the bearer token
                // (the file is owner-protected — a plain open would 403) and
                // hands off to the phone's own viewer.
                if (result.hasFile && !result.isImage) ...[
                  const SizedBox(height: 8),
                  ChatDocumentCard(
                    doc: DocumentAttachment(
                      url: result.photoUrl!,
                      name:
                          result.originalName?.isNotEmpty == true
                              ? result.originalName!
                              : '${result.testName} report',
                      mimeType: result.mimeType,
                      sizeBytes: result.sizeBytes,
                    ),
                    onDark: false,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
