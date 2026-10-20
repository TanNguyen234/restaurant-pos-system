# Project: Restaurant & Cafe POS System (Member 1: Team Leader & Fullstack Architect)

## Architecture
- **Backend (.NET 10 Web API)**:
  - Pattern: 4-Tier Provider / Facade Pattern (`BaseController` -> `SiteProvider` -> `BaseRepository` -> `RestaurantPosContext`)
  - ORM: Entity Framework Core 10 (`Microsoft.EntityFrameworkCore.SqlServer` 10.0.12)
  - Database: SQL Server 2022 (10 normalized relational tables in 3NF)
  - Key Modules: Area & Table Management, Order/Payment domain models, JSON Serialization cycle mitigation
- **Mobile Client (Flutter 3.47 / Dart 3.13)**:
  - Pattern: Layered Architecture (Views -> Repositories/Services -> SQLite DatabaseHelper / HTTP Client)
  - Local Storage: SQLite (`sqflite` + `path`) with 3 core tables: `user_session`, `cart_items`, `offline_orders`
  - Offline-First: `OfflineSyncService` background queue for un-synced orders
  - UI/UX: F&B Table Floor Plan with TabBar per Area, visual status color codes (Green: Trống, Red: Có khách, Orange: Đặt trước/Chờ), Table Card, and Quick Transfer Dialog
- **Documentation & Version Control**:
  - Senior Software Engineer-grade `README.md`
  - Conventional Commits: 3 atomic commits (`feat(backend)`, `feat(mobile)`, `docs`) pushed to GitHub `origin/main`

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | 10-Table EF Core Models & Context | Synchronize `RestaurantPosContext.cs` to cover all 10 tables from `RestaurantPosDb.sql` (`Areas`, `DiningTables`, `Categories`, `Products`, `Orders`, `OrderDetails`, `Accounts`, `Roles`, `Payments`, `ProductAttributes`) | M1 | ORIGINAL_REQUEST §R1 |
| 2 | TableRepository Implementation | Implement `TableRepository.cs` inheriting `BaseRepository` with `GetAreas`, `GetTablesByArea`, `GetAllTables`, `GetById`, `UpdateStatus`, and `TransferTable` (atomic transaction) | M1 | ORIGINAL_REQUEST §R1 |
| 3 | SiteProvider Integration | Register lazy `TableRepository Table` property in `SiteProvider.cs` | M1 | ORIGINAL_REQUEST §R1 |
| 4 | TableController Web API | Implement `TableController.cs` inheriting `BaseController` with 5 REST endpoints (`GET /api/table/areas`, `GET /api/table/by-area/{areaId}`, `GET /api/table`, `PUT /api/table/{id}/status`, `POST /api/table/transfer`) | M1 | ORIGINAL_REQUEST §R1 |
| 5 | Backend Build Verification | Verify `dotnet build` succeeds with 0 errors and 0 warnings | M1 | ORIGINAL_REQUEST §AC |
| 6 | SQLite DatabaseHelper Expansion | Implement full CRUD in `lib/utils/database_helper.dart` for `user_session`, `cart_items` total calculation, and `offline_orders` queue | M2 | ORIGINAL_REQUEST §R2 |
| 7 | Floor Table Page UI | Implement `lib/views/table/floor_table_page.dart` with Area TabBar, color-coded GridView, table card metadata, status update & transfer dialog | M2 | ORIGINAL_REQUEST §R2 |
| 8 | Mobile Models & Repository | Create `Area`, `DiningTable` models and `TableRepository` in mobile client | M2 | ORIGINAL_REQUEST §R2 |
| 9 | Offline Sync Service | Implement `lib/services/offline_sync_service.dart` with connectivity check, unsynced queue polling, backend API sync, and `is_synced` update | M2 | ORIGINAL_REQUEST §R2 |
| 10 | Main Shell & Route Navigation | Standardize `lib/main.dart` with F&B theme and smooth navigation across Tables, Categories, and Cart | M2 | ORIGINAL_REQUEST §R2 |
| 11 | Mobile Static Analysis | Verify `flutter analyze` passes with 0 syntax errors or unresolved imports | M2 | ORIGINAL_REQUEST §AC |
| 12 | Comprehensive README.md | Write senior software engineer-grade README covering architecture, tech stack, data models, API catalog, setup guide, and 3-member matrix with Member 1 completion evidence | M3 | ORIGINAL_REQUEST §R3 |
| 13 | Atomic Commits & Git Push | Commit 3 atomic units (`feat(backend)`, `feat(mobile)`, `docs`) and push clean working tree to `origin/main` | M3 | ORIGINAL_REQUEST §R3 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Backend Architecture & Table Management | Features #1, #2, #3, #4, #5 (.NET 10 Web API) | none | DONE |
| M2 | Mobile Architecture, SQLite & Floor Table UI | Features #6, #7, #8, #9, #10, #11 (Flutter Mobile) | M1 (API Contract) | DONE |
| M3 | Senior Documentation, Atomic Commits & Push | Features #12, #13 (README, Git Release) | M1, M2 | IN_PROGRESS |

## Interface Contracts
### Backend ↔ Mobile / External Clients
1. `GET /api/table/areas`:
   - Response: `200 OK` `[ { "areaId": 1, "areaName": "Tầng trệt - Máy lạnh trong nhà", "description": "...", "sortOrder": 1, "isActive": true } ]`
2. `GET /api/table/by-area/{areaId}`:
   - Param: `areaId` (int)
   - Response: `200 OK` `[ { "tableId": 1, "areaId": 1, "tableName": "Bàn T1-01", "capacity": 4, "status": 1, "currentOrderId": 1, "updatedAt": "..." } ]`
3. `GET /api/table`:
   - Response: `200 OK` `[ { "tableId": 1, "areaId": 1, "tableName": "Bàn T1-01", "capacity": 4, "status": 1, "currentOrderId": 1, "updatedAt": "..." } ]`
4. `PUT /api/table/{id}/status`:
   - Route Param: `id` (int)
   - Body: `{ "status": 1 }` (supports 0: Trống, 1: Có khách, 2: Chờ phục vụ / Đã đặt trước)
   - Response: `200 OK` `{ "tableId": 1, "status": 1, "message": "Cập nhật trạng thái thành công" }`
5. `POST /api/table/transfer`:
   - Body: `{ "fromTableId": 1, "toTableId": 2 }` (or `{ "sourceTableId": 1, "targetTableId": 2 }`)
   - Precondition: `fromTable` exists, `toTable` exists and has `status == 0` (empty)
   - Response: `200 OK` `{ "success": true, "message": "Chuyển bàn thành công", "fromTableId": 1, "toTableId": 2 }`

## Code Layout
- Backend files exclusively owned by Member 1:
  - `backend/Models/RestaurantPosContext.cs`
  - `backend/Models/TableRepository.cs`
  - `backend/Models/SiteProvider.cs`
  - `backend/Api/Controllers/TableController.cs`
  - *(Do NOT modify CategoryRepository.cs or CategoryController.cs)*
- Mobile files exclusively owned by Member 1:
  - `mobile/lib/utils/database_helper.dart`
  - `mobile/lib/models/area.dart`
  - `mobile/lib/models/dining_table.dart`
  - `mobile/lib/repositories/table_repository.dart`
  - `mobile/lib/views/table/floor_table_page.dart`
  - `mobile/lib/services/offline_sync_service.dart`
  - `mobile/lib/main.dart`
- Documentation & Git release files:
  - `README.md`
  - `.gitignore`
