import 'package:flutter/material.dart';

class QuickLogResult {
  const QuickLogResult({required this.mood, required this.symptoms, required this.painLevel, required this.notes});

  final String? mood;
  final List<String> symptoms;
  final int painLevel;
  final String notes;
}

class QuickLogSheet extends StatefulWidget {
  const QuickLogSheet({super.key, required this.onSave});

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

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(QuickLogResult(
      mood: _mood,
      symptoms: _symptoms.where(_selectedSymptoms.contains).toList(),
      painLevel: _pain.round(),
      notes: _notes.text.trim(),
    ));
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How are you feeling today?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in _moods.entries)
              ChoiceChip(
                label: Text(entry.key),
                selected: _mood == entry.value,
                onSelected: (_) => setState(() => _mood = entry.value),
              ),
          ]),
          const SizedBox(height: 16),
          const Text('Symptoms', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final symptom in _symptoms)
              FilterChip(
                label: Text(symptom),
                selected: _selectedSymptoms.contains(symptom),
                onSelected: (on) => setState(() => on ? _selectedSymptoms.add(symptom) : _selectedSymptoms.remove(symptom)),
              ),
          ]),
          const SizedBox(height: 16),
          Text('Pain level: ${_pain.round()} of 10', style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(value: _pain, min: 0, max: 10, divisions: 10, onChanged: (v) => setState(() => _pain = v)),
          TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)'), maxLines: 2),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _saving ? null : _save, child: const Text('Save')),
          ),
        ],
      ),
    );
  }
}
