import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/user_profile.dart';

final profileProvider =
    StateNotifierProvider<ProfileNotifier, UserProfile?>((ref) {
  return ProfileNotifier();
});

class ProfileNotifier extends StateNotifier<UserProfile?> {
  static const _boxName = 'profile';
  static const _key = 'user_profile';

  ProfileNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final box = await Hive.openBox(_boxName);
    final data = box.get(_key);
    if (data != null) {
      state = UserProfile.fromMap(Map<dynamic, dynamic>.from(data));
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    final box = await Hive.openBox(_boxName);
    await box.put(_key, profile.toMap());
    state = profile;
  }

  Future<void> updateProfile(UserProfile profile) async {
    await saveProfile(profile);
  }

  static Future<bool> hasProfile() async {
    final box = await Hive.openBox(_boxName);
    return box.containsKey(_key);
  }
}
