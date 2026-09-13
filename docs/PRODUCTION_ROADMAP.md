# Lộ Trình Nâng Cấp Thực Chiến & Chiến Lược Quản Lý Bộ Nhớ
## (iOS Native Production Readiness Roadmap & Memory Management Strategy)

> **Mục đích tài liệu:** Lưu trữ toàn bộ các phân tích, đề xuất kỹ thuật nâng cao và chiến lược quản lý bộ nhớ để phát triển ứng dụng cấp độ Enterprise / Fintech trong tương lai, trong khi vẫn giữ template ở trạng thái tối giản, sạch sẽ và nhẹ nhất ở hiện tại (Lean Template Core).

---

## Mục lục

- [I. Triết Lý Thiết Kế: Core Tinh Gọn (Lean Core)](#i-triết-lý-thiết-kế-core-tinh-gọn-lean-core)
- [II. Chiến Lược Quản Lý Bộ Nhớ Toàn Diện (iOS Memory Management Strategy)](#ii-chiến-lược-quản-lý-bộ-nhớ-toàn-diện-ios-memory-management-strategy)
  - [1. Phân cấp Scope & Vòng đời đối tượng (Scope Hygiene)](#1-phân-cấp-scope--vòng-đời-đối-tượng-scope-hygiene)
  - [2. Quản lý bộ nhớ & Tối ưu hóa trong SwiftUI](#2-quản-lý-bộ-nhớ--tối-ưu-hóa-trong-swiftui)
  - [3. Chiến lược nạp & giải phóng hình ảnh (Image Caching & Downsampling)](#3-chiến-lược-nạp--giải-phóng-hình-ảnh-image-caching--downsampling)
  - [4. Ứng phó áp lực bộ nhớ hệ điều hành (Low Memory & Memory Pressure)](#4-ứng-phó-áp-lực-bộ-nhớ-hệ-điều-hành-low-memory--memory-pressure)
  - [5. Tối ưu dữ liệu lớn: Pagination & JSON Streaming](#5-tối-ưu-dữ-liệu-lớn-pagination--json-streaming)
  - [6. Giám sát & Phát hiện rò rỉ bộ nhớ (Leak Detection & Instruments)](#6-giám-sát--phát-hiện-rò-rỉ-bộ-nhớ-leak-detection--instruments)
- [III. Chiến Lược Quản Lý Quyền Chuẩn Mực (iOS Permission Management Strategy)](#iii-chiến-lược-quản-lý-quyền-chuẩn-mực-ios-permission-management-strategy)
  - [1. Phân loại quyền trên iOS hiện đại (iOS 16–18+)](#1-phân-loại-quyền-trên-ios-hiện-đại-ios-1618)
  - [2. Ranh giới Clean Architecture & MVI đối với Quyền](#2-ranh-giới-clean-architecture--mvi-đối-với-quyền)
  - [3. Luồng UX: Rationale, Vĩnh Viễn Từ Chối & Suy Thoái Mềm (Graceful Degradation)](#3-luồng-ux-rationale-vĩnh-viễn-từ-chối--suy-thoái-mềm-graceful-degradation)
  - [4. Quản lý quyền trong Super App (Just-in-Time Permissions)](#4-quản-lý-quyền-trong-super-app-just-in-time-permissions)
  - [5. Giải pháp thay thế không cần quyền (SwiftUI PhotosPicker)](#5-giải-pháp-thay-thế-không-cần-quyền-swiftui-photospicker)
- [IV. Ba Bài Toán Sống Còn Cho Siêu Ứng Dụng (Super App Runtime Resilience)](#iv-ba-bài-toán-sống-còn-cho-siêu-ứng-dụng-super-app-runtime-resilience)
  - [1. Quản trị tài nguyên & Vòng đời bộ nhớ: Giải phóng cưỡng bức (Force Eviction / LRU State Hibernation)](#1-quản-trị-tài-nguyên--vòng-đời-bộ-nhớ-giải-phóng-cưỡng-bức-force-eviction--lru-state-hibernation)
  - [2. Bảo mật ranh giới giữa các Mini App: Crash Isolation (Error Boundary) & Scoped Token Exchange](#2-bảo-mật-ranh-giới-giữa-các-mini-app-crash-isolation-error-boundary--scoped-token-exchange)
  - [3. Chiến lược phát hành & Giám sát độc lập: Remote Config & Router-Level Kill-Switch](#3-chiến-lược-phát-hành--giám-sát-độc-lập-remote-config--router-level-kill-switch)
- [V. Danh Mục Nâng Cấp Chiến Lược (Future Enhancements Backlog)](#v-danh-mục-nâng-cấp-chiến-lược-future-enhancements-backlog)
  - [1. Bảo Mật & Fintech Defense (Security Hardening)](#1-bảo-mật--fintech-defense-security-hardening)
  - [2. Khả Năng Chịu Tải & Offline-First (Resilience & Caching)](#2-khả-năng-chịu-tải--offline-first-resilience--caching)
  - [3. Design System & Micro-Interactions (UI/UX Kit)](#3-design-system--micro-interactions-uiux-kit)
  - [4. DevOps, CI/CD & Build Variants (Release Automation)](#4-devops-cicd--build-variants-release-automation)
  - [5. Khả Năng Quan Sát & Telemetry (Observability)](#5-khả-năng-quan-sát--telemetry-observability)
  - [6. Khôi Phục Trạng Thái khi Process Death (State Restoration)](#6-khôi-phục-trạng-thái-khi-process-death-state-restoration)
- [VI. Ma Trận Phân Kỳ Triển Khai (Prioritized Execution Matrix)](#vi-ma-trận-phân-kỳ-triển-khai-prioritized-execution-matrix)
- [VII. Tổng Kết & Đề Xuất Lộ Trình Hành Động (Summary & Next Steps Roadmap)](#vii-tổng-kết--đề-xuất-lộ-trình-hành-động-summary--next-steps-roadmap)

---

## I. Triết Lý Thiết Kế: Core Tinh Gọn (Lean Core)

Một template Super App iOS thành công phục vụ từ các dự án quy mô nhỏ (Startup / MVP) đến hệ sinh thái siêu ứng dụng Fintech hàng triệu người dùng cần tuân thủ nguyên tắc:
1. **Khung xương sạch sẽ (Zero Bloat):** Không tích hợp sẵn các SDK cồng kềnh, nặng nề của bên thứ ba (Firebase, Realm, Alamofire...) khi chưa có nhu cầu thực tế.
2. **Điểm mở rộng chuẩn mực (Well-defined Extension Seams):** Kiến trúc đã phân tách sẵn các interface và vị trí cắm ghép (Seams) tại `Packages/Platform`, `Packages/Core`, `Packages/Network` để khi cần bổ sung tính năng, kỹ sư chỉ việc "plug-in" mà không phải refactor cấu trúc cốt lõi.
3. **Kích hoạt theo nhu cầu (On-demand Adoption):** Tham khảo danh mục tài liệu này để lựa chọn và kích hoạt dần từng module theo yêu cầu thực tế của từng giai đoạn sản phẩm.

---

## II. Chiến Lược Quản Lý Bộ Nhớ Toàn Diện (iOS Memory Management Strategy)

Trong kiến trúc Super App đa module và SwiftUI, quản lý bộ nhớ trên iOS đòi hỏi kiểm soát chặt chẽ vòng đời đối tượng, luồng concurrency và tài nguyên đồ họa:

### 1. Phân cấp Scope & Vòng đời đối tượng (Scope Hygiene)

| Cấp độ | Vòng đời | Quy tắc áp dụng | Rủi ro nếu dùng sai |
|---|---|---|---|
| **App Singleton** | Toàn bộ tiến trình (`@main`) | **CHỈ** dành cho hạ tầng cấp thấp vô trạng thái hoặc cache cốt lõi: `APIClient`, `SecureCacheStore`, `SessionManager`, `AppRouter`. | Rò rỉ bộ nhớ vĩnh viễn (Retain Cycle cả vòng đời app) nếu gán state của Feature vào Singleton. |
| **Navigation Tab Scope** | Tồn tại theo từng Tab của Shell (`Platform.AppRouter`) | Dành cho Navigation path stack (`[AnyAppRoute]`) và điều phối chuyển tab. | Không lưu trữ View/Context tại đây. |
| **Screen / Feature Scope** | Gắn liền với vòng đời của View và `NavigationStack` | **Mọi business state và data của Feature phải nằm ở đây.** Sử dụng `@StateObject` trong SwiftUI View để ViewModel được khởi tạo 1 lần và tự hủy khi màn hình bị pop khỏi stack. | Dùng `@ObservedObject` thay cho `@StateObject` sẽ gây tái tạo ViewModel liên tục mỗi khi parent view render lại, gây tràn RAM và đứt gãy luồng Async Task. |

*   **Nguyên tắc Async Task & Cancellation:** Tuyệt đối không dùng `Task.detached` vô tội vạ. Toàn bộ hiệu ứng bất đồng bộ trong Feature phải được quản lý qua `MviViewModel.launch(key:)` hoặc `.task {}` modifier của SwiftUI. Khi màn hình biến mất, `cancelEffects()` và `onClear()` lập tức hủy các Task đang chạy, ngắt kết nối network và giải phóng memory buffer.

### 2. Quản lý bộ nhớ & Tối ưu hóa trong SwiftUI

SwiftUI dựng lại cây View thông qua cơ chế Re-evaluation của struct `body`. Nếu không kiểm soát, quá trình cấp phát bộ nhớ (Allocation Churn) sẽ diễn ra liên tục gây tràn Garbage Collection và giảm khung hình (Jank):

*   **Ổn định kiểu dữ liệu (`Equatable` State):**
    *   Các struct State UI (`*State`) nên conform `Equatable`.
    *   Sử dụng `.equatable()` modifier hoặc tách subview nhỏ để SwiftUI chỉ đánh giá lại các node thực sự có dữ liệu thay đổi.
*   **Thu gom tài nguyên danh sách lớn (`List` / `LazyVStack`):**
    *   Trong `ForEach`, luôn luôn chỉ định `id: \.id` với các model conform `Identifiable`.
    *   Tránh gán `id: \.self` cho các đối tượng lớn hoặc mutable, vì SwiftUI sẽ không thể tái sử dụng (recycle) cell node và buộc phải giữ toàn bộ cell trong bộ nhớ.
*   **Tránh Capture Retain Cycles:**
    *   Trong mọi closure async/Combine trong ViewModel, luôn dùng `[weak self]` để tránh giữ tham chiếu vòng tròn.

### 3. Chiến lược nạp & giải phóng hình ảnh (Image Caching & Downsampling)

Hình ảnh và Bitmap là nguyên nhân hàng đầu gây Out-Of-Memory (OOM) và crash trên thiết bị iOS cũ (RAM 2GB–3GB):

*   **Cấu hình RAM & Disk Cache trong `AppUIKit`:**
    *   Sử dụng `NSCache<NSURL, UIImage>` cho in-memory cache với giới hạn `totalCostLimit` (ví dụ: tối đa 25% physical memory khả dụng).
    *   Sử dụng `CacheStore` của `Core` để lưu trữ disk cache với cơ chế LRU tự động dọn dẹp file cũ.
*   **Downsampling chuẩn kích thước hiển thị (`CGImageSource`):**
    *   Không bao giờ nạp toàn bộ ảnh độ phân giải gốc 4K/8K vào bộ nhớ để hiển thị trong khung thumbnail 60x60.
    *   Luôn sử dụng `CGImageSourceCreateThumbnailAtIndex` với `kCGImageSourceThumbnailMaxPixelSize` khớp với kích thước của View để giải mã ảnh nhỏ trực tiếp từ đĩa/mạng, giảm 90% dung lượng RAM tiêu thụ.

### 4. Ứng phó áp lực bộ nhớ hệ điều hành (Low Memory & Memory Pressure)

Hệ điều hành iOS phát tín hiệu cảnh báo áp lực bộ nhớ trước khi tiêu diệt tiến trình (Jetsam kill):

*   **Lắng nghe cảnh báo trong `Core`:**
    *   Đăng ký `NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)`.
    *   Hoặc sử dụng `DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical])` để chủ động phản ứng ở cấp độ kernel.
*   **Chiến lược phản ứng:**
    *   *Mức Warning:* Xóa sạch cache ảnh trong RAM (`NSCache.removeAllObjects()`), dọn dẹp các JSON cache tạm thời.
    *   *Mức Critical:* Hủy các request pre-fetching đang chạy ngầm, kích hoạt thu nhỏ backstack.

### 5. Tối ưu dữ liệu lớn: Pagination & JSON Streaming

*   **Phân trang dữ liệu (Pagination):** Không bao giờ nạp toàn bộ danh sách 1,000+ bản ghi từ local cache/API vào một mảng `[Entity]` trong RAM. Bắt buộc dùng phân trang (Page Size: 20-50 items) và nạp tiếp khi user cuộn gần tới đáy.
*   **JSON Streaming Parsing:** Với các payload lớn (báo cáo, danh sách giao dịch), tận dụng `AsyncSequence` hoặc xử lý theo từng khối nhỏ thay vì nạp toàn bộ chuỗi JSON khổng lồ vào `Data` trước khi decode.

### 6. Giám sát & Phát hiện rò rỉ bộ nhớ (Leak Detection & Instruments)

*   **Xcode Memory Graph Debugger:**
    *   Kiểm tra định kỳ chu kỳ điều hướng: `Mở Feature -> Thao tác -> Nhấn Back ra ngoài`. Biểu tượng ViewModel và View của màn hình cũ phải được giải phóng hoàn toàn (không còn node tím cảnh báo retain cycle).
*   **Instruments Leaks & Allocations:**
    *   Chạy profile định kỳ để phát hiện các anonymous closures hoặc CoreFoundation objects chưa được giải phóng.

---

## III. Chiến Lược Quản Lý Quyền Chuẩn Mực (iOS Permission Management Strategy)

### 1. Phân loại quyền trên iOS hiện đại (iOS 16–18+)

| Nhóm quyền | Khai báo Info.plist | Hành vi cấp quyền | Cơ chế xử lý |
|---|---|---|---|
| **Camera** | `NSCameraUsageDescription` | Người dùng chọn "OK" hoặc "Don't Allow" | Quản lý qua `AVCaptureDevice.authorizationStatus` |
| **Microphone** | `NSMicrophoneUsageDescription` | Người dùng chọn "OK" hoặc "Don't Allow" | `AVAudioSession.sharedInstance().recordPermission` |
| **Photo Library** | `NSPhotoLibraryUsageDescription` | Full Access, Limited Access, hoặc Denied | **Ưu tiên dùng PhotosPicker** để không cần xin quyền! |
| **Notifications** | Không bắt buộc Info.plist | Dialog cấp quyền nhận thông báo đẩy | `UNUserNotificationCenter.requestAuthorization` |
| **Face ID** | `NSFaceIDUsageDescription` | Tự động kích hoạt khi gọi `LAContext` | `LocalAuthentication` framework |

### 2. Ranh giới Clean Architecture & MVI đối với Quyền

*   **Layer Domain (Pure Swift):**
    *   **CẤM:** Không import `AVFoundation`, `Photos`, `CoreLocation` (vi phạm rule **K3**).
    *   **NÊN:** Domain chỉ quản lý logic nghiệp vụ trừu tượng, ví dụ trạng thái `PermissionStatus` (`.authorized`, `.denied`, `.notDetermined`).
*   **Layer Presentation (SwiftUI & MVI):**
    *   Là nơi duy nhất tương tác với iOS SDK để xin quyền.
    *   **MVI Loop:**
        1. User chạm nút "Quét mã" -> View gọi `permissionHandler.requestCamera()`.
        2. Nhận kết quả từ iOS -> View phát Action: `viewModel.dispatch(.cameraPermissionResult(isGranted))`.
        3. ViewModel cập nhật State: `reduce { $0.hasCameraPermission = isGranted }`.
        4. View render camera scanner hoặc fallback UI.

### 3. Luồng UX: Rationale, Vĩnh Viễn Từ Chối & Suy Thoái Mềm (Graceful Degradation)

```text
[Người dùng chạm tính năng]
          ↓
[Kiểm tra status == .authorized?] ──(Đã cấp)──> [Khởi chạy tính năng ngay]
          ↓ (Chưa cấp)
[Kiểm tra status == .notDetermined?]
    ├── (Lần đầu) ──> [Hiển thị Rationale Dialog giải thích lý do] ──> [Gọi System Permission Prompt]
    └── (Đã Denied) ──> [Hiển thị Settings Redirect Dialog]
                               ├── (Mở Cài đặt) ──> [Mở UIApplication.openSettingsURLString]
                               └── (Hủy)         ──> [Suy thoái mềm (Graceful Degradation)]
```

*   **Nguyên tắc Suy thoái mềm (Graceful Degradation):**
    *   Ứng dụng **tuyệt đối không bao giờ crash** hoặc rơi vào màn hình đen khi bị từ chối quyền.
    *   Cung cấp giải pháp thay thế: Từ chối Camera khi quét mã QR -> Cung cấp nút *"Chọn ảnh QR từ thư viện"* hoặc *"Nhập mã thủ công"*.

### 4. Quản lý quyền trong Super App (Just-in-Time Permissions)

*   **Không xin quyền tập trung:** Không xin toàn bộ quyền khi vừa mở Super App (tránh gây phiền hà và làm giảm tỷ lệ onboard).
*   **Just-in-Time:** Chỉ khi người dùng bước vào tính năng cụ thể của Mini App (ví dụ tính năng quét mã của `ScannerFeature`) thì mới kích hoạt luồng xin quyền.

### 5. Giải pháp thay thế không cần quyền (SwiftUI PhotosPicker)

*   Để chọn ảnh avatar hoặc hóa đơn thanh toán: **Không cần xin quyền Photo Library**.
*   Sử dụng `PhotosPicker` của SwiftUI (`import PhotosUI`). Hệ thống sẽ mở picker ngoài tiến trình ứng dụng; người dùng chọn ảnh nào thì app chỉ nhận đúng data ảnh đó mà **hoàn toàn không cần khai báo `NSPhotoLibraryUsageDescription`**!

---

## IV. Ba Bài Toán Sống Còn Cho Siêu Ứng Dụng (Super App Runtime Resilience)

### 1. Quản trị tài nguyên & Vòng đời bộ nhớ: Giải phóng cưỡng bức (Force Eviction / LRU State Hibernation)

*   **Vấn đề:** Người dùng mở liên tiếp Mini App A ➡️ Mini App B ➡️ Mini App C... Nếu Host App không giải phóng các màn hình ngầm, việc tích lũy View hierarchy, ViewModel và Image Cache sẽ dẫn tới lỗi Memory Jetsam Kill từ iOS.
*   **Giải pháp kiến trúc: LRU Active Mini Apps Cache & Hibernation:**
    1.  Host Shell duy trì giới hạn Mini App hoạt động đồng thời (ví dụ: `MAX_ACTIVE_MINI_APPS = 3`).
    2.  Khi người dùng mở Mini App thứ 4, Host gửi tín hiệu **Hibernate** tới Mini App lâu nhất chưa tương tác:
        *   Mini App lưu snapshot state hiện tại vào `CacheStore` (hoặc `SceneStorage`).
        *   Giải phóng cache ảnh trong RAM liên kết với feature đó.
    3.  Khi người dùng pop ngược lại: Host kích hoạt luồng **Hydrate / Restore** từ snapshot để nạp lại dữ liệu liền mạch.

### 2. Bảo mật ranh giới giữa các Mini App: Crash Isolation (Error Boundary) & Scoped Token Exchange

*   **Vấn đề:**
    *   Một lỗi runtime unhandled (force unwrap `!`, `fatalError`) trong Mini App có thể kéo sập toàn bộ Super App.
    *   Mini App độc hại có thể nghe lén `AppEventBus` để đánh cắp Token xác thực.
*   **Giải pháp kiến trúc:**
    1.  **SwiftUI Safe Error Boundary:** Bọc mọi entry point của Mini App trong một container bảo vệ:
        ```swift
        public struct MiniAppContainer<Content: View>: View {
            let featureName: String
            let content: () -> Content
            @State private var hasError = false

            public var body: some View {
                if hasError {
                    AppErrorView(title: "Tính năng tạm thời gián đoạn", onRetry: { hasError = false })
                } else {
                    content()
                }
            }
        }
        ```
    2.  **Scoped Token Exchange:**
        *   Tuyệt đối không broadcast Master Access Token lên `AppEventBus`.
        *   Host App cung cấp cơ chế `TokenScoping`: Khi Mini App cần gọi API đặc thù, Host cấp **Downscoped Temporary Token** (chỉ có quyền trên đúng service của feature đó và hết hạn trong thời gian ngắn).

### 3. Chiến lược phát hành & Giám sát độc lập: Remote Config & Router-Level Kill-Switch

*   **Vấn đề:** Khi một Mini App gặp lỗi nghiêm trọng hoặc lỗ hổng bảo mật, thời gian chờ Apple App Store duyệt bản vá khẩn cấp (thường mất 12-48h) sẽ gây thiệt hại lớn.
*   **Giải pháp kiến trúc: Router-Level Kill-Switch:**
    *   Tích hợp trực tiếp `FeatureFlagGuard` vào chuỗi pipeline `DeepLinkGuard` sẵn có của `DeepLinkRouter`:
        ```mermaid
        flowchart LR
            URL["DeepLink / Tab Tap"] --> Router["DeepLinkRouter"]
            Router --> Guard{"FeatureFlagGuard"}
            Guard -- "Active" --> Target["Mở Mini App View"]
            Guard -- "Bảo trì / Lỗi" --> Maint["Màn hình Thông báo Bảo trì"]
        ```
    *   Host App cập nhật cấu hình Remote Config (Firebase Remote Config hoặc Backend Gateway).
    *   Nếu cờ `features.<name>.status == "MAINTENANCE"`, Router lập tức chặn điều hướng và hiển thị màn hình thông báo bảo trì mà không cần nộp bản cập nhật lên App Store.

---

## V. Danh Mục Nâng Cấp Chiến Lược (Future Enhancements Backlog)

### 1. Bảo Mật & Fintech Defense (Security Hardening)
*   **1.1 Biometrics Authentication Manager:**
    *   *Mục đích:* Xác thực Face ID / Touch ID an toàn chuẩn `LocalAuthentication`.
    *   *Vị trí:* `Packages/Core` (interface `BiometricAuthenticating`) và `Packages/AppUIKit` (UI prompt wrapper).
*   **1.2 Jailbreak & Hook Detector:**
    *   *Mục đích:* Phát hiện thiết bị đã bị bẻ khóa (Cydia, Sileo, Frida, Substrate, Simulator tampering).
    *   *Vị trí:* `Packages/Core/Sources/Core/Security/JailbreakDetector.swift`.
*   **1.3 Screen & Memory Privacy (App Switcher Protection):**
    *   *Mục đích:* Che mờ / ẩn thông tin nhạy cảm (số dư, mã OTP) khi người dùng mở App Switcher hoặc đưa app xuống background (`ScenePhase.inactive`).
    *   *Vị trí:* `App/Sources/Composition/PrivacyOverlayModifier.swift`.
*   **1.4 Network Security & SSL Pinning:**
    *   *Mục đích:* Khóa chặt certificate và chặn tấn công Man-In-The-Middle (MITM).
    *   *Vị trí:* `Packages/Network/Sources/Network/Security/SSLPinningDelegate.swift`.

### 2. Khả Năng Chịu Tải & Offline-First (Resilience & Caching)
*   **2.1 Realtime Network Connectivity Observer:**
    *   *Mục đích:* Theo dõi trạng thái mạng liên tục qua `Network.framework` (`NWPathMonitor`).
    *   *Vị trí:* `Packages/Core/Sources/Core/Network/NetworkMonitor.swift` phát ra `AnyPublisher<NetworkStatus, Never>`.
    *   *Giao diện:* `NetworkBannerView` trong `Packages/AppUIKit` tự động hiển thị thanh cảnh báo khi mất mạng.
*   **2.2 Intelligent Network Retry Interceptor:**
    *   *Mục đích:* Tự động thử lại theo cấp số nhân (Exponential Backoff) với các request idempotent gặp lỗi mạng chập chờn.
*   **2.3 Offline Cache & Sync Pattern:**
    *   *Mục đích:* Mẫu chuẩn nạp dữ liệu từ `CacheStore` trước, tải ngầm qua API sau và cập nhật UI.

### 3. Design System & Micro-Interactions (UI/UX Kit)
*   **3.1 Shimmer Loading Skeleton:**
    *   *Mục đích:* Hiệu ứng skeleton card chuyển động khi chờ tải dữ liệu (`View.shimmer()` modifier) thay cho activity indicator đơn điệu.
*   **3.2 Design System Tokens Hoàn Thiện:**
    *   *Mục đích:* Bổ sung Elevation / Shadow tokens, Corner Radius tokens vào `AppUIKit/DesignSystem`.
*   **3.3 Global Feedback & Dialog Coordinator:**
    *   *Mục đích:* Quản lý thông báo lỗi hệ thống, Toast, Alert, BottomSheet tập trung qua `AppEventBus`.

### 4. DevOps, CI/CD & Build Variants (Release Automation)
*   **4.1 Tuist Multi-Environment Configurations:**
    *   Cấu hình Base URL, Bundle Identifier (`.dev`, `.stg`, `.prd`), App Icon và Display Name riêng biệt qua Tuist Settings / `.xcconfig`.
*   **4.2 GitHub Actions Workflows Mẫu:**
    *   `.github/workflows/ci.yml`: Chạy tự động khi mở PR (`swiftlint --strict`, `swiftformat --lint`, `ArchTests`, `check_module_boundaries.sh`, `swift test`).
    *   `.github/workflows/release.yml`: Build production archive, chạy test tự động.

### 5. Khả Năng Quan Sát & Telemetry (Observability)
*   **5.1 Analytics Tracker Seam:**
    *   Khai báo protocol `AnalyticsTracker` tại `Packages/Platform`. Các Mini App chỉ phát event tracking qua interface này mà không phụ thuộc vào SDK bên thứ ba (Firebase, Mixpanel, AppsFlyer).
*   **5.2 MVI Action & State Breadcrumbs:**
    *   Tự động ghi log hành vi tương tác khi debug để đính kèm crash log trên Crashlytics.

### 6. Khôi Phục Trạng Thái khi Process Death (State Restoration)
*   **6.1 NavigationPath Persistence:**
    *   Lưu trữ `[AnyAppRoute]` của từng tab vào `SceneStorage` hoặc `CacheStore` để khôi phục chính xác vị trí người dùng khi app bị OS giải phóng bộ nhớ.

---

## VI. Ma Trận Phân Kỳ Triển Khai (Prioritized Execution Matrix)

| Giai đoạn | Hạng mục | Nhóm chức năng | Tác động kiến trúc | Khi nào cần áp dụng? |
|:---:|---|---|:---:|---|
| **Phase A (P0)** | **Network Connectivity Monitor & Offline Banner** | Core / AppUIKit | Thấp (Đã có sẵn seam) | Ngay khi app có tương tác API cần báo mất mạng |
| **Phase A (P0)** | **Biometrics Authentication Manager** (Face ID) | Security / Core | Trung bình | Dự án Fintech, Ngân hàng, Ví điện tử |
| **Phase A (P0)** | **Screen & Memory Privacy (App Switcher Blur)** | Security / UI | Thấp | Bảo vệ thông tin tài chính người dùng |
| **Phase A (P0)** | **Network Security & SSL Pinning** | Network / Security | Trung bình | Trước khi phát hành bản production đầu tiên |
| **Phase B (P1)** | **Shimmer Loading Skeleton** | AppUIKit | Thấp | Nâng cao trải nghiệm người dùng theo Design System |
| **Phase B (P1)** | **Router Kill-Switch (FeatureFlagGuard)** | Platform | Thấp (Tích hợp Guard) | Khi cần kiểm soát bật/tắt tính năng từ xa |
| **Phase B (P1)** | **Tuist Multi-Environment Configurations** | Build Config | Trung bình | Khi kết nối môi trường Staging/Production thật |
| **Phase C (P2)** | **Sandbox Mini App Runner** | Tooling / Tuist | Cao | Khi đội ngũ dev mở rộng nhiều team làm việc độc lập |
| **Phase C (P2)** | **Analytics Tracker Protocol** | Platform | Thấp (Đã có seam) | Khi đội ngũ Product yêu cầu đo lường dữ liệu |
| **Phase C (P2)** | **State Restoration khi Process Death** | Framework / Shell | Trung bình | Khi có các form nhập liệu phức tạp nhiều bước |

---

## VII. Tổng Kết & Đề Xuất Lộ Trình Hành Động (Summary & Next Steps Roadmap)

| STT | Hạng mục bổ sung | Phân loại | Độ cần thiết | Package dự kiến tác động |
|:---:|---|---|:---:|---|
| **1** | **Network Connectivity Monitor** + Thanh báo Offline | Network / UX | ⭐⭐⭐⭐⭐ | `Packages/Core`, `Packages/AppUIKit` |
| **2** | **Biometrics Authentication Manager** (Face ID / Touch ID) | Security | ⭐⭐⭐⭐⭐ | `Packages/Core`, `Packages/AppUIKit` |
| **3** | **Screen Privacy Protector** (Ẩn thông tin khi rời app) | Security | ⭐⭐⭐⭐⭐ | `App`, `Packages/AppUIKit` |
| **4** | **SSL Pinning Subsystem** mẫu | Security | ⭐⭐⭐⭐ | `Packages/Network` |
| **5** | **Shimmer Loading Skeleton** & Design Tokens | UI Kit | ⭐⭐⭐⭐ | `Packages/AppUIKit` |
| **6** | **Router Kill-Switch Guard** | Navigation | ⭐⭐⭐⭐ | `Packages/Platform` |
| **7** | **Tuist Multi-Environment Flavors** (Dev / Stg / Prd) | DevOps | ⭐⭐⭐⭐ | `Tuist/`, `Project.swift` |
| **8** | **Analytics Tracker Bridge** (`AnalyticsTracker` protocol) | Platform | ⭐⭐⭐⭐ | `Packages/Platform` |

---

> 💡 **Kết luận:** Template iOS hiện tại đã hoàn thiện xuất sắc về Kiến trúc Clean Architecture + MVI, điều hướng DeepLinkRouter, và hệ thống kiểm tra ranh giới AST (ArchTests). Danh mục lộ trình trên định hình đầy đủ chiến lược để nâng cấp dự án thành một Siêu ứng dụng Fintech cấp Enterprise hoàn chỉnh.
