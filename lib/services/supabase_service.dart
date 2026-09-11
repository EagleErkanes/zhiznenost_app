import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://usyswctldfbryjwsiuzk.supabase.co';

  // Твоят готов Publishable ключ
  static const String supabaseAnonKey = 'sb_publishable_RNb-OuW68izlPBWB1y-MFA_kgTv7M3l';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}