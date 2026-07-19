# CSMS — Hướng dẫn cho Claude Code

Monorepo POS + back-office cho quán cà phê. Backend NestJS + Prisma + PostgreSQL, mobile Flutter.
Tài liệu nghiệp vụ gốc: `CSMS_PROJECT_CONTEXT.md` (trích từ CSMS-SRS v1.0) — là source of truth cho
business rules. Khi code mâu thuẫn với SRS, hỏi lại trước khi sửa theo bên nào.

## Lệnh hay dùng

```bash
# Backend (cwd: backend/)
npm run start:dev              # http://localhost:3000/api
npx jest                       # unit tests
npx tsc --noEmit               # typecheck
npx prisma migrate dev         # sau khi đổi schema.prisma
npx prisma generate            # sinh lại Prisma Client (bắt buộc sau khi pull migration mới)

# Mobile (cwd: mobile/)
flutter analyze
flutter test
flutter run
```

Chạy **cả hai** bộ test khi đụng vào code chung (ví dụ đổi shape response API).

## Kiến trúc

**Backend** — mỗi domain là 1 NestJS module trong `backend/src/<domain>/`, gồm
`*.controller.ts` (routing + `@Roles`) → `*.service.ts` (business logic) → `PrismaService`.
DTO trong `dto/`, validate bằng `class-validator`. Global prefix `/api`,
`ValidationPipe({ whitelist: true, forbidNonWhitelisted: true })` — field lạ trong body sẽ **bị reject**,
nên khi thêm field mới phải khai báo trong DTO.

**Mobile** — feature-first, mỗi feature trong `mobile/lib/features/<name>/`:
- `domain/` — model + `fromJson`
- `data/` — repository gọi API + Riverpod provider
- `presentation/` — page/widget

State bằng Riverpod. Sau khi mutate, `ref.invalidate(<provider>)` để refetch.
Lỗi API hiển thị qua `apiErrorMessage(e)` (`core/network/api_client.dart`).

## Quy ước

- **Comment tiếng Việt**, gắn mã rule khi liên quan: `// BR-08: trừ kho theo công thức`.
  Mã BR-xx/CR-xx/UC-xx tra trong `CSMS_PROJECT_CONTEXT.md`.
- Tiền: `Decimal(12,2)` trong Prisma, `double` + `parseAmount()` ở Flutter, format bằng `formatVnd()`.
- Giá tiền **luôn tính lại từ DB**, không tin giá client gửi lên (xem `OrdersService.buildItems`).
- Business rule mới → thêm test trong `*.spec.ts` tương ứng.

## Điểm cần lưu ý

- **Tồn kho chỉ bị trừ thật lúc thanh toán.** Order OPEN không giữ stock ở DB, nên guard BR-08 khi
  tạo/sửa order phải tự trừ hao phần đã được các order OPEN khác "giữ chỗ"
  (`OrdersService.ensureStockAvailable`). Bỏ qua bước này thì 2 order cùng qua được lúc tạo rồi
  mới fail ở màn thanh toán.
- **`recipe` khi `PATCH /products/:id`**: bỏ trống = giữ nguyên công thức cũ; gửi mảng (kể cả rỗng)
  = thay thế toàn bộ. Đừng đổi ngữ nghĩa này — client cũ chưa biết field sẽ xóa mất công thức.
- `ProductIngredient` có khóa chính là cặp `[productId, ingredientId]` → 1 ingredient chỉ xuất hiện
  1 lần trong công thức của mỗi món.
- Xóa product/category đã được dùng → trả `409`, không xóa cứng (giữ lịch sử order).

## Tài liệu

| File | Nội dung |
|---|---|
| `CSMS_PROJECT_CONTEXT.md` | SRS rút gọn: actors, use case, business rule |
| `docs/API.md` | Toàn bộ REST endpoint + payload |
| `docs/ARCHITECTURE.md` | Tổng quan kiến trúc & luồng dữ liệu |
| `CHANGELOG.md` | Lịch sử thay đổi |
| `docs/system-design.md`, `docs/class-diagrams.md`, `docs/sequence-diagrams.md` | Thiết kế chi tiết |
