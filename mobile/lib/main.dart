import 'dart:async';

import 'package:asc_common/asc_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'configs/pref_const.dart';
import 'controller/event_controller.dart';
import 'controller/gift_list_controller.dart';
import 'controller/plan_controller.dart';
import 'controller/gift_controller.dart';
import 'controller/recording_controller.dart';
import 'controller/settings_controller.dart';
import 'presentation/screen_shell/shell_screen.dart';
import 'repository/event_repository.dart';
import 'repository/gift_repository.dart';
import 'repository/outbox_repository.dart';
import 'repository/plan_repository.dart';
import 'services/application/api_client.dart';
import 'services/application/google_auth_service.dart';
import 'services/application/sync_service.dart';
import 'values/app_pages.dart';
import 'values/app_theme.dart';
import 'values/route_name.dart';

const List<Locale> kSupportedLocales = [Locale('vi', 'VN'), Locale('en', 'US')];

final AscLogger _log = AscLogger();

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      );
      await initializeDateFormatting();
      await _setupLocale();
      _hideNavigationBar();
      WidgetsBinding.instance.addObserver(_SystemUiObserver());
      await ApiClient.loadBaseUrl();
      await _setupDependencies();
      runApp(const GiftFlowApp());
    },
    (error, stack) => _log.error('Uncaught error', error, stack),
  );
}

/// Mặc định tiếng Việt (MVP); người dùng đổi được trong Cài đặt.
Future<void> _setupLocale() async {
  AscLocale.configure(
    supportedLocales: kSupportedLocales,
    languagePrefKey: PrefConst.language,
    followSystemPrefKey: PrefConst.followSystemLanguage,
  );
  final p = await SharedPreferences.getInstance();
  final saved = p.getString(PrefConst.language);
  final locale = saved == 'en_US' || saved == 'en'
      ? const Locale('en', 'US')
      : const Locale('vi', 'VN');
  await AscLocale.setAppLocale(locale);
  await AscLocale.loadTranslations();
}

/// Đăng ký repository / service / controller dùng toàn app.
Future<void> _setupDependencies() async {
  final api = Get.put(ApiClient(), permanent: true);
  final outbox = Get.put(OutboxRepository(), permanent: true);
  final events = Get.put(EventRepository(outbox), permanent: true);
  final gifts = Get.put(GiftRepository(outbox), permanent: true);
  final plan = Get.put(PlanRepository(outbox), permanent: true);

  final settings = await Get.put(SettingsController(), permanent: true).init();
  final sync = await Get.put(
    SyncService(api, outbox, events, gifts, plan),
    permanent: true,
  ).init();
  final eventC = Get.put(
    EventController(events, gifts, settings, sync),
    permanent: true,
  );
  final giftC = Get.put(GiftController(gifts, eventC, sync), permanent: true);
  Get.put(
    RecordingController(api, gifts, eventC, giftC, settings),
    permanent: true,
  );
  Get.put(
    GiftListController(gifts, giftC, eventC, sync),
    permanent: true,
  );
  Get.put(PlanController(plan, eventC, sync), permanent: true);
  Get.put(GoogleAuthService(api, settings, sync), permanent: true);
  Get.put(ShellController(), permanent: true);
}

class GiftFlowApp extends StatelessWidget {
  const GiftFlowApp({super.key});

  @override
  Widget build(BuildContext context) => GetMaterialApp(
        title: 'GiftFlow AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        themeMode: ThemeMode.light,
        locale: AscLocale.getAppLocale(),
        fallbackLocale: const Locale('en', 'US'),
        supportedLocales: kSupportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        initialRoute: RouteName.splash,
        getPages: AppPages.pages,
        // Hỗ trợ chữ lớn tới 1.3x nhưng không phá layout.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(
                minScaleFactor: 0.9,
                maxScaleFactor: 1.3,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
}

/// Ẩn thanh điều hướng của máy (3 nút); thanh trạng thái vẫn giữ để xem giờ/pin.
void _hideNavigationBar() {
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );
}

class _SystemUiObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _hideNavigationBar();
  }

  @override
  void didChangeMetrics() {
    // Bàn phím đóng/mở có thể làm thanh điều hướng hiện lại.
    _hideNavigationBar();
  }
}
