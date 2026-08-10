import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/ui/theme.dart';
import '../../core/config/config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _jobController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController = TextEditingController(text: auth.profile?.fullName ?? '');
    _jobController = TextEditingController(text: auth.profile?.jobTitle ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jobController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final success = await auth.updateUserProfile(
      _nameController.text.trim(),
      _jobController.text.trim(),
    );

    setState(() => _saving = false);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil úspešne uložený'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nepodarilo sa uložiť profil'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nastavenia',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Spravujte svoj profil a skontrolujte konfiguráciu systémových integrácií.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 24),

              // Profile Section Card
              _buildSectionHeader('Môj profil'),
              Container(
                decoration: AppTheme.glassDecoration(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email (disabled)
                    _buildLabel('Prihlasovací e-mail'),
                    TextFormField(
                      initialValue: user?.email ?? '',
                      enabled: false,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      decoration: _buildInputDecoration(
                        '',
                      ).copyWith(fillColor: const Color(0x02FFFFFF)),
                    ),
                    const SizedBox(height: 16),

                    // Full name
                    _buildLabel('Celé meno *'),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: _buildInputDecoration('Meno a priezvisko...'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Meno je povinné'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Job Title
                    _buildLabel('Pracovná pozícia'),
                    TextFormField(
                      controller: _jobController,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: _buildInputDecoration(
                        'napr. Senior Developer, QA Tester...',
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(LucideIcons.save, size: 14),
                          label: const Text(
                            'Uložiť zmeny',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _saving ? null : _saveProfile,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // System integrations status
              _buildSectionHeader('Systémové integrácie'),
              Container(
                decoration: AppTheme.glassDecoration(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildStatusRow(
                      'Firebase Auth & Services',
                      AppConfig.firebaseApiKey.isNotEmpty,
                      'Priradené API: ${AppConfig.firebaseProjectId}',
                    ),
                    const Divider(color: Color(0x10FFFFFF), height: 24),
                    _buildStatusRow(
                      'Supabase Postgres & Realtime',
                      AppConfig.supabaseUrl.isNotEmpty,
                      'Endpoint: ${AppConfig.supabaseUrl}',
                    ),
                    const Divider(color: Color(0x10FFFFFF), height: 24),
                    _buildStatusRow(
                      'WordPress REST Gateway',
                      AppConfig.wordpressPublicSiteUrl.isNotEmpty,
                      AppConfig.wordpressPublicSiteUrl.isNotEmpty
                          ? 'Portal URL: ${AppConfig.wordpressPublicSiteUrl}'
                          : 'WP Integrácia nie je nastavená',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 2.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0x05FFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primary),
      ),
    );
  }

  Widget _buildStatusRow(String service, bool active, String desc) {
    return Row(
      children: [
        Icon(
          active ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
          color: active ? AppTheme.success : AppTheme.error,
          size: 20,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.success.withValues(alpha: 0.1)
                : AppTheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            active ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: active ? AppTheme.success : AppTheme.error,
            ),
          ),
        ),
      ],
    );
  }
}
