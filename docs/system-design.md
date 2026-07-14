# II. Software Design Document — CSMS

## 1. System Design

### 1.1 System Architecture

CSMS uses a **3-tier client–server architecture** drawn in **box-and-line** style: rectangles are software components / runtime environments, dashed rectangles are the runtime host environments they run in, stick figures are the human actors that trigger the system, and every line is labelled with the **connection method** (protocol). The system has **2 software components** built by the team (Mobile App, Backend API) and **1 external system** (PostgreSQL DBMS).

> 📐 Editable diagram (draw.io): [`csms-architecture.drawio`](csms-architecture.drawio).

#### Overall architecture diagram

```mermaid
flowchart LR
    subgraph Staff["Café Staff (Actors)"]
        direction TB
        C(["Cashier"])
        B(["Barista"])
        M(["Manager"])
        A(["Administrator"])
    end

    subgraph ClientEnv["🖥️ Runtime env: Web Browser (Chrome), staff device"]
        MobileApp["<b>CSMS Mobile App</b>\nFramework: Flutter 3 + Riverpod (Dart)\nCompiled to Web; same codebase\nalso targets Android / iOS / macOS.\nRole: presentation client (UI, calls API,\nkeeps JWT session)."]
    end

    subgraph ServerEnv["⚙️ Runtime env: Node.js runtime (app server)"]
        BackendApi["<b>CSMS Backend API</b>\nFramework: NestJS 10 + Prisma 5 (TypeScript)\nRuns on Node.js.\nRole: REST API — JWT + RBAC auth,\nbusiness rules (BR-01…BR-12),\ndata access via Prisma."]
    end

    subgraph DataEnv["🐳 Runtime env: Docker container"]
        DB[("<b>PostgreSQL 16</b>\nRelational DBMS.\nRole: persistent store for all\nbusiness data.")]
    end

    Staff -->|"operate via UI (touch / click)"| MobileApp
    MobileApp -->|"HTTPS · REST/JSON · Bearer JWT"| BackendApi
    BackendApi -->|"TCP 5432 · SQL (via Prisma ORM)"| DB
```

#### Explanation of the components

Each component is described by **what it is**, **its role**, and **the platform/environment it runs on** — as required.

| Component | Type | Runtime environment | Framework / Platform | Role (what it is & does) |
|-----------|------|---------------------|----------------------|--------------------------|
| **CSMS Mobile App** | Sub-system (client) | Web Browser (Chrome) on the staff device — the same codebase can also be built for Android, iOS and macOS | **Flutter 3 + Riverpod** (Dart) | Presentation client for café staff. Renders role-based UI (Cashier/Barista/Manager/Admin), captures user actions, calls the REST API, and keeps the JWT login session. Holds no core business logic. |
| **CSMS Backend API** | Sub-system (server) | **Node.js** runtime (application server) | **NestJS 10 + Prisma 5** (TypeScript) | REST API server. Handles authentication & authorization (JWT + role-based access control), enforces all business rules (BR-01…BR-12), and performs data access through the Prisma ORM within transactions. |
| **PostgreSQL 16** | External system (data store) | **Docker** container | PostgreSQL relational DBMS | Persistent storage for all business data (users, products, orders, payments, inventory, customers, loyalty). Accessed only by the Backend API. |

**Actors (who triggers the system):**

| Actor | Description |
|-------|-------------|
| **Cashier** | Creates orders, handles checkout, processes payments. |
| **Barista** | Views the preparation queue, updates item preparation status. |
| **Manager** | Manages menu, inventory, tables, customers; views reports; approves discounts. |
| **Administrator** | Manages user accounts, roles/permissions, and system configuration. |

**Connections between components (method / protocol):**

| Connection | Method / Protocol | Description |
|------------|-------------------|-------------|
| Actors → Mobile App | UI interaction (touch / click) | Staff log in and operate directly on the app in the browser. |
| Mobile App → Backend API | **HTTPS · REST / JSON · Bearer JWT** | Every business request carries an access token; the backend authenticates & authorizes before processing. |
| Backend API → PostgreSQL | **TCP (port 5432) · SQL via Prisma ORM** | Reads/writes data within transactions (`$transaction`) to keep operations atomic (e.g. payment + stock deduction + loyalty update). |

> 💳 **Scope note:** there is **no external payment gateway and no extra hardware device** in this version — Card/E-Wallet payments are mocked inside the Backend (pressing Confirm = PAID).

---

### 1.2 Package Diagram

See [`package-diagram.md`](package-diagram.md) and the diagram [`csms-package.drawio`](csms-package.drawio) — presented as the **Development View** of the 4+1 architecture model, split into Mobile and Backend, showing the layered architecture down to the source-file level.

---

## 2. 4+1 Architectural Views

### 2.1 Logical View (High-Level Domain Class Diagram)

Sơ đồ lớp mô tả cấu trúc dữ liệu miền (domain model) và mối quan hệ giữa các thực thể cốt lõi trong hệ thống:

```mermaid
classDiagram
    class User {
        +int id
        +string username
        +string fullName
        +Role role
    }
    class Customer {
        +int id
        +string fullName
        +int loyaltyPoints
    }
    class Order {
        +int id
        +OrderStatus status
        +int tableId
    }
    class OrderItem {
        +int id
        +int quantity
        +decimal linePrice
    }
    class Product {
        +int id
        +string name
        +decimal price
    }
    class Payment {
        +int id
        +PaymentMethod method
        +decimal amount
    }
    class Ingredient {
        +int id
        +string name
        +decimal quantityOnHand
    }

    User "1" --> "*" Order : creates
    User "1" --> "*" Payment : processes
    Customer "1" *-- "*" Order : places
    Order "1" *-- "*" OrderItem : contains
    Product "1" --> "*" OrderItem : ordered_as
    Order "1" --> "0..1" Payment : paid_by
    Payment "1" --> "0..1" Customer : earns_points
    Product "*" o-- "*" Ingredient : recipe
```

### 2.2 Process View (High-Level Request-Response Flow)

Sơ đồ mô tả quy trình tương tác và giao tiếp giữa các tầng nghiệp vụ từ Client đến Database khi xử lý một request:

```mermaid
sequenceDiagram
    autonumber
    actor Staff as Café Staff
    participant Client as CSMS Mobile
    participant Guard as Jwt/Roles Guard
    participant Ctrl as Controller
    participant Svc as Service
    participant Prisma as Prisma ORM
    participant DB as PostgreSQL

    Staff->>+Client: tương tác UI (ví dụ: Checkout)
    Client->>+Guard: HTTP POST /payments (Bearer JWT)
    alt Token hợp lệ & Đúng quyền (RBAC)
        Guard->>+Ctrl: chuyển tiếp Request
        Ctrl->>+Svc: process(dto, cashierId)
        Svc->>+Prisma: $transaction(write actions)
        Prisma->>+DB: Thực thi các câu lệnh SQL
        DB-->>-Prisma: Kết quả truy vấn SQL
        Prisma-->>-Svc: committed transaction
        Svc-->>-Ctrl: DTO kết quả thanh toán
        Ctrl-->>-Client: 201 Created (JSON data)
        Client-->>Staff: hiển thị thông báo thành công
    else Sai Token hoặc Sai quyền
        Guard-->>-Client: 401 Unauthorized / 403 Forbidden
        Client-->>-Staff: hiển thị thông báo lỗi
    end
```

### 2.3 Deployment View (System Hardware/Runtime Nodes)

Sơ đồ mô tả cách phân bổ các thành phần phần mềm trên các nút phần cứng vật lý và các môi trường chạy ở runtime:

```mermaid
flowchart TD
    subgraph ClientDevice["📱 Client Node: Staff Tablet / Desktop"]
        Browser["🌐 Web Browser (Chrome)\nRuntime: HTML5/JS VM"]
        subgraph App["CSMS Mobile App (Flutter Web Assembly)"]
            UI["UI Components"]
            Store["Riverpod State"]
        end
        Browser --- App
    end

    subgraph ServerNode["⚙️ Application Server Node: On-Premise VM / VPS"]
        NodeJS["🟢 Node.js 20 Runtime Environment"]
        subgraph API["CSMS Backend API (NestJS)"]
            Router["REST Router & Guards"]
            Biz["Business Services"]
            ORM["Prisma Client"]
        end
        NodeJS --- API
    end

    subgraph DatabaseNode["🐳 DB Server Node: Docker Host container"]
        subgraph DockerHost["Docker Engine Container (csms-db)"]
            PostgreSQL[(PostgreSQL 16 Relational DBMS)]
        end
    end

    subgraph Hardware["🖨️ Peripheral Device Node"]
        Printer[[Receipt Kitchen Printer]]
    end

    ClientDevice -->|"HTTPS / REST JSON (Port 4000/3000)"| ServerNode
    ServerNode -->|"TCP/IP / SQL (Port 5432)"| DatabaseNode
    ClientDevice -->|"Bluetooth / Local IP"| Hardware
```

