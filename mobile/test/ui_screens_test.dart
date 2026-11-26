// Chụp màn hình các màn hình đã thiết kế lại với dữ liệu mẫu (SQLite thật qua ffi),
// font thật (Roboto của Flutter SDK) -> phát hiện tràn bố cục (overflow) và lỗi runtime.
// Ảnh nằm ở test/_shots/*.png (không commit).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:asc_common/asc_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gift_flow/controller/event_controller.dart';
import 'package:gift_flow/controller/gift_controller.dart';
import 'package:gift_flow/controller/gift_list_controller.dart';
import 'package:gift_flow/controller/settings_controller.dart';
import 'package:gift_flow/models/data_models/gift_event.dart';
import 'package:gift_flow/models/data_models/gift_record.dart';
import 'package:gift_flow/models/ui_models/gift_status.dart';
import 'package:gift_flow/presentation/common_components/ui_kit.dart';
import 'package:gift_flow/presentation/screen_events/event_detail_screen.dart';
import 'package:gift_flow/repository/gift_filter.dart';
import 'package:gift_flow/presentation/screen_events/events_tab.dart';
import 'package:gift_flow/presentation/screen_gifts/gift_filter_sheet.dart';
import 'package:gift_flow/presentation/screen_gifts/gifts_tab.dart';
import 'package:gift_flow/presentation/screen_home/home_tab.dart';
import 'package:gift_flow/presentation/screen_shell/shell_screen.dart';
import 'package:gift_flow/presentation/screens_settings/settings_tab.dart';
import 'package:gift_flow/repository/event_repository.dart';
import 'package:gift_flow/repository/gift_repository.dart';
import 'package:gift_flow/repository/outbox_repository.dart';
import 'package:gift_flow/services/application/api_client.dart';
import 'package:gift_flow/services/application/sync_service.dart';
import 'package:gift_flow/values/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final f = File(p);
    if (f.existsSync()) {
      loader.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    }
  }
  await loader.load();
}

Future<void> _shot(WidgetTester t, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await t.runAsync(() => boundary.toImage(pixelRatio: 1.5));
  final data = await t.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  final dir = Directory('test/_shots')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GiftRepository gifts;
  late EventRepository events;
  final key = GlobalKey();

  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'] ??
        'C:/Users/Asus/AppData/Local/Flutter_sdk/flutter';
    final fonts = '$root/bin/cache/artifacts/material_fonts';
    await _loadFont('Roboto', [
      '$fonts/Roboto-Regular.ttf',
      '$fonts/Roboto-Bold.ttf',
      '$fonts/Roboto-Medium.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = Directory.systemTemp.createTempSync('giftflow_ui');
    await databaseFactory.setDatabasesPath(dir.path);
    SharedPreferences.setMockInitialValues({});

    AscLocale.configure(
      supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
      languagePrefKey: 'language',
      followSystemPrefKey: 'follow_system',
    );
    await AscLocale.setAppLocale(const Locale('vi', 'VN'));
    await AscLocale.loadTranslations();

    final outbox = Get.put(OutboxRepository());
    events = Get.put(EventRepository(outbox));
    gifts = Get.put(GiftRepository(outbox));
    final settings = await Get.put(SettingsController()).init();
    final sync = Get.put(SyncService(ApiClient(), outbox, events, gifts));
    final eventC = Get.put(EventController(events, gifts, settings, sync));
    Get.put(GiftController(gifts, eventC, sync));
    Get.put(GiftListController(gifts, Get.find<GiftController>(), eventC, sync));
    Get.put(ShellController());

    // ---- dữ liệu mẫu giống bản vẽ
    final now = DateTime.now();
    String iso(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final wedding = GiftEvent(
      id: 'e1', name: 'Đám Cưới', type: 'wedding',
      eventDate: iso(now.subtract(const Duration(days: 1))),
    );
    final bday = GiftEvent(
      id: 'e2', name: 'Sinh Nhật Bảo An', type: 'birthday',
      eventDate: iso(now.add(const Duration(days: 30))),
    );
    final baby = GiftEvent(
      id: 'e3', name: 'Thôi Nôi Minh Khang', type: 'baby_month',
      eventDate: iso(now.subtract(const Duration(days: 90))),
    );
    for (final e in [wedding, bday, baby]) {
      await events.save(e);
    }
    final rows = <(String, String, String, int, GiftStatus, int)>[
      ('Chị Thi', 'Bạn cô dâu', 'e1', 250000, GiftStatus.confirmed, 0),
      ('Anh Nam', 'Bạn chú rể', 'e1', 500000, GiftStatus.confirmed, 0),
      ('Anh Quang', 'Bạn cơ quan', 'e1', 12000000, GiftStatus.confirmed, 0),
      ('Anh Hùng', 'Họ hàng', 'e1', 0, GiftStatus.pendingReview, 0),
      ('Chị Phương', 'Bạn cô dâu', 'e1', 5000000, GiftStatus.confirmed, 1),
      ('Chị Phương', 'Đồng nghiệp', 'e1', 4950000, GiftStatus.confirmed, 1),
      ('Cô Lan', 'Đồng nghiệp', 'e1', 1000000, GiftStatus.confirmed, 2),
      ('Bác Hùng', 'Bạn bố', 'e1', 5000000, GiftStatus.confirmed, 3),
      ('Em Mai', 'Gia đình', 'e2', 500000, GiftStatus.confirmed, 1),
    ];
    var i = 0;
    for (final r in rows) {
      await gifts.save(
        GiftRecord(
          id: 'g${i++}', eventId: r.$3, guestName: r.$1, relationship: r.$2,
          amountVnd: r.$4, status: r.$5,
          source: i.isEven ? GiftSource.voice : GiftSource.manual,
          createdAt: now.subtract(Duration(days: r.$6, minutes: i * 7)),
        ),
        enqueue: false,
      );
    }
    await eventC.load();
    await Get.find<GiftController>().reload();
    await Get.find<GiftListController>().reload();
  });

  Future<void> pumpShot(
    WidgetTester t,
    Widget child,
    String name, {
    Future<void> Function()? after,
    int settleMs = 500,
  }) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: GetMaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light.copyWith(
            textTheme: AppTheme.light.textTheme.apply(fontFamily: 'Roboto'),
          ),
          locale: const Locale('vi', 'VN'),
          home: Scaffold(
            backgroundColor: const Color(0xFFF6F0FF),
            body: child,
          ),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 300));
    // cho các truy vấn SQLite thật (ngoài FakeAsync) chạy xong rồi dựng lại
    await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: settleMs)));
    await t.pump(const Duration(milliseconds: 600));
    if (after != null) {
      await after();
      await t.pump(const Duration(milliseconds: 600));
    }
    await _shot(t, key, name);
    expect(t.takeException(), isNull, reason: 'tràn bố cục / lỗi ở $name');
    // xả các timer chờ khóa của sqflite (tạo trong FakeAsync)
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 12));
  }

  test('Truy vấn danh sách/khách/xu hướng/lọc trả đúng dữ liệu', () async {
    final all = await gifts.search(const GiftFilter());
    expect(all.length, 9);
    // lọc theo loại sự kiện + khoảng tiền
    final wedding = await gifts.search(
      const GiftFilter(eventType: 'wedding', minAmount: 1000000, maxAmount: 6000000),
    );
    expect(wedding.map((r) => r.gift.guestName).toSet(), {'Chị Phương', 'Cô Lan', 'Bác Hùng'});
    expect((await gifts.search(const GiftFilter(eventType: 'birthday'))).length, 1);
    // tìm không dấu
    expect((await gifts.search(const GiftFilter(query: 'phuong'))).length, 2);
    // sắp xếp theo tiền giảm dần
    final sorted = await gifts.search(const GiftFilter(sort: GiftSort.amountDesc));
    expect(sorted.first.gift.guestName, 'Anh Quang');
    // gộp khách (Chị Phương 2 phong bì)
    final guests = await gifts.guests('e1');
    final phuong = guests.firstWhere((g) => g.name == 'Chị Phương');
    expect(phuong.count, 2);
    expect(phuong.totalVnd, 9950000);
    expect(guests.first.name, 'Anh Quang'); // nhiều tiền nhất
    // chờ xác nhận không cộng vào tổng khách
    expect(guests.firstWhere((g) => g.name == 'Anh Hùng').totalVnd, 0);
    // xu hướng cộng dồn = tổng đã xác nhận
    final trend = await gifts.trend('e1');
    expect(trend.last.cumulativeVnd, 28700000);
    expect(trend.length, greaterThanOrEqualTo(2));
  });

  testWidgets('Trang chủ', (t) async {
    await t.runAsync(() async {
      await Get.find<EventController>().setActive('e1');
      await Get.find<GiftController>().reload();
    });
    await pumpShot(t, const HomeTab(), 'home');
  });

  testWidgets('Sự kiện', (t) async {
    await pumpShot(t, const EventsTab(), 'events');
  });

  testWidgets('Danh sách tiền mừng', (t) async {
    await pumpShot(t, const GiftsTab(), 'gifts');
  });

  testWidgets('Bộ lọc', (t) async {
    await pumpShot(
      t,
      const GiftsTab(),
      'filter',
      after: () async {
        showGiftFilterSheet(Get.find<GiftListController>());
        await t.pump(const Duration(milliseconds: 700));
      },
    );
  });

  testWidgets('Cài đặt', (t) async {
    await pumpShot(t, const SettingsTab(), 'settings');
  });

  testWidgets('Biểu đồ xu hướng + donut', (t) async {
    await pumpShot(
      t,
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TrendChart(
              points: [
                TrendPoint(DateTime(2026, 11, 1), 2000000, 2000000),
                TrendPoint(DateTime(2026, 11, 2), 8000000, 10000000),
                TrendPoint(DateTime(2026, 11, 3), 3000000, 13000000),
                TrendPoint(DateTime(2026, 11, 4), 8000000, 21000000),
                TrendPoint(DateTime(2026, 11, 5), 6000000, 27000000),
              ],
            ),
            const SizedBox(height: 20),
            const DonutChart(values: [2, 1, 1], centerTop: '4', centerBottom: 'Khách'),
          ],
        ),
      ),
      'charts',
    );
  });

  for (final tab in [0, 1, 2, 3]) {
    testWidgets('Chi tiết sự kiện tab $tab', (t) async {
      Get.testMode = true;
      await pumpShot(
        t,
        Builder(
          builder: (ctx) {
            Get.routing.args = {'id': 'e1', 'tab': tab};
            return const EventDetailScreen();
          },
        ),
        'event_detail_$tab',
        settleMs: 2500,
      );
    });
  }
}
