# GiftFlow AI (Flutter app)

Quản lý tiền mừng cưới bằng giọng nói. Theo `GiftFlow_AI_Implementation_Blueprint_v1.docx`.

**Kiến trúc** (cùng kiểu `music_asc`): GetX + sqflite + SharedPreferences + XML strings (`lib/xml_strings`), dùng package chung `../asc_common` (path dependency).
`lib/`: `configs/ values/ models/ controller/ repository/ services/{storage,application}/ utils/ presentation/`.

**Local-first**: ghi SQLite + outbox → `SyncService` đẩy lên backend (`../app-gift-flow-backend`) khi có mạng.

## Chạy
```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000   # backend dev, Android emulator
flutter test
```
Backend: xem `../app-gift-flow-backend/README.md` (mặc định AI mock, chưa cần token).

Ghi chú: `android/app/google-services.json` đã đặt sẵn nhưng Firebase chưa được nối (blueprint không yêu cầu).

## Đăng nhập Google (tuỳ chọn)
1. Google Cloud/Firebase (project `app-gift-flow`): tạo OAuth client **Android** (package `com.asc.gift_flow` + SHA-1 của keystore debug/release) và một **Web client**.
2. App: `flutter run --dart-define=API_BASE_URL=... --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com`
3. Backend `.env`: `GOOGLE_CLIENT_IDS=<web-client-id>.apps.googleusercontent.com`
Chưa cấu hình thì nút hiện thông báo; app vẫn chạy bằng guest.

## Tính năng bổ sung
Nhóm khách (của mình / bố mẹ), Nhập nhanh (chip tiền + Lưu & thêm tiếp), quét phong bì bằng ML Kit (OCR trên máy, chỉ gợi ý), gom danh sách theo quan hệ.

## Build (giống muvik)
Flavor bắt buộc: `alpha | dev | product | claude` (`flutter run --flavor dev`). `python build.py` build APK + tăng version + phát hành thử; `python tool/build/build_aab.py` build bundle Play Store. Ký store: tạo `android/key.properties` (không commit), nếu không có thì ký debug.
