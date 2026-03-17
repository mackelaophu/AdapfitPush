# AdapfitPush – macOS Firebase Push Sender

macOS app Swift thay thế `send_push.py` — gửi FCM push notification qua Firebase HTTP v1 API.

## Tính năng
- Import `serviceAccount.json` bằng **drag-and-drop** hoặc file picker
- Gửi đến **Topic** hoặc **Device Token**
- Cấu hình đầy đủ: Title, Body, data payload, APNS headers
- Live log cuộn được, hiển thị kết quả gửi
- **Không cần Python, không có thư viện ngoài** — JWT RS256 được ký bằng `Security.framework` có sẵn

## Yêu cầu
- macOS 13+
- Xcode 15+
- File `serviceAccount.json` từ Firebase Console → Project Settings → Service Accounts

## Cách mở
1. Mở `AdapfitPush.xcodeproj` trong Xcode
2. Chọn **Team** trong Signing & Capabilities
3. Nhấn **Run** ▶

## Cấu trúc files
```
AdapfitPush/
├── AdapfitPushApp.swift       # App entry point
├── ContentView.swift          # UI chính (SwiftUI)
├── PushViewModel.swift        # Logic / state management
├── ServiceAccountModel.swift  # Decode serviceAccount.json
├── JWTSigner.swift            # JWT RS256 + OAuth2 token exchange
├── FCMService.swift           # FCM HTTP v1 API caller
├── Info.plist
└── AdapfitPush.entitlements
```

## So sánh với send_push.py

| send_push.py | AdapfitPush (Swift) |
|---|---|
| `google.oauth2.service_account` | `Security.SecKey` + JWT RS256 tự viết |
| `requests.post()` | `URLSession.shared.data(for:)` async/await |
| Config trong source code | UI nhập liệu trực quan |
| Terminal output | Live log panel |
