# System Architecture & Technical Design

This document provides a detailed breakdown of the technical architecture, database design, and key execution flows for the **SAP ABAP Bonus Monitor** application.

---

## 1. Architectural Pattern (3-Tier OOP)

The application adheres to the **Separation of Concerns (SoC)** principle, isolating user interaction, business calculations, and database operations into three distinct, decoupled layers.

```
+-------------------------------------------------------------------+
|                        PRESENTATION LAYER                         |
|  - Dynpro 100 (ALV Grid via CL_GUI_ALV_GRID)                      |
|  - Dynpro 200 (SALV Table via CL_SALV_TABLE)                      |
|  - Modal Dialog Popups                                            |
+-------------------------------------------------------------------+
                                 |
         Events & User Actions   |   Data & Refresh Triggers
                                 v
+-------------------------------------------------------------------+
|                    CONTROLLER / NAVIGATION LAYER                  |
|  - LCL_NAVIGATION_MANAGER                                         |
|    (Coordinates UI state, button actions, and view switches)      |
+-------------------------------------------------------------------+
                                 |
             Method Delegation   |   Instantiated & Passed Data
                                 v
+-------------------------------------------------------------------+
|                        BUSINESS LOGIC LAYER                       |
|  - ZCL_SAL_BONUS_SERVICE_MAU                                      |
|    (Stateful service, calculates percentages/bonuses, holds state) |
+-------------------------------------------------------------------+
                                 |
              Dependency Inj.    |   Clean Open SQL / Data Tables
              (Constructor)      v
+-------------------------------------------------------------------+
|                         DATA ACCESS LAYER                         |
|  - ZCL_SAL_BONUS_DB_MAU                                           |
|    (Stateless DB class, reads SAP SD/HR tables, manages fallback) |
+-------------------------------------------------------------------+

```

### Layer Breakdown

#### A. Data Access Layer (`ZCL_SAL_BONUS_DB_MAU`)

* **Role:** Performs all database read/write operations. It is designed to be **stateless** and can be easily mocked during unit testing.
* **Key Responsibilities:**
* Querying billing document headers (`VBRK`) and partner functions (`VBPA`).
* Retrieving employee HR organizational assignments (`PA0001`).
* Managing fallback logic when standard SD billing tables are empty.



#### B. Business Logic Layer (`ZCL_SAL_BONUS_SERVICE_MAU`)

* **Role:** Acts as the brain of the application. It is a **stateful** service class that holds the current session data.
* **Dependency Injection:** The constructor receives an instance of the DB class (`ZCL_SAL_BONUS_DB_MAU`), making the business logic decoupled from the actual physical data source.
* **Key Logic:**
* **Achieved % Calculation:** `calculate_sal_pct = (Actual Turnover / Target Plan) * 100`
* **Bonus Thresholds:**
* Under 80% Achievement $\rightarrow$ 0% Bonus rate, Red Status Icon (`icon_red_light`).
* 80% to 100% Achievement $\rightarrow$ 1% Bonus rate (`mc_bonus_rate_mid`), Yellow Status Icon.
* Over 100% Achievement $\rightarrow$ 2.5% Bonus rate (`mc_bonus_rate_normal`), Green Status Icon (`icon_green_light`).





#### C. Navigation & Event Controller (`LCL_NAVIGATION_MANAGER`)

* **Role:** Captures system triggers (user clicks) and controls screen-to-screen transitions.
* **Screens managed:**
* **Dynpro 100 (Main Monitor):** Displays aggregated sales target achievements using an editable `CL_GUI_ALV_GRID`.
* **Dynpro 200 (Transaction Details):** Provides a drill-down view of underlying invoices for the selected employee via `CL_SALV_TABLE`.



---

## 2. Database & DDIC Model

The application integrates standard SAP tables with custom, client-specific custom tables (`Z-tables`) to establish a clear data flow.

```
       +-----------------------+              +-----------------------+
       |   ZMAU_SAL_TARGETS    |              |    ZMAU_SAL_BONUS     |
       |  (Sales Target Plans) |              | (Calculated Results)  |
       +-----------------------+              +-----------------------+
       | MANDT   (KEY)         |              | MANDT   (KEY)         |
       | PERNR   (KEY, FK) ----+--+        +--| PERNR   (KEY, FK)     |
       | GJAHR   (KEY)         |  |        |  | GJAHR   (KEY)         |
       | QUARTER (KEY)         |  |        |  | QUARTER (KEY)         |
       | TARGET_VAL            |  |        |  | ACTUAL_VAL            |
       | WAERK                 |  |        |  | BONUS_VAL             |
       +-----------------------+  |        |  | STATUS  (S/A)         |
                                  |        |  | WAERK                 |
                                  |        |  +-----------------------+
                                  v        v
                        +--------------------+
                        |   Standard SAP HR  |
                        |      PA0001        |
                        | (Org. Assignment)  |
                        +--------------------+
                                  ^
                                  | (Sales Employee / PERNR match)
                                  |
                        +--------------------+
                        |   Standard SAP SD  |
                        |    VBRK / VBPA     |
                        | (Billing / Invoices)|
                        +--------------------+

```

### Table Definitions

1. **`ZMAU_SAL_TARGETS` (Transparent Table):** Holds the quarterly target goals for sales employees (`PERNR`).
2. **`ZMAU_SAL_BONUS` (Transparent Table):** Stores calculated final sales achievements, calculated bonus values, and the release status (e.g., `S` - Draft, `A` - Approved).
3. **`ZMAU_TEST_INV` (Transparent Table):** Used as a test/mock database containing simplified invoice data for non-production environments where standard billing data is unavailable.

---

## 3. Core Technical Flows

### 3.1. Data Retrieval and Fallback Flow

To support seamless development and functional testing on sandboxes or clean development systems, the database layer implements a transparent fallback mechanism:

```
[Service Layer requests Turnover Data]
                  |
                  v
       [Query Standard VBRK/VBPA]
                  |
                  +---> Data Found? ---> YES ---> [Aggregate & Return Results]
                  |
                  +---> NO (Fallback)
                        |
                        v
         [Query Custom Table ZMAU_TEST_INV]
                        |
                        v
             [Aggregate & Return Results]

```

### 3.2. Target Modification Sequence (`EDIT_TRGT`)

When a manager selects a row on Dynpro 100 and clicks **Edit Target**:

1. **Validation:** `LCL_NAVIGATION_MANAGER->handle_edit_target()` verifies that exactly one row is selected and that its status is not yet "Approved".
2. **User Input:** The controller triggers a popup dialog to request the new numerical value.
3. **Buffer Update:** The new target is updated in the class memory buffer.
4. **Recalculation:** `ZCL_SAL_BONUS_SERVICE_MAU` automatically recalculates percentages, bonus amounts, and status icons.
5. **View Refresh:** The ALV Grid is refreshed in-place, indicating unsaved changes.

### 3.3. Concurrency Control & Locking Strategy

To prevent overwrites in multi-user environments during status updates (saving draft/approving), the application executes a strict database locking sequence:

```
[Start Save/Approve]
         |
         v
[Call DB class method: lock_data()]
         |
         v
[Call ENQUEUE_EZ_SAL_BONUS_MAU]
         |
         +---> Lock Successful? ---> YES ---> [Execute COMMIT WORK] ---> [Call unlock_data() / DEQUEUE] ---> [Exit Success]
         |
         +---> NO (Locked by another user)
                  |
                  v
       [Raise cx_abap_lock_failure] ---> [Execute ROLLBACK WORK] ---> [Display Safe UI Warning Message] ---> [Exit Safe]

```

> ⚠️ **Technical Limitation & Iteration Note:**
> Currently, the `lock_data` method registers a logical lock against the **first** row of the incoming data table using the specific employee key. In multi-row mass selection scenarios, this protects only the primary record from concurrent modification. Future refactoring is planned to wrap the enqueue operation in a loop to systematically register lock entries for all selected records.