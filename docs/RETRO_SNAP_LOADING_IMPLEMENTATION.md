# SNAPLEASE — Retro Snap Loading

Ngày triển khai: 19/10/2026. Repository: `D:\KhoaLuan\Mobile\rentcam`.
Nhánh giữ nguyên: `mobile`; HEAD lúc bắt đầu: `dc7ad35f02bdb1710789474e0ab6e47d77a83de6`.

## Phạm vi và bảo toàn source

Đã đọc `RULES.md`, `PROJECT_CONTEXT.md`, kiểm tra theme, widget chung, states,
dependencies, assets và diff Explore trước khi sửa. Không tìm thấy `AGENTS.md`
hoặc `AI_RULES.md` trong phạm vi kiểm tra. Yêu cầu thiết kế loading trong tác vụ
là căn cứ cho giao diện mới; không thay design system.

Các thay đổi có sẵn trước tác vụ: `android/gradle.properties`, `lib/app/app.dart`,
`lib/app/router/app_router.dart`, `lib/core/network/api_config.dart`,
`lib/core/storage/token_storage.dart`, account page, contract detail page,
device detail page, Explore page, HomeHeader, test API page; các file chưa track
thuộc cart/review, app image viewer, Google services và tài liệu/test liên quan.
Chỉ Explore được sửa thêm phần loading và format; badge/cart navigation có sẵn
được giữ nguyên. Các file review/gia hạn không cần sửa trực tiếp.

Không đổi nhánh, stash, commit, push, reset, clean hoặc thay Backend/API/SQL.
Không build/cài APK, không gọi API ghi nghiệp vụ. Các test API dùng adapter giả.

## Quyết định reuse

| Nhu cầu | Thành phần sẵn có | Quyết định |
| --- | --- | --- |
| Camera/loading toàn vùng | `app_loading.dart` trống | Tạo vector loader và `SnapLoadingView`; giữ file trống nguyên trạng |
| Nút đang gửi | `PrimaryButton.isLoading` | Giữ button/khóa nút; thay nội dung bằng `SnapButtonLoader` |
| Skeleton | Cart skeleton tĩnh, notification skeleton trong page | Giữ cart; tách notification thành widget feature và dùng shimmer chung |
| Màu/typography/khoảng cách | `AppTheme`, `AppColors`, `AppText`, `AppSizes` | Reuse; chỉ thêm token kem trang trí tập trung |
| Animation assets | Chỉ có image/font assets, không có animation runtime sẵn | Dùng Flutter SDK, không thêm asset/package |

## File mới

| File | Mục đích |
| --- | --- |
| `lib/core/widgets/loading_motion.dart` | Một clock/vùng; quản lý lifecycle, TickerMode, reduced motion và dispose |
| `lib/core/widgets/retro_camera_loader.dart` | Camera CustomPainter 5 pha, dots, progress và `SnapLoadingProgress` cho refresh |
| `lib/core/widgets/snap_loading_view.dart` | Bố cục SafeArea/cuộn cho vùng chờ; camera nhỏ dùng trong button |
| `lib/core/widgets/snap_skeleton.dart` | Primitive `SkeletonBox`, shimmer chung, loại bỏ focus/tương tác/semantics giả |
| `lib/features/home/presentation/widgets/product_card_skeleton.dart` | Skeleton ảnh/tên/rating/giá/actions; grid 2 cột, aspect .7 dùng cho Home/Explore |
| `lib/features/contract/presentation/list/widgets/contract_card_skeleton.dart` | ID/badge, thumbnail 80px, thông tin/ngày thuê, chi phí/action |
| `lib/features/notification/presentation/widgets/notification_item_skeleton.dart` | Icon tròn 44px, title, description, timestamp theo NotificationCard |
| `lib/loading_preview.dart` | Entrypoint debug độc lập; xem ba cỡ, light/dark, reduced motion, skeletons |
| `test/retro_camera_loader_test.dart` | Test preview, frame các pha/vòng lặp, kích thước/theme, lifecycle/dispose, semantics/state replacement |
| `test/snap_loading_integration_test.dart` | Test skeleton, button và chuyển trạng thái thực tế ở 4 view qua BLoC được điều khiển trong test |
| `docs/RETRO_SNAP_LOADING_IMPLEMENTATION.md` | Bàn giao triển khai và giới hạn kiểm chứng |

## File đã chỉnh sửa

| File | Thay đổi |
| --- | --- |
| `lib/core/constants/app_colors.dart` | Thêm `AppColors.loadingCream`, không đổi primary/trạng thái/giá |
| `lib/core/widgets/primary_button.dart` | Camera nhỏ thay spinner; semantics theo nhãn nút; giữ nguyên `isLoading`/callback |
| `lib/features/home/presentation/home_page.dart` | Giữ header/search/banner và skeleton tại vùng sản phẩm; giữ cards cũ khi refresh |
| `lib/features/explore/presentation/explore_page.dart` | Skeleton cho initial/loading khi chưa có sản phẩm; giữ error/retry/load-more hiện tại |
| `lib/features/contract/presentation/list/contract_list_page.dart` | Skeleton hợp đồng khi chưa có dữ liệu; giữ nội dung cũ và báo refresh cục bộ |
| `lib/features/notification/presentation/notification_page.dart` | Thay skeleton nội bộ bằng widget feature/shimmer; giữ cards khi đang làm mới |
| `lib/features/main/presentation/main_layout.dart` | TickerMode theo tab IndexedStack để dừng animation ở tab ẩn |

Không tạo/sửa BLoC/Cubit, repository, routing hay request. Formatter có thay đổi
trình bày trong các page được sửa; phần nghiệp vụ giữ nguyên.

## Animation

Một `AnimationController` chạy chu kỳ 3.000ms và chỉ repaint phần camera/dots/
progress. Camera dùng tọa độ vector 240×240, không dùng PNG/emoji/spinner:

1. **0–600ms — Wind Up:** bounce nhẹ và nghiêng thân; cần film và bánh răng quay riêng.
2. **600–1.200ms — Focus:** lens nở nhẹ, vòng nét xoay, brackets thu vào, thân hơi nghiêng.
3. **1.200–1.600ms — Snap:** sáu lá khẩu độ đóng/mở, thân giật nhẹ; glow cục bộ 120ms,
   không flash toàn màn hình.
4. **1.600–2.500ms — Print:** ảnh Polaroid trượt qua khe, nghiêng nhẹ, ảnh bên trong hiện dần.
5. **2.500–3.000ms — Reset:** ảnh thu về; vòng nét/thân trở về vị trí đầu, camera luôn hiện.

Frame 0 và 3.000ms được so sánh pixel và khớp; năm frame giữa chu kỳ khác nhau.
Camera có `RepaintBoundary`; skeleton dùng một controller cho cả list/grid,
giữ child trong AnimatedBuilder để không rebuild cards mỗi frame.

API công khai của loader/view: `message`, `subtitle`, `size`, `showProgress`,
`showAnimatedDots`. Cỡ gợi ý: `RetroCameraLoader.small` (96), `medium` (180),
`large` (240); nhận số dương tùy chọn. Message mặc định:
“Đang chuẩn bị thiết bị cho bạn”. Không hiển thị phần trăm hoặc trì hoãn API.

Primary lấy từ `Theme.of(context).colorScheme.primary`: light `#1D39C4`, dark
dùng token hiện có. Shimmer dùng surface của theme; kem là màu trang trí riêng.
Reduced motion giữ camera tĩnh, dots tĩnh, thanh tiến trình tĩnh và dừng shimmer;
không vẽ tiến độ hoàn thành giả. Semantics được gộp theo vùng, không đọc từng frame.
Clock dừng khi app background hoặc TickerMode tắt và tiếp tục từ vị trí đã dừng.

## Tích hợp và giới hạn phạm vi

| Vùng | Kết quả / kiểm chứng |
| --- | --- |
| App initialization | Không tích hợp: `main.dart`/app không có state chờ toàn màn hình phù hợp. Không thêm state/splash/delay |
| Home | Skeleton grid cùng layout sản phẩm, giữ chrome; test initial → content → refresh giữ cards → error |
| Explore | Grid skeleton; test initial → content → failure/retry. Đổi criteria vẫn xóa danh sách theo BLoC hiện có; không sửa cache/filter |
| Contract List | Skeleton theo contract card; test initial → content → refresh giữ hợp đồng → error |
| Notification | Skeleton theo notification card; test initial → content → refresh giữ cards → error; hồi quy category/group vẫn đạt |
| Extension request | Qua `PrimaryButton.isLoading` với `_state.submitting`; giữ nguyên khóa gửi/Back; suite renewal đạt |
| Review submission | Qua `PrimaryButton.isLoading` với `state.isSubmitting`; giữ draft/khóa Back/chống gửi trùng/timeout/upload/publication; hai suite review đạt |

Các thanh refresh có chỗ cao 3px được giữ sẵn để không đẩy layout khi bật/tắt.
RefreshIndicator và cơ chế refresh sẵn có được giữ nguyên; không sửa cách phát
event/chờ response của BLoC. Spinner tải thêm và loading ở feature khác nằm ngoài
phạm vi chọn lọc. `PrimaryButton` là component chung nên các nút khác đang dùng
`isLoading` cũng nhận camera nhỏ.

## Kiểm chứng lần triển khai đầu

Môi trường: Flutter 3.38.6, Dart 3.10.7.

- Đã chạy `dart format` cho toàn bộ 17 file Dart thuộc tác vụ.
- Analyze riêng 17 file: **No issues found**.
- `flutter analyze --no-pub` toàn repository: **56 warning/info** ngoài các file
  loading được sửa (text field, cart header, signing logs, identity verification,
  rental state, các script test ở root...). Không sửa cảnh báo ngoài phạm vi.
- Bộ mới: **11/11 test đạt**, gồm 5 component/preview và 6 integration tests.
- Kiểm tra 320×480 với text scale 2 cho loader; skeleton và debug preview ở 320×568;
  light/dark, ba cỡ, reduced motion, mount/unmount nhiều lần, lifecycle, tab TickerMode,
  semantics, giữ nội dung refresh, loading → content/success/error và khóa button.
- Bộ hồi quy mở rộng: **96 đạt, 2 lỗi** khi chạy integration mới + notification,
  renewal, review feature/API, cart và login. Hai lỗi là `widget_test.dart:16`
  không tìm thấy nút “Đăng nhập” và `cart_feature_test.dart:428` không thấy “Xong”.
  Đã tái hiện cả hai trên bản sao tạm dùng `PrimaryButton` từ HEAD trước tác vụ;
  không sửa test, session hay cart flow để che lỗi.
- Đã xuất và xem frame raster Focus/Print bằng Flutter test; đây là kiểm tra hình
  trong test, không phải kiểm thử animation realtime hoặc hiệu năng GPU thiết bị.
- `git diff --check` các file tracked thuộc tác vụ: đạt. Kiểm tra toàn repo có
  blank line EOF tại `lib/app/app.dart` thuộc thay đổi có sẵn, giữ nguyên.

Lệnh chạy bộ mới:

```powershell
cd D:\KhoaLuan\Mobile\rentcam
flutter test --no-pub test/retro_camera_loader_test.dart test/snap_loading_integration_test.dart
```

Chế độ tùy chọn xuất frame PNG vào thư mục build (không phải assets production):

```powershell
flutter test --no-pub --dart-define=SNAP_LOADING_CAPTURE=true test/retro_camera_loader_test.dart
```

Các frame ở `build/loading-preview/camera_<milliseconds>.png`. Palette trong bài
test frame là fixture để so sánh pixel; loader runtime lấy màu từ AppTheme.

## Chạy preview

```powershell
cd D:\KhoaLuan\Mobile\rentcam
flutter run --debug -d chrome -t lib/loading_preview.dart
```

Preview không nằm trong navigation production; entrypoint từ chối chạy ngoài
debug. Sau lượt tinh chỉnh hình ảnh, preview có một loader chính trong vùng
390×844; công tắc dark/reduced motion nằm bên ngoài vùng mobile. Vùng mobile
co theo không gian cửa sổ, không thêm viền điện thoại/status bar giả hoặc header
kỹ thuật vào component production.

Đã chạy preview realtime bằng Chrome headless trong lượt tinh chỉnh bên dưới.
**Chưa xác minh runtime, độ mượt hoặc hiệu năng trên điện thoại Android thật**.
Không build/cài APK trong tác vụ này. Không thêm dependency hoặc animation asset.

## Tinh chỉnh hình ảnh theo ảnh tham khảo — 19/10/2026

Chỉ chỉnh 4 file: `lib/core/widgets/retro_camera_loader.dart`,
`lib/loading_preview.dart`, `test/retro_camera_loader_test.dart` và tài liệu này.
Không đổi giao diện sử dụng component, controller/lifecycle, chu kỳ 3 giây,
5 pha, các integration, skeleton, theme, BLoC/API/review/gia hạn hoặc Backend.
Không commit/push.

Khác biệt được xử lý:

- Thân máy có lớp vỏ sau, viền kim loại, bevel, mặt xanh chuyển sắc nhẹ và
  texture nhỏ; top plate sáng gọn hơn, không còn mảng kem lớn phẳng.
- Lens lớn hơn, có nhiều lớp housing/rim/focus knurling/kính/iris; lõi luôn tối
  kể cả Dark. Trước đó `onSurface` sáng ở Dark bị dùng làm kính nên tâm lens trắng.
- Nút chụp, cần lên film, viewfinder, flash và khe in được vẽ thành chi tiết riêng.
- Thêm quầng sáng radial, vòng trang trí và bóng mềm cục bộ. Không thêm layer
  blur toàn màn hình hoặc controller; giữ RepaintBoundary và reduced motion.
- Primary runtime vẫn lấy AppTheme: Light `#1D39C4`, Dark `#3856E3`.
  Không dùng màu tím từ ảnh mẫu và không đổi màu app.
- Preview chỉ có một loader, không còn danh sách nhiều cỡ/skeletons trong
  cùng vùng đối chiếu. Debug controls được tách ra ngoài canvas mobile.

Kết quả kiểm tra sau tinh chỉnh:

- **12/12 test liên quan đạt** (6 camera/preview/comparison, 6 integration).
- Analyze 3 file Dart đã sửa: **No issues found**; đã format.
- Hai ảnh đối chiếu là **390×844, cùng chính xác 900ms / Focus**; bài test
  kiểm tra `progress.value == .3` ở cả hai theme, không dùng ảnh khác pha.
- Đã chạy `flutter run --debug -d web-server --web-port 59041
  --web-hostname 127.0.0.1 -t lib/loading_preview.dart` và xem các frame của
  preview Chrome thực tế. Ghi 40 frame PNG khác nhau trong khoảng 5,2 giây,
  ghép thành GIF với thời gian lấy mẫu thực tế; không ghi nhận exception JS.
  Bảng frame cho thấy thân/cần film, iris và ảnh in thay đổi qua vòng lặp.
- Đã bật reduced motion trong browser: hai screenshot cách nhau 1.200ms
  giống hệt nhau sau khi hiệu ứng tap kết thúc. Đã kiểm tra Dark trong browser.
- Bản ghi là ảnh chụp lấy mẫu khoảng 8fps, **không phải benchmark FPS**; không
  dùng nó để khẳng định đạt 60fps hoặc độ mượt trên Android thật.

Artifact để duyệt (trong `build/`, không đưa vào assets production):

| Artifact | File |
| --- | --- |
| Light 390×844, 900ms | `build/loading-preview/mobile_light_900.png` |
| Dark 390×844, 900ms | `build/loading-preview/mobile_dark_900.png` |
| Chuyển động browser thực tế | `build/loading-preview/runtime_preview.gif` |
| Bảng frame browser | `build/loading-preview/runtime_contact_sheet.png` |
| Dark/reduced motion runtime | `build/loading-preview/runtime/runtime_dark.png` |

Lưu ý font khi render test: hai file `assets/fonts/Roboto-*.ttf` đang chứa HTML
(header `<!DOCTYPE html>`), không phải font TTF hợp lệ. Đã giữ nguyên các asset
này ngoài phạm vi yêu cầu. Ảnh duyệt được nạp Roboto hợp lệ từ Flutter SDK chỉ
trong test; không thay font hoặc cấu hình font của app. Có thể tái tạo bằng:

```powershell
flutter test --no-pub --dart-define=SNAP_LOADING_CAPTURE=true --dart-define=SNAP_LOADING_FONT_DIR=D:/flutter/flutter/bin/cache/artifacts/material_fonts test/retro_camera_loader_test.dart test/snap_loading_integration_test.dart
```

Không truyền `SNAP_LOADING_FONT_DIR` thì test dùng font mặc định của môi trường
test. Kiểm tra runtime trình duyệt dùng cơ chế font hiện có của app.

## Tích hợp camera lớn trong ứng dụng thật — cập nhật theo yêu cầu mới

Phần này thay thế chính sách initial skeleton trong các mục triển khai trước.
Không sửa painter, controller, theme, API/BLoC/Cubit, auth/session, policy review,
đối soát hay logic gia hạn. Giữ toàn bộ thay đổi local trước lượt này.

### Điểm loading đã kiểm tra

| Màn/vùng | Trước lượt này | Sau lượt này |
| --- | --- | --- |
| Home | Product skeleton chính | Camera lớn trong vùng nội dung, giữ HomeHeader và Bottom Navigation |
| Explore | Product skeleton chính | Camera lớn bên dưới AppBar/search/filter; tải thêm vẫn spinner nhỏ ở cuối grid |
| Contract List | Contract skeleton chính | Camera lớn bên dưới header/status chips; refresh giữ hợp đồng + progress nhỏ |
| Notification List | Notification skeleton chính | Camera lớn dưới header/filter; refresh giữ thông báo; tải thêm giữ spinner nhỏ |
| Cart | Cart skeleton chính | Camera lớn khi chưa có dữ liệu; giữ AppBar, cached cart và hành vi refresh |
| Device Detail | Hai nhánh spinner toàn vùng | Camera lớn cho tải chi tiết và chờ khởi tạo thông tin thuê; giữ AppBar/Back/cart badge |
| Contract Detail | Spinner giữa body | Camera lớn khi chưa có contract; có dữ liệu thì giữ nội dung + progress nhỏ |
| Contract Tracking | Spinner trước khi xác minh dữ liệu | Camera lớn, giữ AppBar/Back và refresh hiện có |
| Review | Spinner tải form; camera nhỏ trong nút gửi | Camera lớn tải form; lớp phủ camera lớn khi `state.isSubmitting` |
| Renewal | Thanh progress và camera nhỏ trong nút | Camera lớn khi tải đầu chưa có state contract; lớp phủ khi `state.submitting`; quote/refresh dùng progress nhỏ |

Loader còn lại ngoài phạm vi lượt này: payment/payment-result, auth/register,
khởi tạo camera eKYC, vùng hồ sơ trong rental confirmation, availability/lịch,
ảnh bàn giao, icon/nút phụ và network image placeholder. Không khẳng định đã
thay mọi CircularProgressIndicator trong app. `catalog/*.txt` không phải màn Dart
runtime. Các skeleton feature vẫn được giữ để tái sử dụng, không xóa component.

### Lớp phủ gửi review/gia hạn

`SnapLoadingOverlay` được thêm ngay trong `core/widgets/snap_loading_view.dart`;
đây là wrapper bố cục sử dụng **SnapLoadingView + RetroCameraLoader hiện có**,
không phải loader/painter/controller mới. Wrapper luôn giữ child mounted.

- Stack phủ lên Scaffold hiện tại, bao gồm AppBar và vùng action; backdrop dùng
  surface của theme. Không push route hoặc thay form bằng một màn loading khác.
- Form/controller/draft còn bên dưới; chặn pointer và semantics nền khi phủ,
  TickerMode dừng animation nền. Phần loader vẫn dùng lifecycle/reduced motion cũ.
- Padding theo keyboard inset giúp camera nằm trong phần màn hình nhìn thấy;
  SafeArea/scroll giữ khả năng hiển thị ở màn hình nhỏ.
- Giữ `PopScope` và callback Back nguyên trạng bên ngoài wrapper. Chủ màn hình
  tiếp tục quyết định thời điểm khóa/gỡ bằng state thật.
- `PrimaryButton.showLoadingAnimation` mặc định true; riêng review/gia hạn dùng
  false trong lúc `isLoading` vẫn true. Nút vẫn tự vô hiệu hóa callback nhưng
  không chạy camera nhỏ đồng thời với camera lớn.
- Review dùng thông điệp “Đang xử lý đánh giá của bạn”; renewal dùng “Đang xử lý
  yêu cầu gia hạn”. Không có thời gian chờ tối thiểu, phần trăm giả hoặc POST mới.
- Đối soát review còn `isSubmitting` thì tiếp tục phủ. Gia hạn khi chuyển sang
  đọc lại hợp đồng với dữ liệu cũ sẽ gỡ phủ và dùng progress nhỏ. Timeout/uncertain
  tiếp tục hiện trạng thái/khóa/đối soát do Cubit hiện có quyết định; không tự
  báo thành công hay gửi lại.

### File tác động trong lượt tích hợp

12 file Dart production:

- `lib/core/widgets/snap_loading_view.dart`: wrapper lớp phủ dùng loader hiện có.
- `lib/core/widgets/primary_button.dart`: tùy chọn tắt animation nhỏ nhưng vẫn khóa nút.
- `lib/features/home/presentation/home_page.dart`
- `lib/features/explore/presentation/explore_page.dart`
- `lib/features/notification/presentation/notification_page.dart`
- `lib/features/cart/presentation/cart_page.dart`
- `lib/features/device_detail/presentation/device_detail_page.dart`
- `lib/features/contract/presentation/list/contract_list_page.dart`
- `lib/features/contract/presentation/contract_page.dart`
- `lib/features/contract/presentation/tracking/contract_tracking_page.dart`
- `lib/features/contract/presentation/renewal/contract_renewal_page.dart`
- `lib/features/review/presentation/review_page.dart`

Test mới: `test/app_loading_entrypoint_test.dart`. Test cập nhật:
`test/snap_loading_integration_test.dart` (assert camera initial theo yêu cầu mới,
giữ kiểm tra refresh/content/error và standalone skeleton). Tài liệu này được cập
nhật. Các file có local diff như contract/device/cart/review được đọc trước khi
sửa; giữ review picker, cart badge, request guards và API integration có sẵn.

### Kiểm chứng lượt tích hợp

- **117 test đạt**: entrypoint/overlay + camera + integration + review API/feature,
  renewal, contract navigation/back/detail layout, notification feature.
- Bootstrap gọi **`main.dart` thật**, dùng `RentCamApp` và router production,
  không dùng `loading_preview.dart` để kết luận integration.
- Đã đi qua route Home/Explore/Contract List/Notification/Device Detail/Contract
  Detail/Review trong trạng thái GET đang chờ; xác nhận loader cỡ 240 và chrome
  AppBar/Bottom Navigation thuộc màn đang tải. Cart được kiểm tra riêng với
  request giữ bằng Completer vì root app đã preload cart khi bootstrap.
- Adapter của test main chỉ cho GET tổng hợp, không gửi ra mạng; session giả
  nằm trong SharedPreferences mock của test, không sửa auth/session production.
- Test review/renewal dùng page/Cubit thật với repository giả: overlay một camera,
  không camera nhỏ; nút khóa, Back bị chặn, draft/reason còn nguyên, gỡ lớp phủ
  khi success hoặc timeout/đối soát thất bại. Kiểm tra chỉ có một lần gửi, không
  thông báo thành công giả khi kết quả chưa xác định.
- Tải đầu gia hạn đặt camera trong body, giữ AppBar và nút Back hoạt động;
  chỉ trạng thái submitting mới phủ toàn màn hình. Có test riêng xác nhận vùng
  tải đầu không có ModalBarrier của overlay và nút Back vẫn có callback.
- Các test hồi quy review vẫn xác minh DTO/publication/session/timeout/upload;
  không chỉnh test để bỏ các assertion này. Test Back cũ có cảnh báo hit-test
  khi cố tap AppBar đang bị ModalBarrier che, đúng trạng thái mới; test vẫn đạt.
- Đã format file tác động. Analyze phạm vi tác vụ không có lỗi/warning mới;
  còn info `curly_braces_in_flow_control_structures` ở callback reload tracking
  có sẵn, ngoài phần loading; không sửa luồng đó.
- Không build/cài APK, không commit/push. **Chưa chạy phiên bản tích hợp này
  trên điện thoại thật**. Kiểm chứng entrypoint ở đây là widget test, không phải
  kiểm thử Android runtime hoặc kết nối API production.

Lệnh test đã chạy:

```powershell
flutter test --no-pub test/app_loading_entrypoint_test.dart test/snap_loading_integration_test.dart test/retro_camera_loader_test.dart test/review_api_integration_test.dart test/review_feature_test.dart test/contract_renewal_test.dart test/contract_navigation_back_test.dart test/contract_detail_layout_test.dart test/notification_feature_test.dart
```

Chạy ứng dụng thật để kiểm tra thủ công:

```powershell
flutter run --debug -t lib/main.dart
```

Entrypoint/router giữ nguyên cấu hình hiện tại (initial location `/test-api`),
không tự chuyển sang trang preview hoặc thay đổi điều hướng/auth của dự án.

## Hoàn thiện tích hợp toàn ứng dụng — 19/10/2026

Phần này cập nhật quyết định dùng camera lớn cho tải đầu và thao tác gửi chính;
các mô tả skeleton chính hoặc camera nhỏ trong nút ở lịch sử phía trên không còn
là lựa chọn cho những luồng đã tích hợp dưới đây. Không thay painter, animation
5 pha/3 giây, màu thương hiệu, controller hoặc lifecycle/reduced motion.

Đã đọc RULES.md, PROJECT_CONTEXT.md; không tìm thấy AGENTS.md áp dụng. Repository
`rentcam`, branch `mobile`, HEAD `dc7ad35f02bdb1710789474e0ab6e47d77a83de6`.
Workspace có nhiều thay đổi tracked/untracked trước lượt này; giữ nguyên chúng,
không stash/reset/clean/chuyển nhánh/commit/push. Không sửa Backend, DB, build,
API, repository, BLoC/Cubit, auth/session hay TTL trong lượt này.

### Ma trận rà soát `lib/`

Đường dẫn trong bảng tương đối từ `lib/features/`, trừ khi ghi `core/` hoặc `main.dart`.
“Đã có” nghĩa là giữ tích hợp camera lớn từ lượt trước, không sửa lại logic.

| Màn/thao tác | Loading đã rà soát | Cách hiển thị cuối cùng và lý do | File chính |
| --- | --- | --- | --- |
| Khởi tạo/khôi phục phiên | `main.dart` khởi tạo định dạng; không có state chờ khôi phục phiên riêng | Không áp dụng; không tạo splash/request giả | `main.dart`, `app/app.dart`, `app/router/app_router.dart` |
| Đăng nhập | PrimaryButton loading nhỏ | Overlay camera lớn theo LoginStatus.loading, giữ controller/form, unfocus bàn phím; nút khóa và tắt camera nhỏ | `auth/login/presentation/login_page.dart` |
| Đăng ký | Spinner trong nút | Overlay theo RegisterStatus.loading, giữ input/consent và AppBar Back; nút chỉ đổi nhãn | `auth/register/presentation/register_page.dart` |
| OTP tài khoản, quên/đổi mật khẩu | Không có luồng OTP tài khoản/đổi mật khẩu hoàn chỉnh; quên mật khẩu là placeholder | Chưa có/không áp dụng; không dựng state/request | Router và auth presentation |
| Home | Đã có SnapLoadingView tải đầu | Camera lớn khi chưa có dữ liệu; RefreshIndicator khi refresh | `home/presentation/home_page.dart` |
| Explore/tìm kiếm/lọc | Đã có camera tải đầu; spinner cuối danh sách | Camera khi chưa có dữ liệu; giữ danh sách, scroll và chỉ báo nhỏ cho refresh/phân trang | `explore/presentation/explore_page.dart` |
| Chi tiết thiết bị | Camera tải đầu đã có; Continue dùng camera nút | Overlay khi isCreatingReservation; giữ device/dates/branch, nút khóa và không camera nhỏ | `device_detail/presentation/device_detail_page.dart`, `widgets/device_detail_widgets.dart` |
| Lịch khả dụng/báo giá thiết bị | Spinner tại khu vực riêng | Giữ nhỏ; không che nội dung thiết bị/các vùng độc lập | `core/widgets/app_availability_calendar.dart`, `device_detail/presentation/widgets/device_detail_widgets.dart` |
| Giỏ hàng | Đã có camera tải đầu; cập nhật số lượng spinner tại item | Giữ camera đầu, RefreshIndicator, spinner item; không đổi nguồn mock/API | `cart/presentation/cart_page.dart`, `widgets/cart_item_card.dart` |
| Chụp/quét CCCD | Spinner khởi tạo camera/chụp ảnh | Giữ giao diện camera và chỉ báo tại chỗ; không overlay camera preview | `identity_verification/presentation/custom_camera_page.dart` |
| Gửi xử lý/xác nhận CCCD | Camera nhỏ trong nút | Một overlay lớn khi loading/confirming; giữ dữ liệu trích xuất, form và chính sách Back hiện có | `identity_verification/presentation/identity_verification_page.dart`, `widgets/verification_result_review.dart` |
| Giữ chỗ/TTL | Spinner nhỏ khi đồng bộ thời hạn | Giữ ReservationTimer ngoài body overlay; Timer/Stopwatch tiếp tục chạy; không reset TTL | `core/widgets/reservation_timer.dart` |
| Xác nhận thuê/tạo hợp đồng | Nhãn nút đang tạo; hồ sơ và quote loading tại khu vực | Overlay isCreatingContract, giữ form/timer/AppBar; hồ sơ/quote vẫn là loading cục bộ độc lập | `rental_confirmation/presentation/rental_confirmation_page.dart` |
| Danh sách hợp đồng | Đã có camera tải đầu | Giữ camera lớn; refresh/tải thêm chỉ báo nhỏ và dữ liệu hiện có | `contract/presentation/list/contract_list_page.dart` |
| Chi tiết hợp đồng | Camera tải đầu; đang xử lý/tải PDF chỉ có khóa nút/chỉ báo nhỏ | Giữ camera đầu; overlay khi tải PDF hoặc hành động isLoading có contract cũ; khóa bottom actions, giữ Back. Gắn overlay PDF với contractId đang tải | `contract/presentation/contract_page.dart` |
| Tracking hợp đồng | Đã có camera tải đầu | Giữ camera đầu, tiến trình cập nhật nhỏ với dữ liệu đã có | `contract/presentation/tracking/contract_tracking_page.dart` |
| Xem PDF | PdfPreview spinner mặc định | Truyền SnapLoadingView lớn vào loadingWidget; giữ lỗi PDF có sẵn | `contract/presentation/contract_preview_page.dart` |
| Chuẩn bị PDF/gửi ký | Camera nhỏ trong nút; cờ _isGeneratingPdf | Overlay theo cờ UI hoặc ContractSigningLoading; giữ chữ ký/đồng ý điều khoản. finally gỡ cờ UI kể cả lỗi tạo PDF; không thay kết quả hay request | `contract/presentation/signature_page.dart` |
| Xác minh OTP ký | Camera nhỏ trong nút | Overlay theo ContractSigningOtpVerifying; giữ OTP/timer. Footer dùng lại hành động “Đóng lại (để kiểm tra sau)” đang có; không thêm hủy request | `contract/presentation/widgets/otp_verification_dialog.dart` |
| Thanh toán tải đầu | Spinner vùng lớn | Camera lớn trước kết quả đọc đầu tiên | `payment/presentation/payment_page.dart` |
| Tạo thanh toán/chủ động kiểm tra | Spinner/lớp che cũ, camera nút | Overlay khi PaymentCreating hoặc PaymentChecking từ nút chủ động; khóa nút và tắt camera nhỏ | Cùng file payment_page.dart |
| Đọc lại thanh toán khi resume/refresh | QR có thể mất khi state không chứa payment | Giữ snapshot UI từ state thật để QR/scroll còn nguyên; SnapLoadingProgress nhỏ; pull-to-refresh không bật overlay | Cùng file payment_page.dart |
| Kết quả thanh toán | Spinner tải đầu | Camera lớn ban đầu; overlay khi người dùng kiểm tra lại và đã có payment; giữ nội dung cũ, xử lý chưa rõ kết quả theo luồng có sẵn | `payment/presentation/payment_result_page.dart` |
| Gia hạn | Đã có camera tải đầu và overlay submit | Giữ form/reason, khóa gửi/Back theo cơ chế có sẵn; timeout/đối soát không suy diễn thành công | `contract/presentation/renewal/contract_renewal_page.dart` |
| Đánh giá/upload ảnh | Đã có camera tải đầu và overlay submit | Giữ draft/ảnh, khóa gửi/Back, một camera; giữ nguyên chống gửi trùng/đối soát upload và publication | `review/presentation/review_page.dart` |
| Danh sách thông báo | Đã có camera đầu, spinner phân trang | Camera đầu; refresh/phân trang nhỏ, giữ danh sách | `notification/presentation/notification_page.dart` |
| Chi tiết thông báo | Nội dung được truyền sẵn; skeleton hợp đồng liên quan | Giữ skeleton chỉ ở thẻ hợp đồng độc lập; thông báo vẫn đọc được. Item thiếu trả lỗi ngay, không có request chính để gắn loading | `notification/presentation/notification_detail_page.dart` |
| Badge/chưa đọc/đánh dấu đã đọc | Không có screen-level wait | Không thêm overlay | Notification BLoC và header hiện có |
| Tài khoản/cập nhật hồ sơ | Không có state cập nhật hồ sơ; logout dùng luồng hiện có | Không áp dụng/chưa có; không tạo state giả hoặc sửa session | `account/presentation/account_page.dart` |
| Ảnh/thumbnail/QR/ảnh bàn giao | Placeholder/spinner/progress ảnh | Giữ cục bộ và tiến trình thật, không che màn chỉ vì ảnh | Device widgets, payment_page, contract_handover_card, review image widgets |
| Test API | Spinner nút kiểm tra sức khỏe | Giữ chỉ báo nhỏ cho thao tác debug | `test_api/presentation/test_api_page.dart` |
| Skeleton còn trong source | ProductCardSkeleton, ContractCardSkeleton, NotificationItemSkeleton, CartLoadingSkeleton, SnapSkeleton | Các định nghĩa giữ lại, không dùng thay camera chính của các màn đã tích hợp; catalog_page.txt là tài liệu, không phải Dart runtime | Các file widgets skeleton và `catalog/catalog_page.txt` |

### Reuse và giới hạn state

- Reuse `RetroCameraLoader`, `SnapLoadingView`, `SnapLoadingOverlay`,
  `SnapLoadingProgress`, `PrimaryButton.showLoadingAnimation` và theme hiện có.
- Mở rộng tối thiểu `core/widgets/snap_loading_view.dart`: footer tùy chọn để
  giữ hành động đóng OTP; avoidKeyboardInsets để body đã được Scaffold resize
  không trừ bàn phím hai lần. Component không gọi API hoặc điều khiển Back.
- Overlay nằm trong body ở các màn có AppBar/Back/timer riêng; chặn chỉnh form
  bên dưới bằng AbsorbPointer, ẩn semantics của form đang bị che. Không thêm
  PopScope mới. Hành vi Back/cancel của từng màn vẫn do màn đó quyết định.
- OTP là overlay riêng khi verifying; state gửi ký của trang cha không chạy
  thêm một camera phía sau. Trang ký kiểm tra route hiện tại trước khi vẽ overlay.
- PaymentBloc không có request ID/origin cho PaymentChecking. UI chỉ đánh dấu
  thao tác nút chủ động; refresh/resume không đặt cờ này. Không thêm polling,
  retry, global interceptor hoặc ép mọi request nền thành modal. Với request
  đồng thời và kết quả đảo thứ tự, state nghiệp vụ hiện có vẫn là nguồn quyết
  định; lượt này không refactor BLoC để bổ sung nhận dạng request.
- Không có state tiến trình upload số byte trong màn đánh giá để hiển thị %;
  không tạo phần trăm giả. Tiến trình ảnh có sẵn vẫn được giữ.
- Không thêm delay cho đủ chu kỳ animation. API trả nhanh thì overlay kết thúc
  ngay. Không thực hiện API ghi thật hay build/cài APK trong tác vụ.

### Kiểm chứng bổ sung

- Bộ hồi quy 13 file lần cuối: **164 test đạt**, gồm 12 test mới cho các
  tích hợp bổ sung và giữ chỗ.
  Bao gồm `app_loading_entrypoint_test.dart` gọi bootstrap `main.dart`/router
  thật, không dùng preview để suy ra tích hợp production.
- Test mới `screen_loading_coverage_test.dart`: login giữ credentials và route
  success/late state; register giữ username/consent; xác minh giữ dữ liệu khi
  lỗi; giữ chỗ thất bại giữ vùng cuộn và lựa chọn ngày/chi nhánh; TTL hết hạn
  trong overlay chỉ xử lý một lần và response muộn không mở
  lại route; tạo hợp đồng giữ rental state/timer; ký giữ controller, nét ký và
  checkbox; OTP giữ input/lỗi/đóng khi đang gửi; thanh toán giữ QR Element/scroll
  khi đọc nền, explicit check riêng, tạo thanh toán khóa gửi và gỡ khi lỗi;
  kết quả chưa rõ không suy diễn thành công; PDF dùng camera rồi gỡ khi lỗi.
- Tất cả dùng repository giả, state điều khiển hoặc Dio adapter trong test;
  POST được giữ tại adapter, không ra mạng. Test không bỏ assertion/skip;
  dùng pump hữu hạn. Lỗi fixture Future của test POST đã sửa tại fixture,
  không sửa PaymentBloc/repository để làm test đạt.
- Analyze phạm vi 15 file: còn cảnh báo `dead_code` có sẵn tại
  `identity_verification_page.dart:142` (nhánh debug `kDebugMode || true`).
  Không sửa nhánh nghiệp vụ/debug ngoài phạm vi. Info dấu ngoặc ở test mới
  đã được sửa. Không khẳng định analyze toàn repo sạch.
- Test camera/overlay đã bao gồm Light/Dark, reduced motion, lifecycle,
  kích thước hẹp/chữ lớn. Chưa kiểm thử bản tích hợp này trên điện thoại,
  chưa xác minh native scanner/keyboard/printing bằng Android runtime.
- Các lỗi baseline trước đây ở `widget_test.dart` (mong route login trong khi
  initialLocation hiện tại là test-api) và cart Sửa/Xong nằm ngoài bộ test trên;
  không sửa hoặc tuyên bố toàn bộ suite sạch.
- `git diff --check` toàn workspace còn blank line cuối `lib/app/app.dart:50`
  thuộc thay đổi local trước lượt này; không chỉnh file đó để dọn ngoài phạm vi.

Lệnh hồi quy lượt này:

```powershell
flutter test --no-pub test/screen_loading_coverage_test.dart test/app_loading_entrypoint_test.dart test/snap_loading_integration_test.dart test/retro_camera_loader_test.dart test/review_api_integration_test.dart test/review_feature_test.dart test/contract_renewal_test.dart test/contract_navigation_back_test.dart test/contract_detail_layout_test.dart test/notification_feature_test.dart test/payment_feature_test.dart test/notification_detail_test.dart test/identity_scanner_test.dart
```

### Checklist điện thoại — entrypoint thật

Chạy `flutter run --debug -t lib/main.dart` từ thư mục rentcam; giữ cấu hình
router hiện có, đi từ màn thật (initialLocation hiện là `/test-api`). Không dùng
`loading_preview.dart` làm bằng chứng cho tích hợp ứng dụng.

- [ ] Light/Dark, màn hẹp/chữ lớn: camera giữa body, không overflow; AppBar,
  Bottom Navigation và Back phù hợp; không hai camera cùng lúc.
- [ ] Login/register: bàn phím đóng khi gửi, chạm gửi lặp không thêm request;
  lỗi giữ input/consent; success đi đúng route.
- [ ] Home/Explore/cart/contracts/notification: tải đầu một camera lớn;
  refresh/phân trang giữ nội dung và scroll, không modal.
- [ ] Device: giữ ngày/chi nhánh khi giữ chỗ lỗi; lịch và quote chỉ loading
  cục bộ, không che thiết bị vì thumbnail.
- [ ] CCCD: scanner vẫn thao tác được; gửi/xác nhận mới overlay; lỗi giữ dữ
  liệu; hết hạn trong request theo luồng cũ, không reset TTL/điều hướng hai lần.
- [ ] Tạo hợp đồng: form/timer giữ nguyên; gửi ký giữ chữ ký và checkbox khi
  lỗi; PDF lỗi gỡ loading. OTP sai giữ input; nút đóng hiện có vẫn dùng được.
- [ ] Thanh toán: QR không biến mất khi resume/refresh; chủ động kiểm tra có
  một overlay; không chặn QR liên tục do đọc nền. Timeout/chưa rõ không hiện
  thành công và không tự gửi lại POST.
- [ ] Đánh giá/gia hạn: draft/ảnh/reason giữ nguyên; submit khóa đúng; luồng
  đối soát sau timeout/409/upload chưa rõ kết quả vẫn như trước.
- [ ] Back/đổi route/logout trong request theo chính sách cũ: không overlay
  kẹt hoặc response cũ mở lại màn. Background/resume dừng/chạy animation đúng.
- [ ] Reduced motion bật: nội dung chờ đọc được, không ép vòng animation.

Chỉ thao tác ghi trên môi trường/tài khoản kiểm thử phù hợp khi người dùng tự
kiểm tra; tác vụ source này không gọi API ghi thật.
