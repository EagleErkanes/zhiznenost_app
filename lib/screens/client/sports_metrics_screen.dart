import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/error_handler.dart';
import '../../models/metric_model.dart';

class SportsMetricsScreen extends StatefulWidget {
  const SportsMetricsScreen({super.key});

  @override
  State<SportsMetricsScreen> createState() => _SportsMetricsScreenState();
}

class _SportsMetricsScreenState extends State<SportsMetricsScreen> {
  final _weightController = TextEditingController();
  final _prExerciseController = TextEditingController();
  final _prValueController = TextEditingController(); // Коригирано (добавена долна черта)

  double _fatigueLevel = 3;
  double _painLevel = 1;
  bool _isLoading = true;
  bool _isSaving = false;

  List<MetricModel> _metricsHistory = [];
  List<MetricModel> _cachedWeightMetrics = [];
  List<FlSpot> _cachedWeightSpots = [];

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _prExerciseController.dispose();
    _prValueController.dispose();
    super.dispose();
  }

  void _updateChartCache(List<MetricModel> history) {
    _cachedWeightMetrics = history.where((m) => m.weight != null).toList();
    _cachedWeightSpots = List.generate(
      _cachedWeightMetrics.length,
          (i) => FlSpot(i.toDouble(), _cachedWeightMetrics[i].weight!),
    );
  }

  Future<void> _loadMetrics() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final res = await Supabase.instance.client
          .from('metrics')
          .select()
          .eq('client_id', userId)
          .order('recorded_at', ascending: true)
          .timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw TimeoutException('Връзката прекъсна.'),
      );

      if (mounted) {
        final list = (res as List).map((m) => MetricModel.fromMap(m)).toList();
        _updateChartCache(list);
        setState(() {
          _metricsHistory = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMetric() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final weight = double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    final prExercise = _prExerciseController.text.trim();
    final prValue = _prValueController.text.trim();

    if (weight != null && (weight < 30 || weight > 300)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Въведете реално тегло между 30 и 300 кг!'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (weight == null && prExercise.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Въведете поне текущо тегло или нов личен рекорд!'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final newMetric = MetricModel(
        id: '',
        clientId: userId,
        weight: weight,
        fatigueLevel: _fatigueLevel.toInt(),
        painLevel: _painLevel.toInt(),
        personalRecordExercise: prExercise.isNotEmpty ? prExercise : null,
        personalRecordValue: prValue.isNotEmpty ? prValue : null,
        recordedAt: DateTime.now(),
      );

      await Supabase.instance.client
          .from('metrics')
          .insert(newMetric.toMap())
          .timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw TimeoutException('Връзката прекъсна. Проверете интернет връзката си.'),
      );

      if (weight != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'weight': weight})
            .eq('id', userId)
            .timeout(
          const Duration(seconds: 4),
          onTimeout: () => throw TimeoutException('Връзката прекъсна.'),
        );
      }

      if (!mounted) return;
      _weightController.clear();
      _prExerciseController.clear();
      _prValueController.clear();

      await _loadMetrics();

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Резултатите са записани успешно!'),
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
    final weightSpots = _cachedWeightSpots;
    final weightList = _cachedWeightMetrics;
    final weightCount = weightSpots.length;

    double minY = 40;
    double maxY = 100;
    if (weightSpots.isNotEmpty) {
      final weights = weightSpots.map((s) => s.y).toList();
      minY = (weights.reduce(min) - 2).floorToDouble();
      maxY = (weights.reduce(max) + 2).ceilToDouble();
      if (minY < 0) minY = 0;
      if (minY >= maxY) {
        minY = max(0, minY - 3);
        maxY += 3;
      }
    }

    final double? firstWeight = weightList.isNotEmpty ? weightList.first.weight : null;
    final double? currentWeight = weightList.isNotEmpty ? weightList.last.weight : null;
    final double? weightDiff = (firstWeight != null && currentWeight != null)
        ? (currentWeight - firstWeight)
        : null;

    final yInterval = max(1.0, ((maxY - minY) / 4));
    final xInterval = max(1.0, (weightCount / 4)).floorToDouble();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'РЕЗУЛТАТИ И ПРОГРЕС',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        cacheExtent: 350,
        padding: const EdgeInsets.all(16),
        children: [
          // 1. КАРТИ С КЛЮЧОВИ ПОКАЗАТЕЛИ
          if (weightCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricSummaryCard(
                      title: 'Стартово',
                      value: '${firstWeight?.toStringAsFixed(1)} кг',
                      icon: Icons.flag_outlined,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricSummaryCard(
                      title: 'Текущо',
                      value: '${currentWeight?.toStringAsFixed(1)} кг',
                      icon: Icons.monitor_weight_outlined,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricSummaryCard(
                      title: 'Промяна',
                      value: weightDiff != null
                          ? '${weightDiff > 0 ? "+" : ""}${weightDiff.toStringAsFixed(1)} кг'
                          : '-',
                      icon: Icons.trending_up,
                      color: (weightDiff ?? 0) <= 0
                          ? AppColors.primaryGreen
                          : Colors.amber,
                    ),
                  ),
                ],
              ),
            ),

          // 2. ГРАФИКА НА ТЕГЛОТО
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.show_chart_rounded, color: AppColors.primaryGreen, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'ХРОНОЛОГИЯ НА ТЕГЛОТО',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (weightCount < 2)
                  SizedBox(
                    height: 130,
                    child: Center(
                      child: Text(
                        weightCount == 0
                            ? 'Въведете поне 2 записа с тегло за графика.'
                            : 'Имате 1 запис (${firstWeight?.toStringAsFixed(1)} кг).\nВъведете още 1 за чертане на линия.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        minY: minY,
                        maxY: maxY,
                        gridData: const FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: null,
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 42,
                              interval: yInterval,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()} кг',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 26,
                              interval: max(1.0, xInterval),
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < weightList.length) {
                                  final d = weightList[index].recordedAt;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      '${d.day}.${d.month}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: weightSpots,
                            isCurved: false,
                            color: AppColors.primaryGreen,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0x2876C043),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. ФОРМА ЗА ЗАПИСВАНЕ
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
                const Text(
                  'Нов запис на показатели',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'ТЕКУЩО ТЕГЛО (КГ)',
                    hintText: 'напр. 75.5',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    prefixIcon: const Icon(Icons.monitor_weight_outlined, color: AppColors.primaryGreen),
                    filled: true,
                    fillColor: AppColors.backgroundDark,
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
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ниво на умора (0-10):',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          '0 = Свеж, 10 = Пълно изтощение',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                    Text(
                      '${_fatigueLevel.toInt()} / 10',
                      style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Slider(
                  value: _fatigueLevel,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  activeColor: AppColors.primaryGreen,
                  inactiveColor: Colors.white10,
                  onChanged: (val) => setState(() => _fatigueLevel = val),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ниво на болка/дискомфорт (0-10):',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          '0 = Без болка, 10 = Силна болка / травма',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                    Text(
                      '${_painLevel.toInt()} / 10',
                      style: const TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Slider(
                  value: _painLevel,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  activeColor: AppColors.errorRed,
                  inactiveColor: Colors.white10,
                  onChanged: (val) => setState(() => _painLevel = val),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Личен рекорд - PR (по избор)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _prExerciseController,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'УПРАЖНЕНИЕ',
                          hintText: 'напр. Лежанка',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          prefixIcon: const Icon(Icons.fitness_center, color: AppColors.primaryGreen, size: 20),
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
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _prValueController, // Коригирано с подчертавка
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          FocusScope.of(context).unfocus();
                        },
                        decoration: InputDecoration(
                          labelText: 'ПОСТИЖЕНИЕ',
                          hintText: '100 кг',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          prefixIcon: const Icon(Icons.emoji_events_outlined, color: AppColors.primaryGreen, size: 20),
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
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveMetric,
                  child: _isSaving
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                  )
                      : const Text('Запази резултатите'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. ПОСЛЕДНИ ЛИЧНИ РЕКОРДИ
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'ПОСЛЕДНИ ЛИЧНИ РЕКОРДИ (PR)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._metricsHistory.reversed
                    .where((m) => m.personalRecordExercise != null && m.personalRecordExercise!.isNotEmpty)
                    .take(5)
                    .map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        m.personalRecordExercise!,
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        m.personalRecordValue ?? '',
                        style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),
                if (!_metricsHistory.any((m) => m.personalRecordExercise != null && m.personalRecordExercise!.isNotEmpty))
                  const Text(
                    'Все още няма въведени лични рекорди.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. ДЕТАЙЛНА ХРОНОЛОГИЯ НА ИЗМЕРВАНИЯТА
          if (_metricsHistory.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ИСТОРИЯ НА ИЗМЕРВАНИЯТА',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  ..._metricsHistory.reversed.map((m) {
                    final d = m.recordedAt;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white10)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${d.day}.${d.month}.${d.year}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          const Spacer(),
                          if (m.weight != null)
                            Text(
                              '${m.weight} кг',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          const SizedBox(width: 12),
                          Text(
                            'Умора: ${m.fatigueLevel}/10',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                          if ((m.painLevel ?? 0) > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Болка: ${m.painLevel}/10',
                              style: const TextStyle(color: AppColors.errorRed, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMetricSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}