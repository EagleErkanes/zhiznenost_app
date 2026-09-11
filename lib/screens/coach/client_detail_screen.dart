import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/metric_model.dart';
import '../../models/user_profile.dart';
import '../../models/visit_model.dart';
import '../../services/database_service.dart';

class ClientDetailScreen extends StatefulWidget {
  final UserProfile client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final DatabaseService _dbService = DatabaseService();
  late UserProfile _currentClient;
  List<VisitModel> _visits = [];
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _workouts = [];
  List<MetricModel> _metrics = [];
  List<MetricModel> _cachedWeightMetrics = [];
  List<FlSpot> _cachedWeightSpots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentClient = widget.client;
    // Изчакваме първия кадър да се нарисува, преди да блокираме нишката с мрежови заявки.
    // Това решава проблема със "забилата" навигационна стрелка при iOS.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClientDetails();
    });
  }

  void _updateChartCache(List<MetricModel> metrics) {
    _cachedWeightMetrics = metrics.where((m) => m.weight != null).toList();
    _cachedWeightSpots = List.generate(
      _cachedWeightMetrics.length,
          (i) => FlSpot(i.toDouble(), _cachedWeightMetrics[i].weight!),
    );
  }

  Future<void> _loadClientDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final visitsFuture = _dbService.getClientVisits(_currentClient.id);
      final packagesFuture = _dbService.getClientPackages(_currentClient.id);
      final workoutsFuture = _dbService.getClientWorkouts(_currentClient.id);
      final metricsFuture = _dbService.getClientMetrics(_currentClient.id);
      final profileFuture = Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', _currentClient.id)
          .maybeSingle();

      final visits = await visitsFuture;
      final packages = await packagesFuture;
      final workouts = await workoutsFuture;
      final metrics = await metricsFuture;
      final profileMap = await profileFuture;

      if (mounted) {
        _updateChartCache(metrics);
        setState(() {
          _visits = visits;
          _packages = packages;
          _workouts = workouts;
          _metrics = metrics;
          if (profileMap != null) {
            _currentClient = UserProfile.fromMap(profileMap);
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _hasIndividualPackage {
    return _packages.any((pkg) {
      final name = (pkg['service_name'] ?? '').toString().toLowerCase();
      final remaining = (pkg['remaining_visits'] as num?)?.toInt() ?? 0;
      return name.contains('индивидуалн') && remaining > 0;
    });
  }

  void _showAddPackageDialog() {
    String selectedService = AppConstants.servicePackageOptions.keys.first;
    String selectedOption = AppConstants.servicePackageOptions[selectedService]!.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final availableOptions = AppConstants.servicePackageOptions[selectedService]!;
            if (!availableOptions.contains(selectedOption)) {
              selectedOption = availableOptions.first;
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Активиране на карта / пакет',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedService,
                      dropdownColor: AppColors.cardDark,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Услуга'),
                      items: AppConstants.servicePackageOptions.keys
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedService = val;
                            selectedOption = AppConstants.servicePackageOptions[val]!.first;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedOption,
                      dropdownColor: AppColors.cardDark,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Брой посещения'),
                      items: availableOptions
                          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedOption = val);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () async {
                        int count = 1;
                        if (selectedOption.contains('4')) count = 4;
                        if (selectedOption.contains('8')) count = 8;

                        Navigator.pop(ctx);
                        await _dbService.addPackageToClient(
                          clientId: _currentClient.id,
                          serviceName: selectedService,
                          packageType: selectedOption,
                          totalVisits: count,
                        );
                        await _loadClientDetails();
                      },
                      child: const Text('Активирай пакета'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditPackageDialog(Map<String, dynamic> pkg) {
    final remainingController = TextEditingController(text: pkg['remaining_visits'].toString());
    final totalController = TextEditingController(text: pkg['total_visits'].toString());
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: AppColors.cardDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Редакция: ${pkg['service_name']}',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: remainingController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      textInputAction: TextInputAction.next, // Прехвърля на следващото поле
                      decoration: const InputDecoration(labelText: 'Оставащи посещения'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: totalController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      textInputAction: TextInputAction.done, // Финален бутон
                      onSubmitted: (_) {
                        FocusScope.of(context).unfocus(); // Принудително крие клавиатурата безопасно
                      },
                      decoration: const InputDecoration(labelText: 'Общ брой по карта'),
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(errorMessage!, style: const TextStyle(color: AppColors.errorRed, fontSize: 12)),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Отказ', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
                          onPressed: () async {
                            // ВЕДНАГА УБИВАМЕ КЛАВИАТУРАТА, ЗА ДА НЕ СРИТИ ВЕБ КОНТЕКСТА СЛЕД ПОПЪПА
                            FocusScope.of(context).unfocus();

                            final remaining = int.tryParse(remainingController.text.trim()) ?? 0;
                            final total = int.tryParse(totalController.text.trim()) ?? 0;

                            // ... останалата част от вашата логика за валидация и запис


                            if (total > 999 || remaining > 999) {
                              setDialogState(() => errorMessage = 'Броят посещения не може да надвишава 999!');
                              return;
                            }
                            if (remaining > total) {
                              setDialogState(() => errorMessage = 'Оставащите ($remaining) не могат да са повече от общите ($total)!');
                              return;
                            }
                            if (total <= 0 || remaining < 0) {
                              setDialogState(() => errorMessage = 'Въведете положителни числа!');
                              return;
                            }

                            Navigator.pop(dialogCtx);
                            await _dbService.updateClientPackage(
                              packageId: pkg['id'].toString(),
                              remainingVisits: remaining,
                              totalVisits: total,
                            );
                            await _loadClientDetails();
                          },
                          child: const Text('Запази'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeletePackage(Map<String, dynamic> pkg) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text('Изтриване на карта', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
          content: Text(
            'Сигурни ли сте, че искате да изтриете картата за "${pkg['service_name']}" (${pkg['package_type']})?',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Отказ', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                minimumSize: const Size(100, 44),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _dbService.deleteClientPackage(pkg['id'].toString());
                await _loadClientDetails();
              },
              child: const Text('Изтрий', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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

    final yInterval = max(1.0, ((maxY - minY) / 3));
    final xInterval = max(1.0, (weightCount / 4)).floorToDouble();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        // ФОРСИРАНО ЗАТВАРЯНЕ ЗА IOS
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () {
            FocusScope.of(context).unfocus(); // Убива всички фокус/клавиатури
            Navigator.of(context).pop(); // Затваря екрана безопасно
          },
        ),
        title: Text(_currentClient.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Презареди данните',
            onPressed: _loadClientDetails,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.all(16),
        children: [
          // СЕКЦИЯ 1: ПРОФИЛ И ФИЗИЧЕСКИ ДАННИ
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
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0x3376C043),
                      child: Text(
                        _currentClient.fullName.isNotEmpty
                            ? _currentClient.fullName.substring(0, 1).toUpperCase()
                            : 'К',
                        style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentClient.fullName,
                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            _currentClient.email,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Colors.white10),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildInfoBadge('Пол', _currentClient.gender ?? 'Непосочен'),
                    _buildInfoBadge('Възраст', _currentClient.age != null ? '${_currentClient.age} г.' : 'Непосочена'),
                    _buildInfoBadge('Ръст', _currentClient.height != null ? '${_currentClient.height} см' : 'Непосочен'),
                    _buildInfoBadge('Тегло', _currentClient.weight != null ? '${_currentClient.weight} кг' : 'Непосочено'),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined, color: AppColors.primaryGreen, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Цел: ${_currentClient.goal ?? "Няма избрана цел"}',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // СЕКЦИЯ 2: АКТИВНИ КАРТИ И ПАКЕТИ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Активни карти и пакети', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              TextButton.icon(
                icon: const Icon(Icons.add_card, color: AppColors.primaryGreen, size: 18),
                label: const Text('Зареди карта', style: TextStyle(color: AppColors.primaryGreen)),
                onPressed: _showAddPackageDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_packages.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(12)),
              child: const Text('Клиентът няма активни карти.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ..._packages.map((pkg) => Card(
              color: AppColors.cardDark,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(pkg['service_name'].toString(), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: Text('Тип: ${pkg['package_type']}', style: const TextStyle(color: AppColors.textSecondary)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x3376C043),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${pkg['remaining_visits']} / ${pkg['total_visits']} ост.',
                        style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                      onPressed: () => _showEditPackageDialog(pkg),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                      onPressed: () => _confirmDeletePackage(pkg),
                    ),
                  ],
                ),
              ),
            )),
          const SizedBox(height: 20),

          // СЕКЦИЯ 3: СПОРТНИ РЕЗУЛТАТИ И ГРАФИКА
          const Text('Спортен прогрес и показатели', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
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
                const Text('Графика на теглото', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 12),
                if (weightCount < 2)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('Няма достатъчно записи за графика на теглото.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                  )
                else
                  SizedBox(
                    height: 160,
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
                              reservedSize: 38,
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
                              reservedSize: 24,
                              interval: max(1.0, xInterval),
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < weightList.length) {
                                  final d = weightList[index].recordedAt;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      '${d.day}.${d.month}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
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
                            belowBarData: BarAreaData(show: true, color: const Color(0x2876C043)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 24, color: Colors.white10),
                const Text('Лични рекорди (PR):', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ..._metrics.reversed
                    .where((m) => m.personalRecordExercise != null && m.personalRecordExercise!.isNotEmpty)
                    .take(5)
                    .map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('• ${m.personalRecordExercise}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text(m.personalRecordValue ?? '', style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                )),
                if (!_metrics.any((m) => m.personalRecordExercise != null && m.personalRecordExercise!.isNotEmpty))
                  const Text('Няма въведени лични рекорди.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),

                if (_metrics.isNotEmpty) ...[
                  const Divider(height: 24, color: Colors.white10),
                  const Text(
                    'История на измерванията:',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ..._metrics.reversed.take(6).map((m) {
                    final d = m.recordedAt;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
                              style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          const SizedBox(width: 10),
                          Text(
                            'Умора: ${m.fatigueLevel}/10',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // СЕКЦИЯ 4: ДНЕВНИК НА ТРЕНИРОВКИТЕ (САМО ЗА ИНДИВИДУАЛНИ ТРЕНИРОВКИ)
          if (_hasIndividualPackage) ...[
            const Text('Дневник на тренировките (Упражнения & RPE)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            if (_workouts.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(12)),
                child: const Text('Клиентът все още не е въвеждал упражнения в дневника си.', style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              ..._workouts.map((w) {
                final sets = (w['sets'] as List<dynamic>?) ?? [];
                final createdAt = w['created_at'] != null ? DateTime.parse(w['created_at'].toString()) : DateTime.now();

                return Card(
                  color: AppColors.cardDark,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    leading: const Icon(Icons.fitness_center, color: AppColors.primaryGreen),
                    title: Text(w['exercise_name']?.toString() ?? 'Упражнение', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${sets.length} серии • ${createdAt.day}.${createdAt.month}.${createdAt.year} г.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    children: [
                      if (w['notes'] != null && w['notes'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Бележка: ${w['notes']}', style: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic, fontSize: 12)),
                          ),
                        ),
                      ...sets.map((s) {
                        final map = s as Map<String, dynamic>;
                        return ListTile(
                          dense: true,
                          title: Text(
                            'Серия ${map['set_number']}: ${map['weight']} кг x ${map['reps']} повт.',
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0x2676C043),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('RPE ${map['rpe']}', style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 20),
          ],

          // СЕКЦИЯ 5: ИСТОРИЯ НА ПОСЕЩЕНИЯТА
          const Text('История на посещенията', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          if (_visits.isEmpty)
            const Text('Няма регистрирани посещения.', style: TextStyle(color: AppColors.textSecondary))
          else
            ..._visits.map((v) => Card(
              color: AppColors.cardDark,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline, color: AppColors.primaryGreen),
                title: Text(v.workoutType, style: const TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(
                  '${v.visitedAt.day}.${v.visitedAt.month}.${v.visitedAt.year} г. - ${v.visitedAt.hour}:${v.visitedAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}