import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/sms_draft_model.dart';

/// Local, device-only, temporary storage for SMS drafts — pending review
/// until the user verifies or discards them. Not synced to Firestore;
/// once verified, a real transaction is created and the draft is removed.
class SmsDraftStore {
  SmsDraftStore._();

  static final SmsDraftStore instance = SmsDraftStore._();

  static const _key = 'sms_drafts';

  Future<List<SmsDraft>> getDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => SmsDraft.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> addDraft(SmsDraft draft) async {
    final drafts = await getDrafts();

    // De-duplicate: the same SMS shouldn't be drafted twice.
    if (drafts.any((d) => d.id == draft.id)) return;

    drafts.add(draft);
    await _save(drafts);
  }

  Future<void> removeDraft(String id) async {
    final drafts = await getDrafts();
    drafts.removeWhere((d) => d.id == id);
    await _save(drafts);
  }

  Future<void> _save(List<SmsDraft> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(drafts.map((d) => d.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
