import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/database_service.dart';
import 'client_dashboard_screen.dart';
import 'workout_logger_screen.dart';
import 'sports_metrics_screen.dart';
import 'client_profile_screen.dart';

class ClientMainNavigation extends StatefulWidget {
  const ClientMainNavigation({super.key});

  @override
  State<ClientMainNavigation> createState() => _ClientMainNavigationState();
}

class _ClientMainNavigationState extends State<ClientMainNavigation> {
  final DatabaseService _dbService = DatabaseService();
  int _currentIndex = 0;
  bool _hasIndividualPackage = false;
  bool _isCheckingPackage = true;

  @override
  void initState() {
    super.initState();
    _checkClientPackages();
  }

  Future<void> _checkClientPackages() async {
    try {
      final packages = await _dbService.getClientPackages();
      final hasIndividual = packages.any((pkg) {
        final name = (pkg['service_name'] ?? '').toString().toLowerCase();
        final remaining = (pkg['remaining_visits'] as num?)?.toInt() ?? 0;
        return name.contains('индивидуалн') && remaining > 0;
      });

      if (mounted) {
        setState(() {
          _hasIndividualPackage = hasIndividual;
          _isCheckingPackage = false;

          final maxAllowedIndex = _hasIndividualPackage ? 3 : 2;
          if (_currentIndex > maxAllowedIndex) {
            _currentIndex = maxAllowedIndex;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingPackage = false);
      }
    }
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _checkClientPackages();
          setState(() => _currentIndex = index);
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.22 : 1.0, // ОПРАВЕНО: Точката и запетаята са сменени с чиста запетая
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                child: Icon(
                  icon,
                  color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPackage) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    final List<Widget> screens = [
      const ClientDashboardScreen(),
      if (_hasIndividualPackage) const WorkoutLoggerScreen(),
      const SportsMetricsScreen(),
      const ClientProfileScreen(),
    ];

    final safeIndex = _currentIndex < screens.length ? _currentIndex : 0;

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        color: AppColors.cardDark,
        child: SafeArea(
          bottom: true,
          child: Container(
            height: 64,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white10, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavButton(icon: Icons.home_filled, label: 'Табло', index: 0),
                if (_hasIndividualPackage)
                  _buildNavButton(icon: Icons.fitness_center, label: 'Дневник', index: 1),
                _buildNavButton(
                  icon: Icons.trending_up,
                  label: 'Прогрес',
                  index: _hasIndividualPackage ? 2 : 1,
                ),
                _buildNavButton(
                  icon: Icons.person,
                  label: 'Профил',
                  index: _hasIndividualPackage ? 3 : 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
