# GiftFlow AI

Monorepo: `mobile/` (Flutter app) + `backend/` (NestJS API).

```bash
# Backend (http://localhost:3000, Swagger /docs). Đặt OPENAI_API_KEY trong backend/.env
cd backend && npm install && npm run start:dev

# App (Android emulator)
cd mobile && flutter run --flavor dev --dart-define=API_BASE_URL=http://10.0.2.2:3000
```
Chi tiết: `backend/README.md`, `mobile/README.md`. Key API chỉ nằm ở `backend/.env` (không commit).
`mobile/pubspec.yaml` dùng `asc_common` qua `path: ../../asc_common`.
