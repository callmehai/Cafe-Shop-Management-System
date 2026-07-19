# Cafe Shop Management System (CSMS)

Monorepo cho CSMS — POS + back-office cho quán cà phê. Dựa trên CSMS-SRS v1.0.

```
csms/
├── backend/   # NestJS + Prisma + PostgreSQL (REST API)
├── mobile/    # Flutter app (Android/iOS)
└── docker-compose.yml   # Postgres cho dev
```

## Chạy backend
```bash
cd backend
cp .env.example .env          # điền DATABASE_URL, JWT_SECRET
npm install
docker compose up -d db       # hoặc dùng Postgres có sẵn
npx prisma migrate dev --name init
npm run start:dev             # http://localhost:3000/api
```

## Cập nhật Database khi pull code mới
Nếu có sự thay đổi về cấu trúc cơ sở dữ liệu (schema.prisma mới), sau khi `git pull`, các thành viên cần chạy lệnh sau tại thư mục `backend` để cập nhật DB local và sinh Typescript client mới:
```bash
cd backend
npx prisma migrate dev
npx prisma generate
```

## Chạy mobile
```bash
cd mobile
flutter pub get
flutter run                   # nhớ trỏ API_BASE_URL về backend (xem lib/core/config/env.dart)
```

## Tài khoản thử nghiệm mặc định (Default Accounts)
Sau khi chạy seed dữ liệu hoặc cập nhật database, bạn có thể dùng các tài khoản mặc định dưới đây để đăng nhập và kiểm thử theo từng vai trò (role):

| Role (Vai trò) | Username | Password | Tên đầy đủ (Full Name) |
| :--- | :--- | :--- | :--- |
| **ADMINISTRATOR** | `admin` | `admin123` | System Admin |
| **MANAGER** | `manager.an` | `123456` | Tran Van An |
| **CASHIER** | `cashier.linh` | `123456` | Linh Nguyen |
| **BARISTA** | `barista.huy` | `123456` | Pham Quang Huy |

## Trạng thái dự án (Release 1.0)
- ✅ **Data model đầy đủ (Prisma)**: 12 entity SRS + `ProductIngredient` (recipe) cho BR-08 + bảng `AuditLog` cho CR-11.
- ✅ **Auth & Security**: Đăng nhập, phân quyền RBAC (JWT, `@Roles()`), khóa tài khoản sau 5 lần sai (BR-10), và rate-limiting chống brute-force.
- ✅ **Audit Log (CR-11)**: Ghi log đăng nhập, đăng xuất, thanh toán, và các thao tác Admin/Manager CRUD.
- ✅ **Quản lý POS & Bàn**: Đặt hàng (Dine-in/Takeaway), cập nhật trạng thái chế biến (PrepStatus), quản lý sơ đồ bàn.
- ✅ **Thanh toán & Loyalty (BR-11)**: Hỗ trợ tiền mặt, thẻ, và ví điện tử (tích hợp VNPay sandbox). Tích/đổi điểm loyalty theo quy ước (1 pt = 100đ, earn 1 pt/10.000đ).
- ✅ **Kho & Inventory (BR-08)**: Tự động trừ kho nguyên liệu theo công thức món ăn khi thanh toán. Goods Receipt (Stock-In) & Low-stock alert.
- ✅ **Khách hàng & Báo cáo**: CRUD khách hàng, báo cáo doanh thu theo khoảng ngày & export báo cáo.
- ✅ **Dọn dẹp & Testing**: Đã dọn toàn bộ trang placeholder thừa, viết đầy đủ unit tests cho backend (Jest - 13 tests) và mobile widget/unit tests (Flutter - 7 tests).

