import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final draftSessionProvider = StateNotifierProvider<DraftSessionNotifier, Map<String, dynamic>?>((ref) {
  return DraftSessionNotifier();
});

class DraftSessionNotifier extends StateNotifier<Map<String, dynamic>?> {
  DraftSessionNotifier() : super(null) {
    _loadDraft();
  }

  static const _key = 'draft_session_v1';

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr != null) {
      state = json.decode(jsonStr);
    }
  }

  Future<void> saveDraft({
    required int? routineId,
    required String date,
    required String notes,
    required List<Map<String, dynamic>> exercises,
    int? sessionId,
  }) async {
    final draft = {
      'routineId': routineId,
      'date': date,
      'notes': notes,
      'exercises': exercises,
      'sessionId': sessionId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    state = draft;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(draft));
  }

  Future<void> clearDraft() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
