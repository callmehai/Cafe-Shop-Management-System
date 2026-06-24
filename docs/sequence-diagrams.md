# CSMS — Sequence Diagrams

> Mỗi diagram biểu thị luồng data của 1 Use Case.  
> Actors: **Mobile App** · **API (NestJS)** · **DB (Postgres)**  
> Thêm actor **Manager** khi cần xác nhận quyền.

---

## UC-01 · Đăng nhập (Login)

```
Mobile App          API                  DB
    |                |                    |
    |-- POST /auth/login (email+pwd) ---> |
    |                |-- SELECT user ---> |
    |                |<-- user row -----  |
    |                | verify bcrypt pwd  |
    |<-- { accessToken, refreshToken } -- |
    |  lưu token vào secure storage       |
```

---

## UC-02 · Xem Menu (danh sách sản phẩm)

```
Mobile App          API                  DB
    |                |                    |
    |-- GET /menu/products?categoryId --> |
    |                |-- SELECT products +|
    |                |   category ------> |
    |                |<-- rows ---------- |
    |<-- [{ id, name, price, image }] --- |
    | render danh sách                    |
```

---

## UC-03 · Quản lý Menu (CRUD sản phẩm — Manager)

```
Mobile App          API                  DB
    |                |                    |
    |-- POST /menu/products (Bearer) ---> |
    |                | guard: role=Manager|
    |                |-- INSERT product ->|
    |                |<-- product row --- |
    |<-- 201 { product } --------------- |

    # PATCH /menu/products/:id  →  UPDATE product
    # DELETE /menu/products/:id →  kiểm tra còn order không, rồi DELETE
```

---

## UC-04 · Quản lý Bàn (Tables — Manager)

```
Mobile App          API                  DB
    |                |                    |
    |-- GET /tables ---------------------->
    |                |-- SELECT tables -->|
    |<-- [{ id, name, status }] --------- |

    |-- POST /tables (name) -----------> |
    |                |-- INSERT table --> |
    |<-- 201 { table } ----------------- |

    # PATCH /tables/:id/status  →  UPDATE status (AVAILABLE/OCCUPIED/RESERVED)
```

---

## UC-05 · Tạo Đơn Hàng (Create Order — Cashier)

```
Mobile App          API                  DB
    |                |                    |
    |-- POST /orders                      |
    |   { tableId, items:[{productId,     |
    |     qty, options}] } ------------>  |
    |                | validate:          |
    |                |  ≥1 item (BR-01)   |
    |                |  product available |
    |                |  (BR-04)           |
    |                |-- SELECT products >|
    |                |<-- prices -------- |
    |                | calc linePrice     |
    |                |-- INSERT order  -->|
    |                |-- INSERT items  -->|
    |                |-- UPDATE table     |
    |                |   status=OCCUPIED >|
    |<-- 201 { orderId, orderNo } ------- |
```

---

## UC-06 · Xem Queue (Barista / Cashier)

```
Mobile App          API                  DB
    |                |                    |
    |-- GET /orders/queue --------------> |
    |                |-- SELECT orders    |
    |                |   WHERE status=    |
    |                |   OPEN ORDER BY    |
    |                |   createdAt -----> |
    |<-- [{ orderId, orderNo, items }] -- |
    | render hàng đợi pha chế             |
```

---

## UC-07 · Cập nhật Đơn Hàng (Update Order — Cashier)

```
Mobile App          API                  DB
    |                |                    |
    |-- PATCH /orders/:id                 |
    |   { items:[...] } ---------------> |
    |                | check status=OPEN  |
    |                | (BR-07)            |
    |                |-- DELETE old items>|
    |                |-- INSERT new items>|
    |                |-- UPDATE order     |
    |                |   (subtotal) -----> |
    |<-- 200 { order } ----------------- |
```

---

## UC-08 · Cập nhật Trạng thái Pha Chế (Barista)

```
Mobile App          API                  DB
    |                |                    |
    |-- PATCH /orders/:id/items/:itemId   |
    |   /prep { status } --------------> |
    |                |-- UPDATE item      |
    |                |   prepStatus -----> |
    |<-- 200 { item } ------------------ |

    # Khi tất cả item done:
    |-- PATCH /orders/:id/prep-done ----> |
    |                |-- check all items  |
    |                |   status=done ----> |
    |                |-- UPDATE order     |
    |                |   prepStatus=DONE >|
    |<-- 200 { order } ----------------- |
```

---

## UC-09 · Thanh Toán (Payment — Cashier)

```
Mobile App          API                  DB          Manager (optional)
    |                |                    |               |
    |-- POST /payments                    |               |
    |   { orderId, method, discount,      |               |
    |     customerId? } ---------------> |               |
    |                | calc amount        |               |
    |                | =subtotal-discount |               |
    |                |                    |               |
    |  [nếu discount > 50% (BR-06)]       |               |
    |<-- 403 "cần Manager duyệt" -------- |               |
    |-- hiện dialog nhập Manager pwd ---> |               |
    |-- POST /auth/verify-credentials --> |               |
    |                |<-- ok / fail ----- |               |
    |                |                    |               |
    |  [approved hoặc discount ≤ 50%]     |               |
    |                |-- $transaction:    |               |
    |                |   INSERT payment ->|               |
    |                |   UPDATE order     |               |
    |                |     status=PAID -->|               |
    |                |   UPDATE table     |               |
    |                |     status=        |               |
    |                |     AVAILABLE ---> |               |
    |                |   trừ Ingredient   |               |
    |                |     (BR-08) -----> |               |
    |                |   cộng loyalty pts>|               |
    |<-- 201 { payment, loyaltyEarned } - |               |
```

---

## UC-10 · Quản lý Khách Hàng (Customers — Manager)

```
Mobile App          API                  DB
    |                |                    |
    |-- GET /customers?search= ---------->|
    |                |-- SELECT customers>|
    |<-- [{ id, name, phone, points }] -- |

    |-- POST /customers (Manager) ------> |
    |                |-- INSERT customer >|
    |<-- 201 { customer } -------------- |

    |-- PATCH /customers/:id (Manager) -> |
    |                |-- UPDATE customer >|
    |<-- 200 { customer } -------------- |
```

---

## UC-11 · Nhập Kho (Stock-In — Manager)

```
Mobile App          API                  DB
    |                |                    |
    |-- POST /inventory/stock-in          |
    |   { ingredientId, qty, note } ----> |
    |                | guard: Manager     |
    |                |-- INSERT           |
    |                |   PurchaseOrder    |
    |                |   (RECEIVED) -----> |
    |                |-- INSERT StockIn ->|
    |                |-- UPDATE ingredient|
    |                |   quantityOnHand  >|
    |<-- 201 { stockIn } --------------- |
```

---

## UC-12 · Cảnh báo Tồn Kho Thấp (Low-Stock Alert)

```
API (background)     DB                  Mobile App
    |                 |                      |
    |  [trigger: sau mỗi lần PAID]           |
    |-- SELECT ingredient                    |
    |   WHERE quantityOnHand                 |
    |   < lowStockThreshold ------->         |
    |<-- [ingredients] ----------           |
    | đính kèm vào response                  |
    | payment hoặc GET /inventory ---------->|
    |                                   hiển thị badge/alert
```

---

## UC-13 · Xem Báo Cáo Doanh Thu (Reports — Manager)

```
Mobile App          API                  DB
    |                |                    |
    |-- GET /reports/sales                |
    |   ?from=&to= --------------------> |
    |                | guard: Manager     |
    |                |-- SELECT orders    |
    |                |   WHERE PAID AND   |
    |                |   date IN range -->|
    |                |<-- rows ---------- |
    |                | group & aggregate  |
    |<-- { totalRevenue, totalOrders,     |
    |      topProducts, byDate[] } ------ |
```

---

## UC-14 · Dashboard Tổng Quan (All roles)

```
Mobile App          API                  DB
    |                |                    |
    |-- GET /reports/dashboard ---------->|
    |                |-- SELECT:          |
    |                |  ordersToday       |
    |                |  revenueToday      |
    |                |  tablesOccupied    |
    |                |  lowStockCount --->|
    |<-- { stats } --------------------- |
    | render 4 card trên Home screen      |
```

---

## UC-15 · Quản lý Người Dùng (Users — Admin)

```
Mobile App          API                  DB
    |                |                    |
    |-- GET /users (Admin) ------------->  |
    |                |-- SELECT users --> |
    |<-- [{ id, name, role, active }] --- |

    |-- POST /users { name, role, pwd } -> |
    |                |-- hash pwd         |
    |                |-- INSERT user ----> |
    |<-- 201 { user } ------------------ |

    |-- PATCH /users/:id { active } ----> |
    |                |-- UPDATE user ----> |
    |<-- 200 { user } ------------------ |
```

---

## UC-16 · Làm mới Token (Refresh Token)

```
Mobile App          API                  DB
    |                |                    |
    |  [401 response detected]            |
    |-- POST /auth/refresh                |
    |   { refreshToken } --------------> |
    |                | verify JWT sig     |
    |                |-- SELECT user ---> |
    |<-- { accessToken (mới) } --------- |
    | retry request gốc với token mới    |
```
