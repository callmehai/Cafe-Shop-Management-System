---
name: verify
description: Kiểm chứng thay đổi trong CSMS — chạy typecheck, test backend/mobile và tự kiểm luồng nghiệp vụ bị ảnh hưởng. Dùng trước khi commit thay đổi có tác động runtime.
---

# Verify — CSMS

Mục tiêu: xác nhận thay đổi **thật sự chạy đúng**, không chỉ "compile được".

## 1. Cổng bắt buộc

Chạy phần tương ứng với code đã sửa; nếu đổi shape response API thì chạy **cả hai**.

```bash
# backend/
npx tsc --noEmit && npx jest

# mobile/
flutter analyze && flutter test
```

`flutter analyze` hiện có sẵn ~14 info/warning cũ (deprecation `value:`/`activeColor`,
`unused_element_parameter` ở `stock_in_page.dart`). Đó là nợ có sẵn — chỉ quan tâm **error**
và các cảnh báo mới xuất hiện ở file bạn vừa sửa.

## 2. Sau khi đổi `schema.prisma`

```bash
npx prisma generate   # bắt buộc, nếu không Prisma Client vẫn dùng type cũ
npx prisma migrate dev --name <mô-tả-ngắn>
```

## 3. Kiểm luồng nghiệp vụ

Unit test ở đây dùng **mock Prisma**, nên không bắt được lỗi query sai hay migration thiếu.
Với thay đổi chạm tới nghiệp vụ, chạy thật:

```bash
cd backend && npm run start:dev      # http://localhost:3000/api
```

Đăng nhập lấy token rồi gọi endpoint liên quan:

```bash
curl -s -X POST http://localhost:3000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"manager.an","password":"123456"}'
```

Tài khoản seed: `admin/admin123`, `manager.an/123456`, `cashier.linh/123456`, `barista.huy/123456`.

### Checklist theo vùng thay đổi

| Sửa ở | Cần kiểm |
|---|---|
| Order/BR-08 | Tạo order vượt tồn kho → phải bị chặn **ngay lúc tạo** (400), không phải lúc thanh toán. Tạo 2 order OPEN cùng ăn 1 nguyên liệu → order thứ 2 bị chặn. |
| Payment | Cash thiếu tiền → 400; giảm giá > 50% không có `approvalManagerId` → 409; sau khi trả tiền, tồn kho giảm đúng & điểm loyalty cộng/trừ đúng. |
| Menu/recipe | `PATCH /products/:id` **không** kèm `recipe` → công thức cũ còn nguyên. Kèm `recipe: []` → xóa sạch công thức. |
| RBAC | Gọi endpoint bằng role không có quyền → 403. |
| Mobile | `flutter run`, đi hết luồng vừa sửa. Kiểm cả trạng thái loading/empty/error, không chỉ happy path. |

## 4. Báo cáo

Nói rõ đã chạy gì và kết quả thật. Nếu chỉ chạy được test mà chưa dựng được DB/app,
**nói thẳng là chưa verify end-to-end** thay vì ngầm định là đã xong.
