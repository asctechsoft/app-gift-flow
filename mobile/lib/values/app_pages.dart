import 'package:get/get.dart';

import '../presentation/screen_events/event_detail_screen.dart';
import '../presentation/screen_events/event_edit_screen.dart';
import '../presentation/screen_export/export_screen.dart';
import '../presentation/screen_gifts/gift_edit_screen.dart';
import '../presentation/screen_invitations/invitations_screen.dart';
import '../presentation/screen_plan/plan_screen.dart';
import '../presentation/screens_settings/widgets_screen.dart';
import '../presentation/screen_recording/record_result_screen.dart';
import '../presentation/screen_recording/recording_screen.dart';
import '../presentation/screen_shell/shell_screen.dart';
import '../presentation/screen_splash/splash_screen.dart';
import '../presentation/screen_statistics/statistics_screen.dart';
import '../presentation/screens_onboarding/onboarding_screen.dart';
import '../presentation/screens_settings/settings_sub_screens.dart';
import 'route_name.dart';

class AppPages {
  AppPages._();

  static final List<GetPage<dynamic>> pages = [
    GetPage(name: RouteName.splash, page: () => const SplashScreen()),
    GetPage(
      name: RouteName.onboarding,
      page: () => const OnboardingScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: RouteName.shell,
      page: () => const ShellScreen(),
      transition: Transition.fadeIn,
    ),
    // Fullscreen, không navbar.
    GetPage(
      name: RouteName.recording,
      page: () => const RecordingScreen(),
      transition: Transition.downToUp,
      fullscreenDialog: true,
    ),
    GetPage(
      name: RouteName.recordResult,
      page: () => const RecordResultScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(name: RouteName.giftEdit, page: () => const GiftEditScreen()),
    GetPage(name: RouteName.eventEdit, page: () => const EventEditScreen()),
    GetPage(name: RouteName.eventDetail, page: () => const EventDetailScreen()),
    GetPage(name: RouteName.plan, page: () => const PlanScreen()),
    GetPage(name: RouteName.invitations, page: () => const InvitationsScreen()),
    GetPage(name: RouteName.widgets, page: () => const WidgetsScreen()),
    GetPage(name: RouteName.privacy, page: () => const PrivacyScreen()),
    GetPage(name: RouteName.terms, page: () => const TermsScreen()),
    GetPage(name: RouteName.statistics, page: () => const StatisticsScreen()),
    GetPage(name: RouteName.export, page: () => const ExportScreen()),
    GetPage(name: RouteName.profile, page: () => const ProfileScreen()),
    GetPage(
      name: RouteName.recordingOptions,
      page: () => const RecordingOptionsScreen(),
    ),
    GetPage(name: RouteName.backup, page: () => const BackupScreen()),
    GetPage(name: RouteName.about, page: () => const AboutScreen()),
  ];
}
