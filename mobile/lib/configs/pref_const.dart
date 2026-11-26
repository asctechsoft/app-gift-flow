/// Mọi key SharedPreferences nằm ở đây - không gõ string rải rác trong code.
class PrefConst {
  PrefConst._();

  static const String language = 'language';
  static const String followSystemLanguage = 'follow_system_language';
  static const String onboardingSeen = 'onboarding_seen';
  static const String activeEventId = 'active_event_id';
  static const String deviceId = 'device_id';
  static const String displayName = 'display_name';
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String autoSilenceCut = 'rec_auto_silence_cut';
  static const String silenceMs = 'rec_silence_ms';
  static const String autoSave = 'rec_auto_save';
  static const String statusNotification = 'status_notification';
  static const String themeMode = 'theme_mode';
  static const String notifAsked = 'notif_permission_asked';
  static const String serverUrl = 'server_url';
  static const String accountEmail = 'account_email';
  static const String lastSyncAt = 'last_sync_at';
}
