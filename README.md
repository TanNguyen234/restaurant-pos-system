# Restaurant and Cafe POS System

A production-grade, multi-platform Point of Sale (POS) and table-service management system engineered for restaurants and cafes. Built as a monorepo comprising a Flutter mobile application with on-device SQLite caching, backed by an ASP.NET Core 10 RESTful API and Microsoft SQL Server.

---

## Architecture Overview

The system adheres to an offline-resilient, layered architecture:

```
[ Mobile Client (Flutter) ]
  +-- Presentation Layer (StatefulWidget / View)
  +-- Local Storage (SQLite via sqflite) --> Local Cart, Sessions, Offline Queue
  +-- Repository Layer (HTTP Client)
            |
            | RESTful JSON over HTTP / HTTPS
            v
[ Backend API (ASP.NET Core 10) ]
  +-- Controllers (BaseController)
  +-- Service and Aggregator Layer (SiteProvider / BaseProvider)
  +-- Data Access Layer (BaseRepository / Entity Repositories)
  +-- File Storage (wwwroot/images for media assets)
            |
            | ADO.NET / EF Core 10
            v
[ Relational Database (Microsoft SQL Server) ]
  +-- 10 Normalized Relational Tables (Roles, Accounts, Areas, DiningTables,
       Categories, Products, ProductAttributes, Orders, OrderDetails, Payments)
```

---

## Technology Stack

| Component | Technology | Version | Purpose |
| :--- | :--- | :--- | :--- |
| **Mobile Client** | Flutter / Dart | 3.47.1 / 3.13.1 | Cross-platform staff ordering and customer terminal |
| **Local Database** | SQLite (sqflite) | 2.4.4 | On-device persistent cart, local session, and offline cache |
| **Backend API** | ASP.NET Core Web API | 10.0 (net10.0) | Centralized business logic, auth, media processing |
| **ORM** | Entity Framework Core | 10.0.12 | Object-relational mapping for SQL Server |
| **Central Database** | Microsoft SQL Server | 2019 / 2022 | Primary ACID-compliant transactional datastore |
| **Online Payments** | VietQR / VNPayment | NAPAS 247 / v2 | Dynamic banking QR codes and payment gateway integration |

---

## Functional Specifications

### 1. Identity and Role-Based Access Control (RBAC)
- **Account Operations:** Registration, authentication, password modification, and profile management.
- **Session Management:** Token generation with secure persistent storage via SQLite and SharedPreferences.
- **Role Separation:** Strict boundary enforcement between Admin (system configuration, catalog, reporting) and Staff / Member (order creation, table service).
- **Extended Identity:** Email activation token tracking, password recovery tokens, and external OAuth provider linkage (Google, Facebook, Zalo).

### 2. Category and Menu Management
- **Hierarchical Catalog:** CRUD operations for food and beverage categories with priority sorting and active state toggles.
- **Media Lifecycle:** Server-side file management (wwwroot/images/categories). Uploading a replacement image automatically deletes obsolete physical files from the host file system.
- **Referential Integrity Protection:** Enforces non-destructive validation; categories containing active products cannot be deleted.

### 3. Product Catalog and Asset Processing
- **Server-Driven Pagination:** High-throughput OFFSET-FETCH pagination on indexed fields (IX_Products_CategoryId, IX_Products_ProductName).
- **Product Lifecycle:** Multi-part form-data image upload, automated file sanitization, and thumbnail handling.
- **Financial Audit Safety:** Rejection of hard deletion for products present in historical orders (OrderDetails), preserving accounting accuracy.

### 4. Home Terminal and Real-Time Discovery
- **Showcase Navigation:** Category horizontal chips, latest menu additions with pagination, and search queries with client-side debouncing.
- **Item Drilldown:** High-resolution asset preview, portion attributes, customizable modifiers (ice, sugar, size, toppings), and category-linked product recommendations.

### 5. Cart Management and Checkout Pipeline
- **Offline-First Persistence:** Cart items are stored directly in SQLite (cart_items), surviving app restarts, memory eviction, and intermittent network loss.
- **Immediate State Synchronization:** Badge indicators compute total item volume via localized queries (SELECT SUM(quantity)).
- **Atomic Checkout:** Multi-item orders execute inside SQL Server transactions, reserving tables, populating order lines, and purging local cart state upon server acknowledgement.
- **Digital Payment Processing:**
  - Dynamic VietQR generation encoding bank BIN, account number, order code, and exact checkout amount into NAPAS-standard QR payloads.
  - VNPayment checkout URL generation using HMAC-SHA512 checksum validation.

### 6. Kitchen Display System (KDS) and Order Dispatch
- **Live Kitchen Board:** Order status progression: Pending -> Cooking -> Ready -> Served -> Completed.
- **Date-Bound Reporting:** Filterable order archives supporting range lookups (DateRangePicker), order code lookups, and revenue summation.
- **Floor and Table Management:** Visual table maps reflecting state colors (Empty: Green, Occupied: Red, Reserved: Blue, Awaiting Service: Orange).

---

## Database Architecture

The system utilizes an enterprise relational schema deployed on Microsoft SQL Server. The full migration script and seed data are located in [RestaurantPosDb.sql](RestaurantPosDb.sql).

### Entity Relationship Structure

```
Roles (1) <--- Accounts (N)
                 |
Areas (1) <-- DiningTables (N)
                 |
                 +---< Orders (1) <--- OrderDetails (N) ---> Products (1) ---> Categories (1)
                         |                  |                   |
                         |                  |                   +---< ProductAttributes (N)
                         |                  +---< OrderDetailModifiers (N)
                         |
                         +---< Payments (N)
```

### Table Definitions

| Table | Primary Key | Description | Seeded Records |
| :--- | :--- | :--- | :---: |
| `Roles` | `RoleId` | System access tiers (Admin, Manager, Cashier, Waiter, Barista, Chef, Member, VIP) | 10 |
| `Accounts` | `AccountId` | User credentials, salt/hash passwords, verification tokens, OAuth providers | 10 |
| `Areas` | `AreaId` | Restaurant layout partitions (Air-conditioned floor, Balcony, VIP rooms, Garden) | 10 |
| `DiningTables` | `TableId` | Seating units, capacity tracking, current occupancy status | 10 |
| `Categories` | `CategoryId` | Menu classifications (Coffee, Espresso, Tea, Bakery, Breakfast, Snacks) | 10 |
| `Products` | `ProductId` | Food and beverage items with pricing in VND (DECIMAL(18,0)), assets, units | 10 |
| `ProductAttributes` | `AttributeId` | Modifiers, size selections, sweetness levels, extra espresso shots, toppings | 10 |
| `Orders` | `OrderId` | Transaction master records containing table bindings, order type, and amounts | 10 |
| `OrderDetails` | `OrderDetailId` | Line items with unit pricing, kitchen cooking status, and custom preparation notes | 10 |
| `Payments` | `PaymentId` | Transaction settlements via Cash, VietQR transfer, or VNPayment gateway | 10 |

---

## Directory Layout

```
restaurant_pos_app/
+-- RestaurantPosDb.sql           # Complete SQL Server DDL & DML script (10 records/table)
+-- backend/                      # ASP.NET Core 10 Web API
|   +-- Api/
|   |   +-- Controllers/          # BaseController, CategoryController, etc.
|   +-- Models/                   # RestaurantPosContext, SiteProvider, Repositories, Entities
|   +-- Services/                 # Helper utilities (image upload, physical file deletion)
|   +-- wwwroot/images/           # Static asset directory for products and categories
|   +-- appsettings.json          # Connection strings and logging configuration
|   +-- Program.cs                # Dependency injection, CORS policy, middleware pipeline
|   +-- WebApi.csproj             # .NET 10 project definition and package references
+-- mobile/                       # Flutter Mobile Application
|   +-- lib/
|   |   +-- models/               # Domain models with fromMap() / toMap() mappers
|   |   +-- repositories/         # REST API clients and HTTP communication
|   |   +-- utils/                # DatabaseHelper (SQLite singleton)
|   |   +-- views/                # Presentation screens (CategoryPage, HomePage, CartPage)
|   |   +-- main.dart             # Application root and theme configuration
|   +-- pubspec.yaml              # Flutter dependencies (http, sqflite, path, intl)
|   +-- test/widget_test.dart     # Automated test suite
+-- docs/                         # Technical documentation and specifications
    +-- 01_YEU_CAU_CUNG_VA_BAREM_DIEM.md
    +-- 02_CHUC_NANG_MO_RONG_DANG_LAM.md
    +-- 03_LUONG_HOAT_DONG_CHI_TIET.md
    +-- 04_THIET_KE_CO_SO_DU_LIEU_MERMAID.md
    +-- 05_MERMAID_SEQUENCE_FLOWS.md
    +-- 06_KE_HOACH_PHAN_CHIA_PHASE_CONG_VIEC.md
    +-- TAI_LIEU_HUONG_DAN_COLLABORATOR_FULL.docx
```

---

## Getting Started

### Prerequisites

Ensure the following runtimes and tools are installed:
- .NET SDK 10.0 (dotnet --version >= 10.0)
- Flutter SDK (flutter --version >= 3.47)
- Microsoft SQL Server (2019 or later)
- SQL Server Management Studio (SSMS)

---

### Step 1: Database Initialization

1. Connect to your SQL Server instance using SSMS or sqlcmd.
2. Open and execute [RestaurantPosDb.sql](RestaurantPosDb.sql).
3. Confirm that database RestaurantPosDb is created with all 10 tables and populated with the default 10 records per table.

```sql
-- Verification query
USE RestaurantPosDb;
SELECT TABLE_NAME, TABLE_ROWS = (SELECT COUNT(*) FROM sys.partitions p WHERE p.object_id = t.object_id AND p.index_id < 2)
FROM sys.tables t;
```

---

### Step 2: Backend API Configuration and Execution

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Verify or update the SQL Server connection string in appsettings.json:
   ```json
   "ConnectionStrings": {
     "RestaurantPosDb": "Server=localhost;Database=RestaurantPosDb;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true;"
   }
   ```
3. Restore packages, compile, and start the service:
   ```bash
   dotnet restore
   dotnet build
   dotnet run --urls "http://localhost:5138"
   ```
4. Verify the service is online by requesting the category endpoint:
   ```bash
   curl http://localhost:5138/api/category
   ```

---

### Step 3: Mobile Client Configuration and Execution

1. Navigate to the mobile directory:
   ```bash
   cd ../mobile
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Execute static code analysis and tests:
   ```bash
   flutter analyze
   flutter test
   ```
4. Launch the application:
   ```bash
   flutter run
   ```

**Android Emulator Network Configuration:**
When running the application inside an Android Virtual Device (AVD), requests directed to `localhost` resolve to the emulator's internal loopback. Use `http://10.0.2.2:5138/api/...` as the base URL to route traffic back to the host machine. On Windows Desktop, macOS, or physical devices connected via local Wi-Fi, target `http://localhost:5138` or your machine's LAN IP address.

---

## API Reference

All requests and responses use standard JSON encoding unless submitting binary multipart form data for image uploads.

| Method | Endpoint | Description | Access Level |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/auth/register` | Register a new user account | Public |
| `POST` | `/api/auth/login` | Authenticate credentials and return session token | Public |
| `POST` | `/api/auth/change-password` | Update account password | Authenticated |
| `GET` | `/api/category` | Retrieve all active menu categories | Public |
| `POST` | `/api/category` | Create a new category with icon asset upload | Admin |
| `PUT` | `/api/category/{id}` | Update category metadata and replace icon asset | Admin |
| `DELETE` | `/api/category/{id}` | Delete category (blocked if child products exist) | Admin |
| `GET` | `/api/product` | Query products with category and pagination parameters | Public |
| `POST` | `/api/product` | Create product with primary image upload | Admin |
| `PUT` | `/api/product/{id}` | Update product details and replace image asset | Admin |
| `DELETE` | `/api/product/{id}` | Delete product (blocked if linked to historical orders) | Admin |
| `POST` | `/api/order` | Submit an order transaction from the client cart | Staff / Member |
| `GET` | `/api/order/admin` | Retrieve order list with date range and status filters | Admin / Cashier |
| `PUT` | `/api/order/{id}/status` | Transition order and kitchen preparation states | Staff / Chef |
| `POST` | `/api/payment/confirm` | Record transaction settlement (Cash, VietQR, VNPay) | Cashier |

---

## Quality Assurance and Verification

Before submitting pull requests or packaging build artifacts, run the automated verification suite:

```bash
# Backend verification
cd backend
dotnet build --configuration Release

# Mobile verification
cd ../mobile
flutter analyze
flutter test
```
