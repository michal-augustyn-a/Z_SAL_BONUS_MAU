# 📊 SAP ABAP Bonus Monitor

[Wersja polska (PL)](#wersja-polska-pl) | [English Version (EN)](#english-version-en)

---

## Wersja polska (PL)

Trzywarstwowa, obiektowa aplikacja raportowo-transakcyjna (ALV Grid / SALV) przeznaczona do automatycznego wyliczania oraz rozliczania kwartalnych premii handlowców w środowisku SAP ERP.

Projekt demonstruje zastosowanie wzorców projektowych, separacji odpowiedzialności (SoC) oraz integracji własnych rozwiązań z modułami standardowymi SAP SD i HR.

---

### Architektura i separacja odpowiedzialności OOP

Aplikację zaprojektowano zgodnie z zasadami podziału ról w architekturze trójwarstwowej:

* **Warstwa dostępu do danych (`ZCL_SAL_BONUS_DB_MAU`):** Klasa bezstanowa. Zbiera dane o obrotach netto z dokumentów sprzedaży (SD) oraz dane etatowe pracowników (HR).
* **Warstwa logiki biznesowej (`ZCL_SAL_BONUS_SERVICE_MAU`):** Klasa stanowa. Odpowiada za silnik kalkulacyjny – weryfikuje progi sprzedażowe (80% i 100%) oraz przypisuje odpowiednie stawki premiowe (1% i 2.5%) wraz z ikonami statusów wizualnych.
* **Kontroler nawigacji i zdarzeń (`LCL_NAVIGATION_MANAGER`):** Klasa lokalna zarządzająca przepływem sterowania. Obsługuje interakcje użytkownika na ekranach Dynpro:
  * **Ekran 100 (Monitor Główny):** Kontrolka `CL_GUI_ALV_GRID` prezentująca zbiorcze zestawienie.
  * **Ekran 200 (Szczegóły):** Tabela `CL_SALV_TABLE` wyświetlająca pozycje faktur powiązane z wybranym handlowcem.

---

### Kluczowe funkcjonalności

* **Interaktywna edycja planów:** Obsługa zmiany celów handlowych bezpośrednio z poziomu raportu za pomocą okna popup.
* **Masowe przetwarzanie transakcyjne:** Możliwość zbiorczego zapisu wersji roboczej (Szkic/Draft) lub ostatecznego zatwierdzenia finansowego (Zatwierdzony/Approved), które trwale blokuje dane przed dalszą edycją.
* **Integracja ze standardem SAP:** Wykorzystanie standardowych struktur i tabel bazodanowych: `VBRK` (faktury), `VBPA` (partnerzy handlowi) oraz `PA0001` (dane etatowe HR).
* **Anglojęzyczność:** Kod źródłowy, komentarze, struktury słownikowe (DDIC) oraz elementy interfejsu użytkownika zostały przygotowane w j. ang.

---

### Rozwiązania techniczne i wyzwania

#### Mechanizm awaryjnego odczytu

Aby zapewnić stabilność działania aplikacji na środowiskach deweloperskich i testowych (gdzie często brakuje rzeczywistych faktur w module SD), w warstwie DB zaimplementowano mechanizm *fallback*. W przypadku braku rekordów produkcyjnych, system przełącza się na odczyt danych z dedykowanej tabeli emulacyjnej `ZMAU_TEST_INV`.

#### Blokowanie danych i kontrola współbieżności (SAP Locks)

Do ochrony przed jednoczesnym zapisem przez wielu użytkowników wykorzystano logiczne blokady SAP – obiekt blokujący `EZ_SAL_BONUS_MAU` oraz moduły funkcyjne `ENQUEUE` i `DEQUEUE`.

> **Refaktoryzacja i wnioski (Inżynieria w praktyce):**
> Podczas testów zidentyfikowano ograniczenie aktualnego mechanizmu blokad: metoda `lock_data` pobiera klucze blokowania wyłącznie z pierwszego wiersza tabeli danych wejściowych. Oznacza to, że przy masowym wyborze wielu pracowników, pełną ochroną SM12 objęty jest jedynie pierwszy rekord.
>
> **Planowany Backlog:** Przebudowa metody blokującej na pętlę przetwarzającą wszystkie zaznaczone rekordy osobno.

---

### 🛠️ Stos technologiczny

* **Język programowania:** ABAP Objects (użycie konstruktorów wyrażeń i klasowej obsługi wyjątków).
* **Słownik danych (DDIC):** Tabele, struktury, obiekty blokujące, domeny i elementy danych.
* **Interfejs użytkownika:** Dynpro (Screen Painter), ALV Grid, SALV.

---

## English Version (EN)

A three-tier, object-oriented reporting and transactional application (ALV Grid / SALV) designed for the automatic calculation and settlement of quarterly sales bonuses in the SAP ERP environment.

The project demonstrates the application of design patterns, Separation of Concerns (SoC), and the integration of custom solutions with standard SAP SD and HR modules.

---

### OOP Architecture and Separation of Concerns

The application is designed in accordance with the principles of division of roles in a three-tier architecture:

* **Data Access Layer (`ZCL_SAL_BONUS_DB_MAU`):** Stateless class. Collects net turnover data from billing documents (SD) and employee master data (HR).
* **Business Logic Layer (`ZCL_SAL_BONUS_SERVICE_MAU`):** Stateful class. Responsible for the calculation engine—verifies sales milestones (80% and 100%) and assigns appropriate bonus rates (1% and 2.5%) along with visual status icons.
* **Navigation and Event Controller (`LCL_NAVIGATION_MANAGER`):** Local class managing the control flow. Handles user interactions on Dynpro screens:
  * **Screen 100 (Main Monitor):** `CL_GUI_ALV_GRID` control presenting the aggregated overview.
  * **Screen 200 (Details):** `CL_SALV_TABLE` presenting billing document items linked to the selected sales employee.

---

### Key Features

* **Interactive Target Editing:** Supports modifying sales targets directly from the report via a popup window.
* **Bulk Transactional Processing:** Allows bulk-saving draft versions (Szkic/Draft) or final financial approvals (Zatwierdzony/Approved), which permanently locks data from further editing.
* **Integration with SAP Standard:** Utilizes standard database tables and structures: `VBRK` (billing), `VBPA` (partners), and `PA0001` (HR organizational assignment).
* **English Language Standard:** The source code, comments, Data Dictionary (DDIC) structures, and user interface elements are fully prepared in English.

---

### Technical Solutions and Challenges

#### Fallback Data Retrieval Mechanism

To ensure the application's stability in development and testing environments (where real invoices in the SD module are often missing), a *fallback* mechanism was implemented in the DB layer. If production records are absent, the system switches to reading data from a dedicated emulation table `ZMAU_TEST_INV`.

#### Data Locking and Concurrency Control (SAP Locks)

To protect against simultaneous saving by multiple users, logical SAP locks are used—specifically, the lock object `EZ_SAL_BONUS_MAU` and function modules `ENQUEUE` and `DEQUEUE`.

> **Refactoring and Conclusions (Engineering in Practice):**
> During testing, a limitation of the current locking mechanism was identified: the `lock_data` method retrieves lock keys solely from the first row of the input data table. This means that during a bulk selection of multiple employees, only the first record is fully protected in SM12.
>
> **Planned Backlog:** Rebuilding the locking method into a loop that processes all selected records individually.

---

### 🛠️ Tech Stack

* **Programming Language:** ABAP Objects (utilizing constructor expressions and class-based exception handling).
* **Data Dictionary (DDIC):** Tables, structures, lock objects, domains, and data elements.
* **User Interface:** Dynpro (Screen Painter), ALV Grid, SALV.
