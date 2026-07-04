# CSMS — Package Diagram (Development View)

> 📐 Editable UML diagram: [`csms-package.drawio`](csms-package.drawio) — 2 pages: **1. Mobile — Development View**, **2. Backend — Development View**.

---

## 0. Where the package diagram sits — the 4+1 view model

CSMS is documented with Kruchten's **4+1 multi-view architecture**. Each view answers a different question and is captured by a different artifact:

| View | Question it answers | Audience | CSMS artifact |
|------|---------------------|----------|---------------|
| **Logical view** | What are the domain concepts / classes and how do they relate? | Analysts, developers | Class Diagrams — [`class-diagrams.md`](class-diagrams.md) |
| **Process view** | What runs at runtime, and how do the parts communicate over time? | Integrators | Sequence Diagrams — [`sequence-diagrams.md`](sequence-diagrams.md) |
| **Development view** | How is the **source code** organized into packages / files for the team to build? | Programmers | **This document** + [`csms-package.drawio`](csms-package.drawio) |
| **Physical / Deployment view** | Which runtime nodes / environments does each part run on? | Ops / deployment | System Architecture — [`system-design.md`](system-design.md) §1.1 |
| **+1 Scenarios** | Key use cases that tie the other views together | Everyone | SRS §2.2.2 use cases |

**➡️ A Package Diagram is the Development View** — it shows the static structure of the source code (packages → files → classes), not runtime behavior.

---

## 1. Architecture model (named)

| Sub-system | Architecture pattern | Layers (top depends on the one below) |
|------------|----------------------|----------------------------------------|
| **Backend API** | **Layered architecture**, organized as a modular monolith (one package per feature module) | `controller` (REST API) → `service` (business logic) → `data-access` (Prisma ORM) |
| **Mobile App** | **Feature-first Layered architecture** (a Clean-Architecture-style split per feature) | `presentation` (UI + Riverpod state) → `data` (repository) → `domain` (models) |

---

## 2. Mobile — Development View

> See `csms-package.drawio` → page **1. Mobile — Development View**.

Source root `csms_mobile/lib` is split into `core/` (shared infrastructure) and `features/` (one package per feature). **Every feature repeats the same three layers** — shown here for the `order` feature, with the real source files and the classes each file declares (a single `.dart` file can hold several classes):

| Layer (package) | Source files (examples) | Classes inside the file |
|-----------------|-------------------------|-------------------------|
| `presentation` | `order_queue_page.dart` · `create_order_page.dart` · `order_details_page.dart` … | `OrderQueuePage`, `TicketCard`, `PrepChip`, `CreateOrderPage`, `AddItemSheet` |
| `data` | `orders_repository.dart` | `OrdersRepository` (+ Riverpod providers) |
| `domain` | `order_models.dart` | `Order`, `OrderItem`, `PrepStatus` («enum») — *one file, several classes* |
| `core` (shared) | `network/api_client.dart` · `router/app_router.dart` · `utils/format.dart` | `ApiClient`, `AppRouter`, `formatVnd()`, `parseAmount()` |

**Dependencies:** `presentation → data → domain` (a layer depends only on the layer below); `data → core/network` (repositories use `ApiClient`).

---

## 3. Backend — Development View

> See `csms-package.drawio` → page **2. Backend — Development View**.

Source root `backend/src` groups code into one package per feature module. **Every module repeats the same layered structure** — shown here for the `orders` module, plus the shared packages:

| Package | Source files | Classes inside the file |
|---------|--------------|-------------------------|
| `orders` (module) | `orders.controller.ts` | `OrdersController` (REST endpoints, `@Roles`) |
| `orders` (module) | `orders.service.ts` | `OrdersService` (business rules, `$transaction`) |
| `orders/dto` | `create-order.dto.ts` · `create-order-item.dto.ts` · `update-order.dto.ts` · `update-prep.dto.ts` | `CreateOrderDto`, `CreateOrderItemDto`, `UpdateOrderDto`, `UpdatePrepDto` |
| `prisma` (shared) | `prisma.service.ts` | `PrismaService` (data-access / ORM) |
| `auth` (guards, shared) | `jwt-auth.guard.ts` · `roles.guard.ts` | `JwtAuthGuard`, `RolesGuard` |
| `common` (shared) | `decorators/*.ts` | `@Public`, `@Roles`, `@CurrentUser` |

**Dependencies:** `controller → service → prisma`; `controller → dto`; `controller → guards → common`.

> Other feature modules — `auth`, `users`, `menu`, `payments`, `inventory`, `tables`, `customers`, `reports` — all follow the same `controller → service → dto` layering on top of the shared `prisma` package.

---

## 4. Package Descriptions

> Each description states the package's **classification** (kind of package / layer), **definition** (purpose), **responsibilities** (what it does and contains), and **dependencies**.

### 4.1 Backend sub-system

| No | Package | Description |
|----|---------|-------------|
| 01 | `controllers` (`*.controller.ts`) | **API layer.** Defines the REST endpoints of each feature module; applies guards/roles, delegates to services, returns responses. Depends on: services, dto, guards. |
| 02 | `services` (`*.service.ts`) | **Business-logic layer.** Implements application logic and enforces all business rules (BR-01…BR-12) inside atomic Prisma transactions. Depends on: dto, prisma, common. |
| 03 | `dto` | **Data Transfer Objects.** Define and validate request/response shapes via `class-validator`. Leaf package. |
| 04 | `auth / guards` | **Security cross-cutting concern.** `JwtAuthGuard` + `RolesGuard`, registered globally via `APP_GUARD`. Depends on: common. |
| 05 | `prisma` | **Data-access layer.** `PrismaService`, schema and migrations; the single gateway to PostgreSQL. Leaf package. |
| 06 | `common` | **Shared utilities.** Reusable decorators (`@Public`, `@Roles`, `@CurrentUser`) and helpers. Leaf package. |

### 4.2 Mobile sub-system

| No | Package | Description |
|----|---------|-------------|
| 01 | `presentation` | **UI layer.** Pages & widgets (`ConsumerWidget`) plus their Riverpod state; renders screens and captures user interaction. Depends on: data, domain. |
| 02 | `data` | **Repository layer.** Per-feature `Repository` classes that call `ApiClient` and map JSON ↔ domain models. Depends on: domain, core·network. |
| 03 | `domain` | **Model layer.** Immutable data classes representing the feature's entities. Leaf package. |
| 04 | `core` | **Shared infrastructure.** `ApiClient` (Dio + JWT interceptor), `AppRouter` (go_router), and helpers (`formatVnd`, `parseAmount`). Leaf package. |
