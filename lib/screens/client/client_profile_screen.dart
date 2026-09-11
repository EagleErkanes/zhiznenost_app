import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/error_handler.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../auth/login_screen.dart';

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController(); // Коригирано с долна черта

  String? _selectedGender;
  String? _selectedGoal;
  String _email = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;

  static const List<String> _genders = ['Мъж', 'Жена'];
  static const List<String> _goals = [
    'Обща кондиция',
    'Подобряване на стойката',
    'Намаляване на тегло',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _dbService.getCurrentUserProfile().timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw TimeoutException('Връзката прекъсна.'),
      );
      if (profile != null && mounted) {
        setState(() {
          _email = profile.email;
          _nameController.text = profile.fullName;
          _selectedGender = profile.gender;
          _ageController.text = profile.age != null ? profile.age.toString() : '';
          _heightController.text = profile.height != null ? profile.height.toString() : '';
          _weightController.text = profile.weight != null ? profile.weight.toString() : '';
          _selectedGoal = profile.goal;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              getHumanReadableError(e),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final ageText = _ageController.text.trim();
      final heightText = _heightController.text.trim().replaceAll(',', '.');
      final weightText = _weightController.text.trim().replaceAll(',', '.');

      final age = ageText.isNotEmpty ? int.tryParse(ageText) : null;
      final height = heightText.isNotEmpty ? double.tryParse(heightText) : null;
      final weight = weightText.isNotEmpty ? double.tryParse(weightText) : null;

      await _dbService
          .updateClientProfile(
        fullName: _nameController.text.trim(),
        gender: _selectedGender,
        age: age,
        height: height,
        weight: weight,
        goal: _selectedGoal,
      )
          .timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw TimeoutException('Връзката прекъсна.'),
      );

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Профилът е успешно обновен!'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            getHumanReadableError(e),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleSignOut() async {
    final navigator = Navigator.of(context);
    try {
      await _authService.signOut();
    } catch (_) {}

    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void _confirmDeleteAccount() {
    FocusScope.of(context).unfocus();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Изтриване на профила?',
                  style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: const Text(
            'Това действие е окончателно и необратимо. Вашият акаунт, тренировъчни дневници, резултати и активни карти ще бъдат напълно премахнати.',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Отказ', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                minimumSize: const Size(110, 42),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _performAccountDeletion();
              },
              child: const Text('Изтрий профила', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performAccountDeletion() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isDeleting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await Supabase.instance.client
          .rpc('delete_user_account')
          .timeout(const Duration(seconds: 5));

      await _authService.signOut();

      if (!mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Вашият профил и данни бяха напълно изтрити.'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(getHumanReadableError(e)),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 68,
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Image.asset(
                  'assets/images/logo_icon.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center, color: AppColors.primaryGreen, size: 30),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ЖИЗНЕНОСТ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'МОЯТ ПРОФИЛ',
                    style: TextStyle(
                      fontSize: 9.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.primaryGreen,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: _loadProfileData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            onPressed: _handleSignOut,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading || _isDeleting
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0x3376C043),
                      child: Icon(Icons.person_rounded, color: AppColors.primaryGreen, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Регистриран акаунт',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _email.isNotEmpty ? _email : 'Няма данни',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Лична и физическа информация',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Име и фамилия',
                  prefixIcon: Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Моля, въведете име.' : null,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField(
                      isExpanded: true,
                      value: _selectedGender,
                      dropdownColor: AppColors.cardDark,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Пол',
                        prefixIcon: Icon(Icons.wc_outlined, color: AppColors.textSecondary),
                      ),
                      items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (val) => setState(() => _selectedGender = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: AppColors.textPrimary),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Възраст (г.)',
                        prefixIcon: Icon(Icons.cake_outlined, color: AppColors.textSecondary),
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final parsed = int.tryParse(val.trim());
                          if (parsed == null || parsed < 10 || parsed > 100) {
                            return '10 - 100 г.';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppColors.textPrimary),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Ръст (см)',
                        prefixIcon: Icon(Icons.height_rounded, color: AppColors.textSecondary),
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final parsed = double.tryParse(val.trim().replaceAll(',', '.'));
                          if (parsed == null || parsed < 100 || parsed > 250) {
                            return '100 - 250 см';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController, // Коригирано с долна черта
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppColors.textPrimary),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).unfocus();
                      },
                      decoration: const InputDecoration(
                        labelText: 'Тегло (кг)',
                        prefixIcon: Icon(Icons.monitor_weight_outlined, color: AppColors.textSecondary),
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          final parsed = double.tryParse(val.trim().replaceAll(',', '.'));
                          if (parsed == null || parsed < 30 || parsed > 300) {
                            return '30 - 300 кг';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Основна тренировъчна цел',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField(
                value: _selectedGoal,
                dropdownColor: AppColors.cardDark,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Изберете фокус (по избор)',
                  prefixIcon: Icon(Icons.flag_outlined, color: AppColors.textSecondary),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Без посочена цел', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  ..._goals.map((goal) => DropdownMenuItem(value: goal, child: Text(goal))),
                ],
                onChanged: (val) => setState(() => _selectedGoal = val),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                )
                    : const Text('Запази промените'),
              ),
              const SizedBox(height: 32),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.errorRed.withAlpha(200),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 20),
                  label: const Text(
                    'Изтрий профила и данните ми',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: _confirmDeleteAccount,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}