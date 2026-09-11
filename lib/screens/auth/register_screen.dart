import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _coachSecretCodeController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final AuthService _authService = AuthService();

  String _selectedRole = 'client';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureSecretCode = true;
  bool _isPasswordFocused = false;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  static const String _coachSecretCode = 'ZHIZNENOST_COACH_2026';

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordRules);
    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });
  }

  void _validatePasswordRules() {
    final pass = _passwordController.text;
    setState(() {
      _hasMinLength = pass.length >= 8;
      _hasUppercase = pass.contains(RegExp(r'[A-Z]'));
      _hasNumber = pass.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]'));
    });
  }

  bool get _isPasswordValid =>
      _hasMinLength && _hasUppercase && _hasNumber && _hasSpecialChar;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.removeListener(_validatePasswordRules);
    _passwordController.dispose();
    _coachSecretCodeController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Моля, въведете имейл адрес';
    }
    final email = value.trim().toLowerCase();
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Моля, въведете валиден имейл формат';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (!_formKey.currentState!.validate()) return;

    if (!_isPasswordValid) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Моля, изпълнете всички изисквания за сигурност на паролата.'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedRole == 'coach') {
      final enteredCode = _coachSecretCodeController.text.trim();
      if (enteredCode != _coachSecretCode) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Невалиден секретен код за треньор! Достъпът е отказан.'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    final emailTrimmed = _emailController.text.trim().toLowerCase();

    try {
      // 1. Предварителна проверка дали имейлът съществува
      try {
        final existingUser = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .ilike('email', emailTrimmed)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));

        if (existingUser != null) {
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Вече съществува профил с този имейл адрес! Влезте от екрана за вход.'),
              backgroundColor: AppColors.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      } catch (_) {
        // Ако RLS блокира анонимното четене, разчитаме на валидацията при signUp
      }

      // 2. Регистрация в Supabase с тайм-аут
      final response = await _authService.signUp(
        email: emailTrimmed,
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        role: _selectedRole,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Връзката прекъсна.'),
      );

      // 3. Проверка за празен списък идентичности
      if (response.user?.identities != null && response.user!.identities!.isEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Вече съществува профил с този имейл адрес!'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Успешна регистрация! Изпратихме имейл за потвърждение. Отворете пощата си, потвърдете акаунта и се върнете за вход.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 6),
        ),
      );

      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;

      String message;
      final rawError = e.message.toLowerCase();

      if (rawError.contains('already registered') ||
          rawError.contains('user_already_exists') ||
          rawError.contains('already in use')) {
        message = 'Вече съществува профил с този имейл адрес.';
      } else if (rawError.contains('socketexception') ||
          rawError.contains('failed host lookup') ||
          rawError.contains('clientexception') ||
          rawError.contains('network')) {
        message = 'Няма връзка с интернет. Моля, проверете мрежата си.';
      } else {
        message = 'Грешка при регистрация: ${e.message}';
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String errorMsg = 'Възникна неочаквана грешка. Моля, опитайте отново.';
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('socketexception') ||
          errorStr.contains('failed host lookup') ||
          errorStr.contains('clientexception') ||
          errorStr.contains('os error') ||
          errorStr.contains('timeout')) {
        errorMsg = 'Няма връзка с интернет. Моля, проверете мрежата си.';
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildRuleItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isMet ? AppColors.primaryGreen : AppColors.errorRed,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? AppColors.primaryGreen : AppColors.textSecondary,
              fontWeight: isMet ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryGreen.withAlpha(76),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 32,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Нова регистрация',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Попълнете данните, за да създадете профил',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _fullNameController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Име и фамилия',
                      prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Моля, въведете име и фамилия';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Имейл',
                      prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Парола',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),

                  if (_isPasswordFocused) ...[
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isPasswordValid
                              ? AppColors.primaryGreen.withAlpha(128)
                              : Colors.white12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Изисквания за паролата:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildRuleItem('Поне 8 символа', _hasMinLength),
                          _buildRuleItem('Поне 1 главна буква (A-Z)', _hasUppercase),
                          _buildRuleItem('Поне 1 цифра (0-9)', _hasNumber),
                          _buildRuleItem('Поне 1 специален символ (!@#\$%^&*...)', _hasSpecialChar),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Text(
                    'Тип потребител:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _selectedRole == 'client'
                                ? AppColors.primaryGreen
                                : AppColors.cardDark,
                            side: BorderSide(
                              color: _selectedRole == 'client'
                                  ? AppColors.primaryGreen
                                  : Colors.transparent,
                            ),
                          ),
                          onPressed: () => setState(() => _selectedRole = 'client'),
                          child: Text(
                            'Клиент',
                            style: TextStyle(
                              color: _selectedRole == 'client'
                                  ? Colors.black
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _selectedRole == 'coach'
                                ? AppColors.primaryGreen
                                : AppColors.cardDark,
                            side: BorderSide(
                              color: _selectedRole == 'coach'
                                  ? AppColors.primaryGreen
                                  : Colors.transparent,
                            ),
                          ),
                          onPressed: () => setState(() => _selectedRole = 'coach'),
                          child: Text(
                            'Треньор',
                            style: TextStyle(
                              color: _selectedRole == 'coach'
                                  ? Colors.black
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_selectedRole == 'coach') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _coachSecretCodeController,
                      obscureText: _obscureSecretCode,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Секретен код за треньор',
                        hintText: 'Въведете предоставения код',
                        prefixIcon: const Icon(Icons.security, color: AppColors.primaryGreen),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureSecretCode ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() => _obscureSecretCode = !_obscureSecretCode);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (_selectedRole == 'coach' && (value == null || value.trim().isEmpty)) {
                          return 'Въведете код за достъп като треньор';
                        }
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                        : const Text('Регистрирай се'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}