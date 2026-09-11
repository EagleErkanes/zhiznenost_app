import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zhiznenost_app/models/metric_model.dart';
import '../models/user_profile.dart';
import '../models/visit_model.dart';

class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, String>> getMotivationalQuote() async {
    try {
      final response = await _supabase
          .from('quotes')
          .select('quote_text, author')
          .eq('id', 1)
          .maybeSingle();

      if (response != null) {
        return {
          'text': response['quote_text']?.toString() ?? '',
          'author': response['author']?.toString() ?? 'Алекс - Жизненост',
        };
      }
    } catch (_) {}

    return {
      'text': 'Постоянството побеждава таланта, когато талантът не работи здраво!',
      'author': 'Алекс - Жизненост',
    };
  }

  Future<void> updateMotivationalQuote(String text, String author) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Няма активна сесия на треньор.');

    await _supabase.from('quotes').upsert({
      'id': 1,
      'quote_text': text,
      'author': author,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> logVisitWithPackageDeduction(String serviceName) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Няма активна потребителска сесия.');

    final packages = await _supabase
        .from('client_packages')
        .select()
        .eq('client_id', user.id)
        .eq('service_name', serviceName)
        .gt('remaining_visits', 0)
        .order('created_at', ascending: true)
        .limit(1);

    final availablePackages = packages as List;
    if (availablePackages.isEmpty) {
      throw Exception('Нямате активна карта или оставащи посещения за "$serviceName".');
    }

    final activePkg = availablePackages.first;
    final int currentRemaining = activePkg['remaining_visits'] as int;
    final String packageId = activePkg['id'] as String;

    await _supabase.from('visits').insert({
      'client_id': user.id,
      'workout_type': serviceName,
      'service_type': serviceName,
      'visited_at': DateTime.now().toIso8601String(),
    });

    await _supabase
        .from('client_packages')
        .update({'remaining_visits': currentRemaining - 1})
        .eq('id', packageId);
  }

  Future<List<VisitModel>> getClientVisits([String? clientId]) async {
    final targetId = clientId ?? _supabase.auth.currentUser?.id;
    if (targetId == null) return [];

    final response = await _supabase
        .from('visits')
        .select()
        .eq('client_id', targetId)
        .order('visited_at', ascending: false);

    return (response as List).map((map) => VisitModel.fromMap(map)).toList();
  }

  Future<List<UserProfile>> getAllClients() async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('role', 'client');

      return (response as List)
          .map((map) => UserProfile.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<UserProfile>> getAllCoaches() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'coach')
          .order('full_name', ascending: true);

      return (response as List).map((map) => UserProfile.fromMap(map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> assignClientToCoach(String clientId, String coachId) async {
    await _supabase.from('profiles').update({
      'coach_id': coachId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', clientId);
  }

  Future<List<Map<String, dynamic>>> getClientPackages([String? clientId]) async {
    final targetId = clientId ?? _supabase.auth.currentUser?.id;
    if (targetId == null) return [];

    final res = await _supabase
        .from('client_packages')
        .select()
        .eq('client_id', targetId)
        .gt('remaining_visits', 0)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> addPackageToClient({
    required String clientId,
    required String serviceName,
    required String packageType,
    required int totalVisits,
  }) async {
    await _supabase.from('client_packages').insert({
      'client_id': clientId,
      'service_name': serviceName,
      'package_type': packageType,
      'total_visits': totalVisits,
      'remaining_visits': totalVisits,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateClientPackage({
    required String packageId,
    required int remainingVisits,
    required int totalVisits,
  }) async {
    if (remainingVisits > totalVisits) {
      throw Exception('Оставащите посещения ($remainingVisits) не могат да надвишават общите ($totalVisits)!');
    }
    if (remainingVisits < 0 || totalVisits <= 0) {
      throw Exception('Невалиден брой посещения.');
    }

    await _supabase.from('client_packages').update({
      'remaining_visits': remainingVisits,
      'total_visits': totalVisits,
    }).eq('id', packageId);
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return UserProfile.fromMap(data);
  }

  Future<void> updateClientProfile({
    required String fullName,
    required String? gender,
    required int? age,
    required double? height,
    required double? weight,
    required String? goal,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Потребителят не е аутентикиран.');

    await _supabase.from('profiles').update({
      'full_name': fullName.trim(),
      'gender': gender,
      'age': age,
      'height': height,
      'weight': weight,
      'goal': goal,
    }).eq('id', user.id);
  }

  Future<List<Map<String, dynamic>>> getClientWorkouts(String clientId) async {
    try {
      final res = await _supabase
          .from('workouts')
          .select()
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  // Извлича статистика за посещенията и активността на всички клиенти за треньорския панел
  Future<Map<String, Map<String, dynamic>>> getClientsVisitsSummary() async {
    final now = DateTime.now();
    final Map<String, Map<String, dynamic>> summary = {};

    try {
      // 1. Извличаме посещенията по карти с безопасна валидация на датите
      final visitsRes = await _supabase
          .from('visits')
          .select('client_id, visited_at')
          .order('visited_at', ascending: false);

      for (final row in (visitsRes as List)) {
        final clientId = row['client_id']?.toString() ?? '';
        final visitedAtRaw = row['visited_at']?.toString() ?? '';
        final visitedAt = DateTime.tryParse(visitedAtRaw);

        if (clientId.isEmpty || visitedAt == null) continue;

        if (!summary.containsKey(clientId)) {
          summary[clientId] = {
            'last_visit': visitedAt,
            'month_visits': 0,
          };
        } else {
          final existingDate = summary[clientId]!['last_visit'] as DateTime;
          if (visitedAt.isAfter(existingDate)) {
            summary[clientId]!['last_visit'] = visitedAt;
          }
        }

        if (visitedAt.year == now.year && visitedAt.month == now.month) {
          summary[clientId]!['month_visits'] = (summary[clientId]!['month_visits'] as int) + 1;
        }
      }
    } catch (_) {}

    try {
      // 2. Извличаме тренировките от дневника с безопасна валидация на датите
      final workoutsRes = await _supabase
          .from('workouts')
          .select('client_id, created_at')
          .order('created_at', ascending: false);

      for (final row in (workoutsRes as List)) {
        final clientId = row['client_id']?.toString() ?? '';
        final createdAtRaw = row['created_at']?.toString() ?? '';
        final createdAt = DateTime.tryParse(createdAtRaw);

        if (clientId.isEmpty || createdAt == null) continue;

        if (!summary.containsKey(clientId)) {
          summary[clientId] = {
            'last_visit': createdAt,
            'month_visits': 0,
          };
        } else {
          final existingDate = summary[clientId]!['last_visit'] as DateTime;
          if (createdAt.isAfter(existingDate)) {
            summary[clientId]!['last_visit'] = createdAt;
          }
        }
      }
    } catch (_) {}

    return summary;
  }

  Future<List<MetricModel>> getClientMetrics(String clientId) async {
    final res = await _supabase
        .from('metrics')
        .select()
        .eq('client_id', clientId)
        .order('recorded_at', ascending: true);

    return (res as List).map((m) => MetricModel.fromMap(m)).toList();
  }

  Future<void> deleteClientPackage(String packageId) async {
    await _supabase.from('client_packages').delete().eq('id', packageId);
  }
}