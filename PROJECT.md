# Project: Restaurant POS Real-World Acceptance & Remediation

## Architecture
- **Backend (.NET 10 Web API)**:
  - Framework: ASP.NET Core Web API (.NET 10.0, C# 14)
  - Pattern: 4-Tier Provider / Facade Pattern (`BaseController` -> `SiteProvider` -> `BaseRepository` -> `RestaurantPosContext`)
  - ORM: EF Core 10 (`Microsoft.EntityFrameworkCore.SqlServer` 10.0.12)
  - Database: Microsoft SQL Server 2022 Express instance (`localhost`), Dedicated test database: `RestaurantPos_Acceptance`
  - Modules: Auth & RBAC (JWT Bearer across 6 roles: ADMIN, MANAGER, CASHIER, WAITER, KITCHEN, MEMBER), Table/Area Management, Category/Product Catalog & Media (`wwwroot/images`), Order Management & Idempotent Deduplication, KDS Workflow, Payment Gateways (VietQR, VNPay Sandbox).
- **Mobile Client (Flutter 3.47 / Dart 3.13)**:
  - Framework: Flutter 3.47 (Material 3)
  - Pattern: Layered Architecture (Views -> Repositories/Services -> SQLite DatabaseHelper / HTTP Client)
  - Local Storage: SQLite (`sqflite` + `path`) with 3 core tables: `user_session`, `cart_items`, `offline_orders`
  - Network: Real HTTP communication with backend (align port: 5138/5254; emulator host: `10.0.2.2`). Clean network error handling with NO fake in-memory fallback.
  - Offline-First: `OfflineSyncService` background queue for un-synced orders with server-side idempotency.
  - UI/UX: Table Floor Plan, Catalog & Product Detail, SQLite Cart, Checkout, Order Receipt, KDS Kitchen Display, VietQR dialog, VNPay callback.

## Feature Inventory (48 Granular Features)
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Master Traceability Matrix | Map 48 features, academic rubrics, and 3-member responsibilities into `docs/acceptance/REQUIREMENTS_TRACEABILITY.md` | R1 | ORIGINAL_REQUEST §R1 |
| 2 | DOCX Extraction | Extract all text & tables from `docs/TAI_LIEU_HUONG_DAN_COLLABORATOR_FULL.docx` | R1 | ORIGINAL_REQUEST §R1 |
| 3 | Git Branching & Worktree | Create working branch `test/restaurant-real-acceptance` | R2 | ORIGINAL_REQUEST §R2 |
| 4 | Clean Backend Build | `dotnet build backend/WebApi.csproj` compiles with 0 errors | R2 | ORIGINAL_REQUEST §R2 |
| 5 | Clean Mobile Analysis & Test | `flutter analyze` 0 errors, `flutter test` passing | R2 | ORIGINAL_REQUEST §R2 |
| 6 | Android Cleartext & Permissions | Configure `usesCleartextTraffic` and `INTERNET` permission in AndroidManifest | R2 | ORIGINAL_REQUEST §R2 |
| 7 | False-Pass Elimination | Remove in-memory fallback masking from `TableRepository.dart` | R2 | ORIGINAL_REQUEST §R2 |
| 8 | Network Port Alignment | Harmonize backend launch port (5138/5254) and mobile API base URL | R2 | ORIGINAL_REQUEST §R2 |
| 9 | Dedicated SQL Server Provisioning | Provision `RestaurantPos_Acceptance` with 10 tables & seed data | R3 | ORIGINAL_REQUEST §R3 |
| 10 | Auth User Registration | `POST /api/auth/register` (SHA-256 + salt password hashing) | R3 | Docs 01 §1.1 |
| 11 | Auth User Login & Session | `POST /api/auth/login` returning JWT token & role | R3 | Docs 01 §1.2 |
| 12 | Auth Password Change | `POST /api/auth/change-password` | R3 | Docs 01 §1.3 |
| 13 | Member Management API | `GET /api/account/members` | R3 | Docs 01 §1.4 |
| 14 | RBAC 6-Role Authorization | Enforce ADMIN, MANAGER, CASHIER, WAITER, KITCHEN, MEMBER on endpoints | R3 | Docs 01 §1.5 |
| 15 | Logout & Session Wipe | Invalidate session in SQLite `user_session` | R3 | Docs 01 §1.6 |
| 16 | Category Display API | `GET /api/category` | R4 | Docs 01 §2.1 |
| 17 | Category Create & Image Upload | `POST /api/category` multipart form upload to `wwwroot/images/categories` | R4 | Docs 01 §2.2 |
| 18 | Category Delete | `DELETE /api/category/{id}` | R4 | Docs 01 §2.3 |
| 19 | Prevent Cascade Category Delete | Reject deletion if category contains products | R4 | Docs 01 §2.4 |
| 20 | Category Update & Image Overwrite | `PUT /api/category/{id}` with file cleanup of old image | R4 | Docs 01 §2.5 |
| 21 | Category Image Lifecycle Management | Ensure no orphaned physical image files on delete/update | R4 | Docs 01 §2.6 |
| 22 | Paginated Product List API | `GET /api/product?page=x&pageSize=y` | R4 | Docs 01 §3.1 |
| 23 | Product Create & Image Upload | `POST /api/product` multipart form upload | R4 | Docs 01 §3.2 |
| 24 | Product Delete & Image Cleanup | `DELETE /api/product/{id}` unlinking image from `wwwroot/images/products` | R4 | Docs 01 §3.3 |
| 25 | Product Update & Image Overwrite | `PUT /api/product/{id}` overwriting image and removing old image | R4 | Docs 01 §3.4 |
| 26 | Prevent Deletion of Historical Products | Reject deletion if product has historical orders in `OrderDetails` | R4 | Docs 01 §3.5 |
| 27 | Mobile Catalog & Search UI | Product grid, category filter tabs, search bar | R4 | Docs 01 §4.1-4.4 |
| 28 | Mobile Product Detail UI | Large image, price, description, Add to Cart action | R4 | Docs 01 §4.5 |
| 29 | SQLite Cart Persistence | Add to cart, quantity accumulation, badge counter, persist on reboot | R4 | Docs 01 §5.1-5.6 |
| 30 | Area & Table Floor Map API | `GET /api/table/areas`, `GET /api/table` | R5 | Docs 01 §7.1 |
| 31 | Table Floor Plan Mobile UI | Visual status colors, capacity, area tabs, quick actions | R5 | Docs 01 §7.1 |
| 32 | Table Transfer API & Dialog | `POST /api/table/transfer` atomic transaction, occupied target rejection | R5 | Docs 01 §7.2 |
| 33 | Order Checkout API | `POST /api/order` creating order & details in SQL Server | R5 | Docs 01 §5.7 |
| 34 | Order Receipt & Detail UI | View order items, status, subtotal, tax | R5 | Docs 01 §5.8 |
| 35 | Table Occupied Status Update | Update table status to Occupied (1) upon order creation | R5 | ORIGINAL_REQUEST §R5 |
| 36 | KDS Active Orders API | `GET /api/kds/active-orders` | R5 | Docs 01 §7.3 |
| 37 | KDS Cooking Status Transition API | `PUT /api/kds/order/{id}/status` (Pending -> Cooking -> Ready) | R5 | Docs 01 §7.3 |
| 38 | KDS Kitchen Display Screen UI | Visual dish cards with elapsed timer and status action buttons | R5 | Docs 01 §7.3 |
| 39 | Cashier Settlement & Table Release | `POST /api/order/{id}/settle` releasing table to Empty (0) | R5 | ORIGINAL_REQUEST §R5 |
| 40 | Offline Order Queuing | Save order to SQLite `offline_orders` (`is_synced = 0`) when offline | R6 | ORIGINAL_REQUEST §R6 |
| 41 | Offline Sync Recovery Experiment | Restore connectivity, sync queue to backend, verify 1 SQL Server order | R6 | ORIGINAL_REQUEST §R6 |
| 42 | Server Idempotency & Deduplication | Enforce idempotency key to prevent duplicate orders on timeout/retry | R6 | ORIGINAL_REQUEST §R6 |
| 43 | VietQR Reference & Generation | Dynamic VietQR NAPAS 247 QR image URL generation | R7 | Docs 01 §5.10 |
| 44 | Cashier VietQR Verification Flow | Cashier confirms payment reference and marks order paid | R7 | ORIGINAL_REQUEST §R7 |
| 45 | VNPay Sandbox Gateway Redirect | Generate signed VNPay payment URL with valid query parameters | R7 | Docs 01 §5.10 |
| 46 | VNPay Callback HMAC Verification | Verify HMAC-SHA512 checksum on return callback and update order status | R7 | ORIGINAL_REQUEST §R7 |
| 47 | UI/UX Audit & Defect Remediation | Polish UI/UX, eliminate broken placeholders, fix P0/P1/P2 defects | R8 | ORIGINAL_REQUEST §R8 |
| 48 | Acceptance Sign-off Deliverables | Generate 7 acceptance reports and open PR to main | R8 | ORIGINAL_REQUEST §R8 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| R1 | Document-Driven Audit & Traceability Matrix | Features #1, #2 | none | DONE |
| R2 | Clean Build & Static Verification | Features #3, #4, #5, #6, #7, #8 | none | PLANNED |
| R3 | Dedicated SQL Server Setup & API RBAC Integration | Features #9, #10, #11, #12, #13, #14, #15 | none | DONE / PASS |
| R4 | Catalog, Media Management & SQLite Cart Verification | Features #16 through #29 | R3 | PLANNED |
| R5 | Complete Restaurant Business Flow & KDS Lifecycle | Features #30 through #39 | R4 | PLANNED |
| R6 | Real Offline & Recovery Synchronization Experiments | Features #40, #41, #42 | R5 | PLANNED |
| R7 | Payment Gateway Testing (VietQR & VNPay Sandbox) | Features #43, #44, #45, #46 | R5 | PLANNED |
| R8 | UI/UX Polishing, Root-Cause Remediation & Acceptance Sign-off | Features #47, #48 | R6, R7 | PLANNED |

## Interface Contracts
### Auth API (`/api/auth`)
- `POST /api/auth/register`: `{ username, password, fullName, email, phone, roleId }` -> `200 OK { accountId, username, message }`
- `POST /api/auth/login`: `{ username, password }` -> `200 OK { token, accountId, username, role, fullName }`
- `POST /api/auth/change-password`: `{ oldPassword, newPassword }` -> `200 OK { message }`

### Catalog API (`/api/category`, `/api/product`)
- `GET /api/category`: `200 OK List<Category>`
- `POST /api/category`: Multipart form (`Name`, `Title`, `file`) -> `200 OK Category`
- `DELETE /api/category/{id}`: `200 OK` (Rejects if has products)
- `GET /api/product?page=1&pageSize=10&categoryId=...`: `200 OK { totalItems, page, pageSize, data: [...] }`
- `POST /api/product`: Multipart form (`CategoryId`, `Name`, `Price`, `Description`, `file`) -> `200 OK Product`

### Order & KDS API (`/api/order`, `/api/kds`)
- `POST /api/order`: `{ idempotencyKey, tableId, orderType, note, items: [ { productId, quantity, price, note } ] }` -> `200 OK { orderId, orderCode, totalAmount }`
- `GET /api/kds/active-orders`: `200 OK List<KdsOrderDto>`
- `PUT /api/kds/order/{id}/status`: `{ cookingStatus }` (1: Pending, 2: Cooking, 3: Ready) -> `200 OK`
- `POST /api/order/{id}/settle`: `{ paymentMethod, amountPaid }` -> `200 OK { success: true, tableReleased: true }`

### Payment API (`/api/payment`)
- `GET /api/payment/vietqr/{orderId}`: `200 OK { qrUrl, accountNo, accountName, amount, refCode }`
- `POST /api/payment/vnpay/create-url`: `{ orderId, returnUrl }` -> `200 OK { paymentUrl }`
- `GET /api/payment/vnpay/callback`: Verifies HMAC checksum and updates order status.

## Code Layout
- Acceptance Documentation: `docs/acceptance/`
  - `REQUIREMENTS_TRACEABILITY.md`
  - `MEMBER_1_ACCEPTANCE.md`
  - `MEMBER_2_ACCEPTANCE.md`
  - `MEMBER_3_ACCEPTANCE.md`
  - `E2E_EXECUTION_REPORT.md`
  - `SECURITY_AND_DATA_INTEGRITY.md`
  - `UNRESOLVED_BLOCKERS.md`
- Backend (`backend/`):
  - Controllers: `backend/Api/Controllers/` (`AuthController.cs`, `CategoryController.cs`, `TableController.cs`, `ProductController.cs`, `OrderController.cs`, `PaymentController.cs`, `KdsController.cs`)
  - Repositories & Models: `backend/Models/`
  - Uploads: `backend/wwwroot/images/`
- Mobile (`mobile/`):
  - Views: `mobile/lib/views/` (`table/`, `catalog/`, `cart/`, `order/`, `kds/`, `auth/`)
  - Database: `mobile/lib/utils/database_helper.dart`
  - Services: `mobile/lib/services/offline_sync_service.dart`, `api_service.dart`
