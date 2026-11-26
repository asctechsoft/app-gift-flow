import 'dart:ui';

import 'package:asc_common/asc_common.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../configs/pref_const.dart';

/// Cài đặt người dùng (permanent): ngôn ngữ, tuỳ chọn ghi âm, onboarding.
class SettingsController extends GetxController {
  late SharedPreferences _p;

  final RxString displayName = ''.obs;
  final RxString accountEmail = ''.obs;
  final RxBool autoSilenceCut = true.obs;
  final RxInt silenceMs = 5000.obs;

  /// Tự lưu khi AI đọc rõ ràng (tên + số tiền, không nghi trùng).
  final RxBool autoSave = true.obs;
  final Rx<Locale> locale = const Locale('vi', 'VN').obs;

  Future<SettingsController> init() async {
    _p = await SharedPreferences.getInstance();
    displayName.value = _p.getString(PrefConst.displayName) ?? '';
    accountEmail.value = _p.getString(PrefConst.accountEmail) ?? '';
    autoSilenceCut.value = _p.getBool(PrefConst.autoSilenceCut) ?? true;
    silenceMs.value = _p.getInt(PrefConst.silenceMs) ?? 5000;
    autoSave.value = _p.getBool(PrefConst.autoSave) ?? true;
    locale.value = AscLocale.getAppLocale();
    return this;
  }

  bool get onboardingSeen => _p.getBool(PrefConst.onboardingSeen) ?? false;

  Future<void> markOnboardingSeen() =>
      _p.setBool(PrefConst.onboardingSeen, true);

  String? get activeEventId => _p.getString(PrefConst.activeEventId);

  Future<void> setActiveEventId(String? id) async {
    if (id == null) {
      await _p.remove(PrefConst.activeEventId);
    } else {
      await _p.setString(PrefConst.activeEventId, id);
    }
  }

  bool get isSignedIn => accountEmail.value.isNotEmpty;

  /// Lưu/xoá thông tin tài khoản Google (null = đăng xuất).
  Future<void> setAccount({String? email, String? name}) async {
    if (email == null) {
      accountEmail.value = '';
      await _p.remove(PrefConst.accountEmail);
      return;
    }
    accountEmail.value = email;
    await _p.setString(PrefConst.accountEmail, email);
    if (displayName.value.isEmpty && (name ?? '').isNotEmpty) {
      await setDisplayName(name!);
    }
  }

  Future<void> setDisplayName(String v) async {
    displayName.value = v.trim();
    await _p.setString(PrefConst.displayName, displayName.value);
  }

  Future<void> setAutoSilenceCut(bool v) async {
    autoSilenceCut.value = v;
    await _p.setBool(PrefConst.autoSilenceCut, v);
  }

  Future<void> setAutoSave(bool v) async {
    autoSave.value = v;
    await _p.setBool(PrefConst.autoSave, v);
  }

  Future<void> setSilenceMs(int v) async {
    silenceMs.value = v;
    await _p.setInt(PrefConst.silenceMs, v);
  }

  Future<void> setLanguage(Locale l) async {
    await _p.setBool(PrefConst.followSystemLanguage, false);
    await AscLocale.setAppLocale(l);
    locale.value = l;
  }
}
