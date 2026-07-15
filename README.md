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

## Trạng thái scaffold
- ✅ Data model đầy đủ (Prisma) — 12 entity SRS + `ProductIngredient` (recipe/BOM) để chạy auto-deduction BR-08.
- ✅ Auth + RBAC (JWT, guard theo role) — module mẫu hoàn chỉnh.
- ✅ Users module — CRUD đầy đủ kèm check trùng username (CR-04) làm tham chiếu.
- 🟡 Các module còn lại (orders, payments, inventory, customers, tables, reports): skeleton + TODO trỏ business rule, cần implement.
- ✅ Mobile: cấu trúc feature-first + core (theme/router/api client) + feature auth mẫu; các feature khác là placeholder page.
