# Splendor Online (Flutter) + Firebase + Voice Chat

![CI](https://github.com/Duong200x/App-Web/actions/workflows/ci.yml/badge.svg)

Ứng dụng Flutter mô phỏng trò chơi **Splendor** dạng **chơi online nhiều người**, dùng **Firebase Auth + Firestore** để quản lý phòng/ván chơi và **Agora Voice** (mobile) để voice chat trong phòng.

## Tính năng chính

- **Đăng nhập**: Firebase Auth (có Google Sign-In).
- **Online realtime**: Firestore collection `splendor_rooms` lưu room + `gameState`.
- **Gameplay**: lấy token, mua thẻ, giam thẻ, nobles, tính điểm, xử lý timeout theo lượt.
- **Voice chat (mobile)**: Agora RTC; lấy token từ 1 endpoint (Vercel/Node server).
- **Hỗ trợ web**: web chạy UI/gameplay; voice chat web đang là stub/no-op.

## Yêu cầu

- **Flutter SDK**: 3.x (Dart `>=3.0.0 <4.0.0` theo `pubspec.yaml`)
- **Firebase project** (Auth + Firestore)
- (Tuỳ chọn) **Agora project** nếu dùng voice chat trên mobile

## Cài đặt & chạy nhanh

```bash
flutter pub get
flutter run
```

Chạy trên web:

```bash
flutter run -d chrome
```

## Cấu hình Firebase

Repo này **không commit** các file config Firebase theo máy/project để tránh lộ thông tin cấu hình:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist` (nếu có)

Bạn cần tự tạo Firebase project và cấu hình theo các bước:

1) Tạo project trên Firebase Console, bật **Authentication** (ví dụ Google) và **Cloud Firestore**.  
2) Thêm app Android (package ví dụ đang là `com.example.splendor_fake`), tải `google-services.json` và đặt vào:

`android/app/google-services.json`

3) Cập nhật `lib/firebase_options.dart` (hiện đang là placeholder). Cách chuẩn:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Sau đó chạy lại:

```bash
flutter pub get
flutter run
```

## Firestore: collections + rules (starter)

App đang dùng các collection chính:

- `splendor_users/{uid}`: lưu hồ sơ người chơi (name, email, avatarUrl, isSetup…)
- `splendor_rooms/{roomId}`: lưu room + `players[]` + `status` + `hostId` + `gameState`…
- `splendor_time/now`: doc phục vụ đồng bộ thời gian lượt (client set serverTimestamp rồi đọc lại)

Repo đã có sẵn file rules/indexes để deploy bằng Firebase CLI:

- `firestore.rules`
- `firestore.indexes.json`

Lưu ý: vì game state được cập nhật từ client, rules hiện tại là **starter “an toàn vừa đủ”** (không cho người ngoài ghi vào room ngẫu nhiên) chứ chưa phải rules chặt chẽ cho môi trường production.

## Cấu hình Voice Chat (Agora) (tuỳ chọn)

Mobile app gọi API để lấy `token` + `appId` tại:

- `lib/services/voice_service_mobile.dart` (hiện đang trỏ đến một URL Vercel)

Repo có kèm 1 token server mẫu tại `agora-token-server/` (dành cho Vercel).

### Chạy token server local (tuỳ chọn)

1) Vào thư mục token server và cài dependencies:

```bash
cd agora-token-server
npm install
```

2) Tạo file env từ mẫu:

```bash
copy .env.example .env
```

Sau đó điền:

- `AGORA_APP_ID`
- `AGORA_APP_CERTIFICATE`

3) Chạy (cần Vercel CLI):

```bash
vercel dev
```

4) Sửa URL API trong `lib/services/voice_service_mobile.dart` để trỏ về server của bạn.

### Deploy token server lên Vercel (gợi ý)

1) Deploy thư mục `agora-token-server/` lên Vercel (Import Project).
2) Thêm Environment Variables trên Vercel:
   - `AGORA_APP_ID`
   - `AGORA_APP_CERTIFICATE`
3) Lấy URL endpoint theo dạng `/api/token` và cập nhật trong `lib/services/voice_service_mobile.dart`.

## Cấu trúc thư mục (rút gọn)

- `lib/`: Flutter app (UI + logic)
- `lib/screens/online_game_board_screen.dart`: màn hình bàn chơi online
- `lib/logic/online_game_manager.dart`: thao tác game state lên Firestore
- `agora-token-server/`: token server mẫu cho Agora (không commit `.env`, không commit `node_modules`)

## Ghi chú bảo mật

- **Không commit** `.env` và các certificate/secret của Agora.
- Firebase web config/API key thường là “public” nhưng vẫn **khuyến nghị** cấu hình theo project của bạn và giới hạn rule/keys phù hợp.
