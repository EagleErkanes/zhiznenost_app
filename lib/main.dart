  import 'package:flutter/material.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';
  import 'core/constants/app_colors.dart';
  import 'screens/auth/login_screen.dart';
  import 'screens/client/client_main_navigation.dart';
  import 'screens/coach/coach_dashboard_screen.dart';
  import 'services/supabase_service.dart';

  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SupabaseService.initialize();
    runApp(const ZhiznenostApp());
  }

  class ZhiznenostApp extends StatelessWidget {
    const ZhiznenostApp({super.key});

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        title: 'Жизненост',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.backgroundDark,
          primaryColor: AppColors.primaryGreen,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.cardDark,
            hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.errorRed, width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.black,
              minimumSize: const Size(64, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              elevation: 0,
            ),
          ),
        ),
        home: const AuthGate(),
      );
    }
  }

  class AuthGate extends StatelessWidget {
    const AuthGate({super.key});

    @override
    Widget build(BuildContext context) {
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        return const LoginScreen();
      }

      return FutureBuilder<Map<String, dynamic>?>(
        future: Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', session.user.id)
            .maybeSingle(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppColors.backgroundDark,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
            );
          }

          final profile = snapshot.data;
          if (profile != null && profile['role'] == 'coach') {
            return const CoachDashboardScreen();
          } else {
            return const ClientMainNavigation();
          }
        },
      );
    }
  }