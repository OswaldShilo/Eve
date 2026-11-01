// EVE_MOBILE/app/lib/features/home/presentation/screens/doctor_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DoctorSummaryScreen extends StatefulWidget {
  const DoctorSummaryScreen({super.key, required this.logs, required this.generateSummary});

  final List<Map<String, dynamic>> logs;
  final Future<String> Function(List<Map<String, dynamic>> logs) generateSummary;

  @override
  State<DoctorSummaryScreen> createState() => _DoctorSummaryScreenState();
}

class _DoctorSummaryScreenState extends State<DoctorSummaryScreen> {
  String? _summary;
  String? _error;
  bool _loading = false;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await widget.generateSummary(widget.logs);
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not generate the summary. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPdf() async {
    final summary = _summary;
    if (summary == null) return;

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('EVE Doctor-Ready Summary', style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text(summary),
            ],
          ),
        ),
      ),
    );

    await Printing.sharePdf(bytes: await doc.save(), filename: 'eve-doctor-summary.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor-Ready Summary')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_summary == null && !_loading)
              ElevatedButton(
                key: const Key('generate-summary-button'),
                onPressed: widget.logs.isEmpty ? null : _generate,
                child: Text(widget.logs.isEmpty ? 'No logs to summarize yet' : 'Generate Summary'),
              ),
            if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            if (_error != null)
              Text(_error!, key: const Key('summary-error-text'), style: const TextStyle(color: Colors.red)),
            if (_summary != null) ...[
              Expanded(child: SingleChildScrollView(child: Text(_summary!, key: const Key('summary-text')))),
              const SizedBox(height: 12),
              ElevatedButton(
                key: const Key('export-pdf-button'),
                onPressed: _exportPdf,
                child: const Text('Export as PDF'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
