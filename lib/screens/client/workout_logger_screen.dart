import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/error_handler.dart';
import '../../models/workout_model.dart';

class WorkoutLoggerScreen extends StatefulWidget {
  const WorkoutLoggerScreen({super.key});

  @override
  State<WorkoutLoggerScreen> createState() => _WorkoutLoggerScreenState();
}

class _WorkoutLoggerScreenState extends State<WorkoutLoggerScreen> {
  final _exerciseController = TextEditingController();
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _notesController = TextEditingController();
  int _rpe = 8;

  final List<WorkoutSet> _currentSets = [];
  List<WorkoutEntry> _pastWorkouts = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  @override
  void dispose() {
    _exerciseController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkouts() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final res = await Supabase.instance.client
          .from('workouts')
          .select()
          .eq('client_id', userId)
          .order('created_at', ascending: false)
          .timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw TimeoutException('Връзката прекъсна.'),
      );

      if (mounted) {
        setState(() {
          _pastWorkouts = (res as List).map((m) => WorkoutEntry.fromMap(m)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addSet() {
    final exerciseName = _exerciseController.text.trim();
    if (exerciseName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Моля, първо въведете име на упражнението!'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final reps = int.tryParse(_repsController.text.trim());
    if (reps == null || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Въведете валиден брой повторения (поне 1)!'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final weight = double.tryParse(_weightController.text.trim().replaceAll(',', '.')) ?? 0.0;

    setState(() {
      _currentSets.add(WorkoutSet(
        setNumber: _currentSets.length + 1,
        weight: weight,
        reps: reps,
        rpe: _rpe,
      ));
    });
  }

  void _removeSet(int index) {
    setState(() {
      _currentSets.removeAt(index);
      for (int i = 0; i < _currentSets.length; i++) {
        _currentSets[i] = WorkoutSet(
          setNumber: i + 1,
          weight: _currentSets[i].weight,
          reps: _currentSets[i].reps,
          rpe: _currentSets[i].rpe,
        );
      }
    });
  }

  void _copyWorkout(WorkoutEntry entry) {
    FocusScope.of(context).unfocus();
    setState(() {
      _exerciseController.text = entry.exerciseName;
      _notesController.text = entry.notes;
      _currentSets.clear();

      for (int i = 0; i < entry.sets.length; i++) {
        final original = entry.sets[i];
        _currentSets.add(WorkoutSet(
          setNumber: i + 1,
          weight: original.weight,
          reps: original.reps,
          rpe: original.rpe,
        ));
      }

      if (entry.sets.isNotEmpty) {
        final lastSet = entry.sets.last;
        _weightController.text = lastSet.weight > 0 ? lastSet.weight.toString() : '';
        _repsController.text = lastSet.reps > 0 ? lastSet.reps.toString() : '';
        _rpe = lastSet.rpe;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Упражнението "${entry.exerciseName}" е заредено за нова серия!'),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveWorkout() async {
    final exercise = _exerciseController.text.trim();
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (exercise.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Въведете име на упражнение!'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_currentSets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавете поне една завършена серия преди запис!'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (userId == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final entry = WorkoutEntry(
        id: '',
        clientId: userId,
        exerciseName: exercise,
        sets: _currentSets,
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      await Supabase.instance.client
          .from('workouts')
          .insert(entry.toMap())
          .timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw TimeoutException('Връзката прекъсна. Проверете интернет връзката си.'),
      );

      if (!mounted) return;
      _exerciseController.clear();
      _weightController.clear();
      _repsController.clear();
      _notesController.clear();
      setState(() => _currentSets.clear());
      await _loadWorkouts();

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Тренировката е записана успешно в дневника!'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('ДНЕВНИК НА ТРЕНИРОВКИТЕ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        cacheExtent: 350,
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _exerciseController,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'УПРАЖНЕНИЕ',
                    hintText: 'напр. Клек с щанга',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    prefixIcon: const Icon(Icons.fitness_center, color: AppColors.primaryGreen, size: 20),
                    filled: true,
                    fillColor: AppColors.backgroundDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0x6676C043), width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'ТЕЖЕСТ (КГ)',
                          hintText: '80',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          filled: true,
                          fillColor: AppColors.backgroundDark,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0x6676C043), width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _repsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'ПОВТОРЕНИЯ',
                          hintText: '10',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          filled: true,
                          fillColor: AppColors.backgroundDark,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0x6676C043), width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x6676C043), width: 1.2),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton(
                            value: _rpe,
                            dropdownColor: AppColors.cardDark,
                            style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 14),
                            items: List.generate(10, (i) => i + 1)
                                .map((val) => DropdownMenuItem(value: val, child: Text('RPE $val')))
                                .toList(),
                            onChanged: (val) => setState(() => _rpe = val ?? 8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _notesController, // Коригирано от notesController
                  style: const TextStyle(color: AppColors.textPrimary),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    FocusScope.of(context).unfocus();
                    _addSet();
                  },
                  decoration: InputDecoration(
                    labelText: 'БЕЛЕЖКИ (ПО ИЗБОР)',
                    hintText: 'напр. Лека загрявка преди това',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    prefixIcon: const Icon(Icons.edit_note, color: AppColors.primaryGreen, size: 22),
                    filled: true,
                    fillColor: AppColors.backgroundDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0x6676C043), width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add, color: AppColors.primaryGreen),
                  label: const Text('Добави серия', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _addSet();
                  },
                ),
                if (_currentSets.isNotEmpty) ...[
                  const Divider(height: 24, color: Colors.white12),
                  const Text('Въведени серии за това упражнение:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  ..._currentSets.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '• Серия ${s.setNumber}: ${s.weight} кг x ${s.reps} повт. (RPE ${s.rpe})',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: AppColors.errorRed),
                            onPressed: () => _removeSet(idx),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveWorkout,
                    child: _isSaving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Запази цялото упражнение'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('История на тренировките', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          else if (_pastWorkouts.isEmpty)
            const Text('Все още няма въведени упражнения.', style: TextStyle(color: AppColors.textSecondary))
          else
            ..._pastWorkouts.map((w) => Card(
              color: AppColors.cardDark,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                title: Text(w.exerciseName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${w.sets.length} серии • ${w.createdAt.day}.${w.createdAt.month}.${w.createdAt.year} г.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppColors.primaryGreen, size: 20),
                  tooltip: 'Копирай предишна тренировка',
                  onPressed: () => _copyWorkout(w),
                ),
                children: [
                  if (w.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Бележка: ${w.notes}',
                          style: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic, fontSize: 12),
                        ),
                      ),
                    ),
                  ...w.sets.map((s) => ListTile(
                    dense: true,
                    title: Text(
                      'Серия ${s.setNumber}: ${s.weight} кг x ${s.reps} повт.',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    trailing: Text('RPE ${s.rpe}', style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                  )),
                ],
              ),
            )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}