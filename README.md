# 📊 SAP ABAP Bonus Monitor

Trzywarstwowa, obiektowa aplikacja raportowo-transakcyjna (ALV Grid / SALV) przeznaczona do automatycznego wyliczania oraz rozliczania kwartalnych premii handlowców w środowisku SAP ERP.

Projekt demonstruje zastosowanie wzorców projektowych, separacji odpowiedzialności (SoC) oraz integracji własnych rozwiązań z modułami standardowymi SAP SD i HR.

---

## Architektura i separacja odpowiedzialności OOP

Aplikację zaprojektowano zgodnie z zasadami podziału ról w architekturze trójwarstwowej:

* **Warstwa dostępu do danych (`ZCL_SAL_BONUS_DB_MAU`):** Klasa bezstanowa. Zbiera dane o obrotach netto z dokumentów sprzedaży (SD) oraz dane etatowe pracowników (HR).
* **Warstwa logiki biznesowej (`ZCL_SAL_BONUS_SERVICE_MAU`):** Klasa stanowa. Odpowiada za silnik kalkulacyjny – weryfikuje progi sprzedażowe ($80\%$ i $100\%$) oraz przypisuje odpowiednie stawki premiowe ($1\%$ i $2.5\%$) wraz z ikonami statusów wizualnych.
* **Kontroler nawigacji i zdarzeń (`LCL_NAVIGATION_MANAGER`):** Klasa lokalna zarządzająca przepływem sterowania. Obsługuje interakcje użytkownika na ekranach Dynpro:
* **Ekran 100 (Monitor Główny):** Kontrolka `CL_GUI_ALV_GRID` prezentująca zbiorcze zestawienie.
* **Ekran 200 (Szczegóły):** Tabela `CL_SALV_TABLE` wyświetlająca pozycje faktur powiązane z wybranym handlowcem.



---

## Kluczowe funkcjonalności

* **Interaktywna edycja planów:** Obsługa zmiany celów handlowych bezpośrednio z poziomu raportu za pomocą okna popup.
* **Masowe przetwarzanie transakcyjne:** Możliwość zbiorczego zapisu wersji roboczej (Szkic/Draft) lub ostatecznego zatwierdzenia finansowego (Zatwierdzony/Approved), które trwale blokuje dane przed dalszą edycją.
* **Integracja ze standardem SAP:** Wykorzystanie standardowych struktur i tabel bazodanowych: `VBRK` (faktury), `VBPA` (partnerzy handlowi) oraz `PA0001` (dane etatowe HR).
* **Anglojęzyczność:** Kod źródłowy, komentarze, struktury słownikowe (DDIC) oraz elementy interfejsu użytkownika zostały przygotowane w j. ang.

---

## Rozwiązania techniczne i wyzwania

### Mechanizm awaryjnego odczytu

Aby zapewnić stabilność działania aplikacji na środowiskach deweloperskich i testowych (gdzie często brakuje rzeczywistych faktur w module SD), w warstwie DB zaimplementowano mechanizm *fallback*. W przypadku braku rekordów produkcyjnych, system przełącza się na odczyt danych z dedykowanej tabeli emulacyjnej `ZMAU_TEST_INV`.

### Blokowanie danych i kontrola współbieżności (SAP Locks)

Do ochrony przed jednoczesnym zapisem przez wielu użytkowników wykorzystano logiczne blokady SAP – obiekt blokujący `EZ_SAL_BONUS_MAU` oraz moduły funkcyjne `ENQUEUE` i `DEQUEUE`.

> **Refaktoryzacja i wnioski (Inżynieria w praktyce):**
> Podczas testów obciążeniowych zidentyfikowano ograniczenie aktualnego mechanizmu blokad: metoda `lock_data` pobiera klucze blokowania wyłącznie z pierwszego wiersza tabeli danych wejściowych. Oznacza to, że przy masowym wyborze wielu pracowników, pełną ochroną SM12 objęty jest jedynie pierwszy rekord.
> **Planowany Backlog:** Przebudowa metody blokującej na pętlę przetwarzającą wszystkie zaznaczone rekordy osobno.

---

## 🛠️ Stos technologiczny

* **Język programowania:** ABAP Objects (użycie konstruktorów wyrażeń, nowoczesnej składni tabel wewnętrznych oraz klasowej obsługi wyjątków).
* **Słownik danych (DDIC):** Tabele przezroczyste, struktury płaskie, obiekty blokujące, domeny i elementy danych.
* **Interfejs użytkownika:** Dynpro (Screen Painter), ALV Grid (technologia Control Framework), SALV.
