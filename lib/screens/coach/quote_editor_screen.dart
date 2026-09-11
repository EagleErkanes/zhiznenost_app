import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/database_service.dart';

class QuoteEditorScreen extends StatefulWidget {
  const QuoteEditorScreen({super.key});

  @override
  State<QuoteEditorScreen> createState() => _QuoteEditorScreenState();
}

class _QuoteEditorScreenState extends State<QuoteEditorScreen> {
  final DatabaseService _dbService = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  final _quoteController = TextEditingController();
  final _authorController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentQuote();
  }

  Future<void> _loadCurrentQuote() async {
    final quote = await _dbService.getMotivationalQuote();
    if (mounted) {
      setState(() {
        _quoteController.text = quote['text'] ?? '';
        _authorController.text = quote['author'] ?? '';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _quoteController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _saveQuote() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus(); // Затваряме клавиатурата контролирано преди старт на записа
    setState(() => _isSaving = true);
    final scaffold = ScaffoldMessenger.of(context);

    try {
      await _dbService.updateMotivationalQuote(
        _quoteController.text.trim(),
        _authorController.text.trim(),
      );
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Мотивацията на деня е обновена успешно!'),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Грешка при запис: $e'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('РЕДАКТИРАНЕ НА МОТИВАЦИЯ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Този текст ще се показва на началния екран на всички Ваши клиенти.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _quoteController,
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary),
                textInputAction: TextInputAction.next, // Слиза на следващото поле
                decoration: const InputDecoration(
                  labelText: 'Текст на посланието',
                  hintText: 'Въведете вдъхновяващ текст...',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Полето не може да бъде празно' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _authorController,
                style: const TextStyle(color: AppColors.textPrimary),
                textInputAction: TextInputAction.done, // Последно поле
                // ОПРАВЕНО: Заменено от 'onSubmitted' на 'onFieldSubmitted'
                onFieldSubmitted: (_) {
                  FocusScope.of(context).unfocus(); // Скрива софтуерната клавиатура
                },
                decoration: const InputDecoration(
                  labelText: 'Подпис / Автор',
                  hintText: 'Напр. Алекс - Жизненост',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Посочете автор' : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveQuote,
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
                    : const Text('Публикувай за клиентите'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
