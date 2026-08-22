import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/database/data_provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/ui/theme.dart';

class BugCreateScreen extends StatefulWidget {
  const BugCreateScreen({super.key});

  @override
  State<BugCreateScreen> createState() => _BugCreateScreenState();
}

class _BugCreateScreenState extends State<BugCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _stepsController = TextEditingController();
  final _expectedController = TextEditingController();
  final _actualController = TextEditingController();
  final _envController = TextEditingController();

  String _severity = 'medium';
  String? _selectedProjectId;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _stepsController.dispose();
    _expectedController.dispose();
    _actualController.dispose();
    _envController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final dataProvider = Provider.of<DataProvider>(context, listen: false);

    final userId = authProvider.user?.uid ?? 'unknown';

    final success = await dataProvider.createBug(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      severity: _severity,
      projectId: _selectedProjectId,
      reporterId: userId,
      stepsToReproduce: _stepsController.text.trim().isEmpty
          ? null
          : _stepsController.text.trim(),
      expectedBehavior: _expectedController.text.trim().isEmpty
          ? null
          : _expectedController.text.trim(),
      actualBehavior: _actualController.text.trim().isEmpty
          ? null
          : _actualController.text.trim(),
      environment: _envController.text.trim().isEmpty
          ? null
          : _envController.text.trim(),
    );

    setState(() => _submitting = false);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chyba bola úspešne nahlásená'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nahlásenie chyby zlyhalo'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final projects = dataProvider.projects;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Nahlásiť chybu',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nová chyba',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Vyplňte formulár pre nahlásenie nového problému v systéme.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 24),

              // Glassmorphic container for the form
              Container(
                decoration: AppTheme.glassDecoration(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    _buildLabel('Názov chyby *'),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: _buildInputDecoration(
                        'Stručný popis problému...',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Názov je povinný'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    _buildLabel('Popis chyby *'),
                    TextFormField(
                      controller: _descController,
                      maxLines: 4,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: _buildInputDecoration(
                        'Detailný popis chyby, čo sa deje...',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Popis je povinný'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Dropdowns row (Project & Severity)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Projekt'),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedProjectId,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                                dropdownColor: const Color(0xFF1E1E22),
                                decoration: _buildInputDecoration(
                                  'Vybrať projekt',
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      'Bez projektu',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  ...projects.map(
                                    (p) => DropdownMenuItem<String>(
                                      value: p.id,
                                      child: Text(
                                        p.name,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (val) =>
                                    setState(() => _selectedProjectId = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Závažnosť *'),
                              DropdownButtonFormField<String>(
                                initialValue: _severity,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                                dropdownColor: const Color(0xFF1E1E22),
                                decoration: _buildInputDecoration('Závažnosť'),
                                items: AppTheme.severityLabels.entries.map((e) {
                                  return DropdownMenuItem<String>(
                                    value: e.key,
                                    child: Text(
                                      e.value,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) =>
                                    setState(() => _severity = val ?? 'medium'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Optional technical fields title
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Technické detaily (Voliteľné)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),

              // Optional fields container
              Container(
                decoration: AppTheme.glassDecoration(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Steps to reproduce
                    _buildLabel('Kroky na reprodukciu'),
                    TextFormField(
                      controller: _stepsController,
                      maxLines: 3,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: _buildInputDecoration(
                        '1. Prejdite na...\n2. Kliknite na...',
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Očakávané správanie'),
                              TextFormField(
                                controller: _expectedController,
                                maxLines: 2,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                                decoration: _buildInputDecoration(
                                  'Čo sa malo stať...',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Skutočné správanie'),
                              TextFormField(
                                controller: _actualController,
                                maxLines: 2,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                                decoration: _buildInputDecoration(
                                  'Čo sa naozaj stalo...',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Environment
                    _buildLabel('Prostredie / Zariadenie'),
                    TextFormField(
                      controller: _envController,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: _buildInputDecoration(
                        'napr. Chrome v120, iOS 17.2, staging...',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Zrušiť',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Odoslať chybu',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0x35FFFFFF), fontSize: 12),
      filled: true,
      fillColor: const Color(0x05FFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0x12FFFFFF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0x12FFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primary),
      ),
    );
  }
}
