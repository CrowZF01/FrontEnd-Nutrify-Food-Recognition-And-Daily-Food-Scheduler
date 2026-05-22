import '../../core/services/hive_service.dart';
import '../models/user_profile.dart';

class UserRepository {
  static UserProfile? getProfile() {
    final data = HiveService.userBox.get('profile');
    if (data == null) return null;
    return UserProfile.fromMap(Map<dynamic, dynamic>.from(data));
  }

  static Future<void> saveProfile(UserProfile profile) async {
    await HiveService.userBox.put('profile', profile.toMap());
  }

  static bool isOnboarded() {
    final data = HiveService.userBox.get('profile');
    if (data == null) return false;
    return data['isOnboarded'] == true;
  }

  static Future<void> clearProfile() async {
    await HiveService.userBox.delete('profile');
  }
}
