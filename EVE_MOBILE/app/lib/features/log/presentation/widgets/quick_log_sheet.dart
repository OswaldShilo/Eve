import 'package:flutter/material.dart';
import 'package:eve_app/core/theme/eve_theme.dart';
import 'package:eve_app/shared/widgets/eve_components.dart';

class QuickLogResult {
  const QuickLogResult({required this.mood, required this.symptoms, required this.painLevel, required this.notes});

  final String? mood;
  final List<String> symptoms;
  final int painLevel;
  final String notes;
}

/// The "new entry" bottom sheet: mood, symptoms, pain and notes, in the
/// mock's outlined style. Lifts above the soft keyboard, and keeps the
/// entry (with an inline message) when saving fails.
class QuickLogSheet extends StatefulWidget {
  const QuickLogSheet({super.key, required this.onSave});

  /// Completes when the entry is saved; throws when it could not be.
  final Future<void> Function(QuickLogResult result) onSave;

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  static const _moods = {'Great': 'great', 'Good': 'good', 'Okay': 'okay', 'Low': 'low', 'Difficult': 'difficult'};
  static const _symptoms = ['Cramps', 'Headache', 'Bloating', 'Fatigue', 'Back pain', 'Nausea'];

  String? _mood;
  final _selectedSymptoms = <String>{};
  double _pain = 0;
  final _notes = TextEditingController();
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.onSave(
        QuickLogResult(
          mood: _mood,
          symptoms: _symptoms.where(_selectedSymptoms.contains).toList(),
          painLevel: _pain.round(),
          notes: _notes.text.trim(),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      // Lift the whole sheet above the soft keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The fields scroll; the error and Save below stay pinned, so Save
          // is always reachable above the keyboard.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('How are you feeling today?', style: text.headlineSmall),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in _moods.entries)
                        EveChip(
                          label: entry.key,
                          size: EveChipSize.regular,
                          selected: _mood == entry.value,
                          onTap: () => setState(() => _mood = entry.value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const EveFormLabel('Symptoms'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final symptom in _symptoms)
                        EveChip(
                          label: symptom,
                          size: EveChipSize.regular,
                          selected: _selectedSymptoms.contains(symptom),
                          onTap: () => setState(
                            () => _selectedSymptoms.contains(symptom)
                                ? _selectedSymptoms.remove(symptom)
                                : _selectedSymptoms.add(symptom),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  EveFormLabel('Pain level: ${_pain.round()} of 10'),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: EveColors.rubyMain,
                      inactiveTrackColor: EveColors.progressTrack,
                      thumbColor: EveColors.rubyMain,
                      overlayColor: EveColors.rubyMain.withValues(alpha: 0.12),
                    ),
                    child: Slider(
                      value: _pain,
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: '${_pain.round()}',
                      onChanged: (v) => setState(() => _pain = v),
                    ),
                  ),
                  EveTextField(label: 'Notes (optional)', controller: _notes, maxLines: 2),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_failed) ...[
                  Text(
                    'Your entry was not saved. Check your connection, then tap Try again.',
                    key: const Key('quick-log-error'),
                    style: text.labelMedium!.copyWith(color: EveColors.rubyMain),
                  ),
                  const SizedBox(height: 10),
                ],
                EveButton(
                  key: const Key('quick-log-save'),
                  label: _failed ? 'Try again' : 'Save',
                  busy: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
