import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import 'supabase_service.dart';

class AuthService {
  final SupabaseClient _supabase = SupabaseService.client;

  User? get currentUser => _supabase.auth.currentUser;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'https://zhiznenost.vercel.app/confirmation',
      data: {
        'full_name': fullName,
        'role': role,
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    }
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (data != null) {
        return UserProfile(
          id: data['id'],
          email: data['email'] ?? user.email ?? '',
          role: data['role'] ?? user.userMetadata?['role'] ?? 'client',
          fullName: data['full_name'] ?? user.userMetadata?['full_name'] ?? '',
          gender: data['gender'],
          goal: data['goal'],
          age: data['age'],
          coachId: data['coach_id'],
          height: data['height'] != null ? (data['height'] as num).toDouble() : null,
          weight: data['weight'] != null ? (data['weight'] as num).toDouble() : null,
          createdAt: data['created_at'] != null
              ? DateTime.parse(data['created_at'])
              : DateTime.now(),
        );
      }
    } catch (_) {}

    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      role: user.userMetadata?['role'] ?? 'client',
      fullName: user.userMetadata?['full_name'] ?? '',
      createdAt: DateTime.now(),
    );
  }
}