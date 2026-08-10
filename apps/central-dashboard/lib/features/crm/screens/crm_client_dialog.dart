import 'package:flutter/material.dart';
import '../../../core/ui/theme.dart';
import '../models/crm_models.dart';

class CrmClientDialog extends StatefulWidget {
  final CrmClient? client;

  const CrmClientDialog({super.key, this.client});

  @override
  State<CrmClientDialog> createState() => _CrmClientDialogState();
}

class _CrmClientDialogState extends State<CrmClientDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _companyNameController;
  late TextEditingController _contactNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _websiteController;
  late TextEditingController _serviceController;
  late TextEditingController _budgetController;
  late TextEditingController _notesController;

  String _status = 'lead';

  final List<String> _statusOptions = ['lead', 'active', 'inactive'];

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _companyNameController = TextEditingController(text: c?.companyName ?? '');
    _contactNameController = TextEditingController(text: c?.contactName ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _websiteController = TextEditingController(text: c?.website ?? '');
    _serviceController = TextEditingController(
      text: c?.service ?? 'Web Development',
    );
    _budgetController = TextEditingController(text: c?.budget ?? '');
    _notesController = TextEditingController(text: c?.notes ?? '');
    _status = c?.status ?? 'lead';
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _serviceController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.client != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 600),
        decoration: AppTheme.glassDecoration(
          borderRadius: 20,
          bgColor: const Color(0xFF15151A),
          borderColor: Colors.white.withValues(alpha: 0.15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Upraviť klienta' : 'Pridať nového klienta',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),

            // Scrollable Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company Name
                      _buildTextField(
                        controller: _companyNameController,
                        label: 'Názov firmy / klienta *',
                        hint: 'Napr. Acme Corp s.r.o.',
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Názov firmy je povinný';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Contact Person & Service
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _contactNameController,
                              label: 'Kontaktná osoba',
                              hint: 'Napr. Ján Kováč',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _serviceController,
                              label: 'Služba / Projekt *',
                              hint: 'Napr. Web Development',
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Názov služby je povinný';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Email & Phone
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _emailController,
                              label: 'E-mail',
                              hint: 'Napr. info@firma.sk',
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _phoneController,
                              label: 'Telefón',
                              hint: 'Napr. +421 900 123 456',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Website & Budget
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _websiteController,
                              label: 'Webstránka',
                              hint: 'Napr. https://firma.sk',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _budgetController,
                              label: 'Rozpočet (€)',
                              hint: 'Napr. 2500',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Status Selector
                      const Text(
                        'Stav klienta *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _status,
                            dropdownColor: const Color(0xFF1E1E24),
                            isExpanded: true,
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: AppTheme.textSecondary,
                            ),
                            items: _statusOptions.map((status) {
                              String display = status;
                              if (status == 'lead') {
                                display = 'Lead (Potenciálny)';
                              }
                              if (status == 'active') {
                                display = 'Aktívny';
                              }
                              if (status == 'inactive') {
                                display = 'Neaktívny';
                              }
                              return DropdownMenuItem(
                                value: status,
                                child: Text(
                                  display,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _status = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      _buildTextField(
                        controller: _notesController,
                        label: 'Poznámky',
                        hint: 'Detailné informácie, poznámky k projektu...',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),

            // Actions Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                    ),
                    child: const Text('Zrušiť'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _saveForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(isEdit ? 'Uložiť zmeny' : 'Vytvoriť klienta'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.error),
            ),
          ),
        ),
      ],
    );
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      final results = {
        'companyName': _companyNameController.text.trim(),
        'contactName': _contactNameController.text.trim().isEmpty
            ? null
            : _contactNameController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'website': _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        'service': _serviceController.text.trim(),
        'budget': _budgetController.text.trim().isEmpty
            ? null
            : _budgetController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'status': _status,
      };
      Navigator.of(context).pop(results);
    }
  }
}
