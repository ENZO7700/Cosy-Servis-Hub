import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/ui/theme.dart';
import '../../app/router.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKeyLogin = GlobalKey<FormState>();
  final _formKeySignup = GlobalKey<FormState>();

  final _emailLoginController = TextEditingController();
  final _passwordLoginController = TextEditingController();

  final _nameSignupController = TextEditingController();
  final _emailSignupController = TextEditingController();
  final _passwordSignupController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailLoginController.dispose();
    _passwordLoginController.dispose();
    _nameSignupController.dispose();
    _emailSignupController.dispose();
    _passwordSignupController.dispose();
    super.dispose();
  }

  void _showToast(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKeyLogin.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.signIn(
      _emailLoginController.text.trim(),
      _passwordLoginController.text,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        _showToast(context, 'Vitajte späť!');
      } else {
        _showToast(
          context,
          authProvider.error ?? 'Prihlásenie zlyhalo.',
          isError: true,
        );
      }
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKeySignup.currentState!.validate()) return;

    if (_passwordSignupController.text.length < 6) {
      _showToast(context, 'Heslo musí mať aspoň 6 znakov.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.signUp(
      _emailSignupController.text.trim(),
      _passwordSignupController.text,
      _nameSignupController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        _showToast(context, 'Účet bol úspešne vytvorený.');
      } else {
        _showToast(
          context,
          authProvider.error ?? 'Registrácia zlyhala.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: AppTheme.glassDecoration(
                borderRadius: 16.0,
                bgColor: const Color(0x0CFFFFFF),
                borderColor: const Color(0x1FFFFFFF),
              ),
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo & Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.shield,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'TRIAGE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sleduj, prioritizuj a rieš chyby',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Direct Access Button (Always available)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981), // Emerald green
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(LucideIcons.zap, size: 18),
                      label: const Text(
                        '⚡ PRIAMY VSTUP DO DASHBOARDU',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final router = GoRouter.of(context);
                              setState(() => _isSubmitting = true);
                              final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );
                              await authProvider.signInAsDev();
                              if (!mounted) return;
                              setState(() => _isSubmitting = false);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Prihlásený do Dashboardu!'),
                                  backgroundColor: AppTheme.success,
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              router.go(AppRoutes.crm);
                            },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: Color(0x1FFFFFFF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.g_mobiledata, size: 18),
                      label: const Text(
                        'Pokračovať cez Google',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final router = GoRouter.of(context);
                              setState(() => _isSubmitting = true);
                              final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              );
                              final success = await authProvider.signInWithGoogle();
                              if (!mounted) return;
                              setState(() => _isSubmitting = false);
                              if (success) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Prihlásený cez Google!'),
                                    backgroundColor: AppTheme.success,
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                                router.go(AppRoutes.dashboard);
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(authProvider.error ?? 'Google prihlásenie zlyhalo.'),
                                    backgroundColor: AppTheme.error,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tabs Header
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: const Color(0x1EFFFFFF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0x15FFFFFF)),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: AppTheme.textPrimary,
                      unselectedLabelColor: AppTheme.textSecondary,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: const [
                        Tab(text: 'Prihlásenie'),
                        Tab(text: 'Registrácia'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tab Views
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: SizedBox(
                      height: 260,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Login Form
                          Form(
                            key: _formKeyLogin,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  label: 'E-mail',
                                  controller: _emailLoginController,
                                  placeholder: 'you@example.com',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) =>
                                      (v == null || !v.contains('@'))
                                      ? 'Zadajte platný e-mail'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  label: 'Heslo',
                                  controller: _passwordLoginController,
                                  placeholder: '••••••••',
                                  obscureText: true,
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Zadajte heslo'
                                      : null,
                                ),
                                const Spacer(),
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: _isSubmitting ? null : _handleLogin,
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Prihlásiť sa'),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Signup Form
                          Form(
                            key: _formKeySignup,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  label: 'Celé meno',
                                  controller: _nameSignupController,
                                  placeholder: 'Jana Nováková',
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Meno je povinné'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  label: 'E-mail',
                                  controller: _emailSignupController,
                                  placeholder: 'you@example.com',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) =>
                                      (v == null || !v.contains('@'))
                                      ? 'Zadajte platný e-mail'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  label: 'Heslo',
                                  controller: _passwordSignupController,
                                  placeholder: 'Min. 6 znakov',
                                  obscureText: true,
                                  validator: (v) => (v == null || v.length < 6)
                                      ? 'Heslo musí mať aspoň 6 znakov'
                                      : null,
                                ),
                                const Spacer(),
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: _isSubmitting ? null : _handleSignup,
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Vytvoriť účet'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    '© ${DateTime.now().year} Triage',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            hintText: placeholder,
            hintStyle: const TextStyle(color: Color(0x44FFFFFF), fontSize: 13),
            filled: true,
            fillColor: const Color(0x08FFFFFF),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0x1FFFFFFF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.error, width: 1.2),
            ),
            errorStyle: const TextStyle(fontSize: 11, color: AppTheme.error),
          ),
        ),
      ],
    );
  }
}
