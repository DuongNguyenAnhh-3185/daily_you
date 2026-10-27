# Nhật ký hàng ngày — bản Việt hóa từ Daily You

Mã nguồn gốc: https://github.com/Demizo/Daily_You
Commit gốc: d9615d8b9bdb8c4074ba5c50043d9c3ea93dd16a (nhánh master, clone rút gọn).
Đây là bản chỉnh sửa của Daily You do Demizo và cộng đồng đóng góp phát triển, không phải ứng dụng chính thức. Giữ nguyên giấy phép GPL-3.0 và ADDITIONAL_TERMS.md. Tên riêng và Android application ID `vn.nhatkyviet.journal` phân biệt bản chỉnh sửa theo yêu cầu giấy phép.

## Mở ứng dụng trên Windows

Chạy `run-windows.ps1` trong thư mục này, hoặc mở:

`build\windows\x64\runner\Release\nhat_ky_viet.exe`

Giữ nguyên toàn bộ thư mục Release, bao gồm DLL và thư mục data. Chỉ sao chép tệp exe sẽ không đủ để chạy.

## Cài đặt và build lại

Máy đã có Flutter 3.47.2, Dart 3.13.2, Visual Studio 2022 và Windows SDK. Từ thư mục dự án:

```powershell
D:\flutter\bin\flutter.bat pub get
D:\flutter\bin\flutter.bat gen-l10n
D:\flutter\bin\flutter.bat analyze --no-pub
D:\flutter\bin\flutter.bat test --no-pub --concurrency=1
D:\flutter\bin\flutter.bat build windows --release --no-pub
.\run-windows.ps1
```

Có thể thay đường dẫn tuyệt đối bằng `flutter` khi Flutter SDK đã nằm đúng trong PATH. Thư mục cha D:\adrstu có một tệp rỗng tên flutter; dùng flutter.bat hoặc đường dẫn SDK để tránh nhầm lệnh.

## Phạm vi localhost và Android

Daily You là ứng dụng Flutter native, chưa có web target. Mã nguồn sử dụng dart:io, SQLite FFI, hệ thống tệp, isolate và nhiều plugin native. Bản Windows chạy trực tiếp trên máy, không có URL localhost. Việc chạy đầy đủ trong trình duyệt cần một công việc chuyển đổi nền tảng riêng; không có website giả hay bản HTML thay thế ứng dụng gốc trong dự án này.

Máy chưa có Android SDK nên chưa build APK hoặc kiểm thử quyền thông báo, camera và sinh trắc học trên Android. Sau khi cài Android SDK phù hợp với compileSdk của dự án, có thể build bằng:

```powershell
flutter build apk --flavor fdroid --release
```

## Những thay đổi Việt hóa

- Bộ dịch `lib/l10n/intl_vi.arb` bao phủ toàn bộ khóa của tệp tiếng Anh, gồm các biến ICU, số lượng, mẫu nhật ký, thẻ mặc định, thông báo và thông báo lỗi.
- Bản cài mới chọn tiếng Việt mặc định. Có thể đổi tại Cài đặt → Ngôn ngữ. Ngày tháng, lịch, nút hộp thoại và giờ theo locale tiếng Việt; người dùng vẫn có thể đổi ngôn ngữ.
- Việt hóa lựa chọn cấp tiêu đề Markdown và các thông báo dự phòng. Cho phép tìm nhóm biểu tượng bằng tên tiếng Việt.
- Giữ tên riêng của ứng dụng bên thứ ba, định dạng JSON/Markdown, thuật ngữ AMOLED và nội dung giấy phép gốc.
- Không dịch hoặc ghi đè các bài nhật ký do người dùng đã tự viết trước đó. Mẫu và thẻ mặc định được dịch khi tạo mới.
- Phần Giới thiệu và bài chào mừng ghi rõ nguồn gốc bản chỉnh sửa.

## Các lỗi vận hành Windows đã sửa

- Dùng đúng giá trị mặc định cho mục cấu hình nullable khi chưa có khóa (trước đó ngôn ngữ mặc định có thể bị bỏ qua).
- Tuần tự hóa thao tác ghi cấu hình và cung cấp hàm chờ ghi hoàn tất.
- Đóng cơ sở dữ liệu kể cả khi kiểm tra integrity_check thất bại.
- Đóng luồng đọc ZIP kể cả khi dữ liệu có đường dẫn không hợp lệ; chờ isolate kết thúc khi hủy nén để nhả tệp trên Windows.
- Dùng đường dẫn native khi xác định thư mục tệp đính kèm; xử lý nhất quán tên tệp từ thiết bị Android.
- CMake đóng gói ứng dụng trong thư mục build thay vì Program Files khi lần cấu hình trước dừng giữa chừng.

## Kiểm tra bản dịch

```powershell
node tool/check_vi.cjs
flutter test test/widgets/vietnamese_localization_test.dart
```

Kiểm thử kiểm tra độ phủ bản dịch, biến trong câu, lỗi UTF-8, ngôn ngữ mặc định, định dạng ngày giờ, câu đếm và thao tác xác nhận hộp thoại chọn màu ở kích thước 360 × 800.

Toàn bộ 513 kiểm thử đã đạt. Kết quả chi tiết và giới hạn kiểm chứng được ghi trong KIEM_THU.md.
