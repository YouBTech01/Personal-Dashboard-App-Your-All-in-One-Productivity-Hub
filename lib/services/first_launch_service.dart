import 'package:shared_preferences/shared_preferences.dart';

class FirstLaunchService {
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';

  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_hasSeenOnboardingKey) ?? false);
  }

  static Future<void> setHasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, true);
  }
}
