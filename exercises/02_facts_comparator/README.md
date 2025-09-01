# Zadanie 2 – Rozszerzony pakiet `PKG_COMPARE_FACT`

## Opis problemu
Druga wersja pakietu rozszerza funkcjonalność z **Zadania 1**.  
Celem jest nie tylko wskazanie rekordów, które zostały:
- **MODIFIED** (`1`),
- **NEW** (`2`),
- **DELETED** (`3`),

ale również - w przypadku gdy parametr `P_BUILD_DIFF = TRUE` - zapisanie **dokładnych różnic kolumn** w dodatkowej tabeli tymczasowej:

### TMP_FACT_HISTORY_COMPARE_DIFF
- `ID_FACT` – identyfikator rekordu,
- `COL_NAME` – nazwa kolumny, w której wystąpiła różnica,
- `COL_TYPE` – typ danych kolumny,
- `COL_OLD_VALUE` – wartość w starej paczce,
- `COL_NEW_VALUE` – wartość w nowej paczce.

---

## Rozwiązanie

Pakiet `PKG_COMPARE_FACT`:
- Usuwa i tworzy od nowa dwie tabele tymczasowe:
  - `TMP_FACT_HISTORY_COMPARE_STATUS`
  - `TMP_FACT_HISTORY_COMPARE_DIFF`
- Wstawia do **STATUS**:
  - rekordy **DELETED** – brakujące w nowej paczce,
  - rekordy **NEW** – pojawiające się w nowej paczce,
  - rekordy **MODIFIED** – obecne w obu paczkach, ale różniące się zawartością.
- Jeśli `P_BUILD_DIFF = TRUE`, to wstawia do **DIFF** informacje o różnicach w poszczególnych kolumnach.

---

## Kluczowe elementy implementacji

- Funkcja `ORA_HASH` – służy do szybkiego wykrycia, czy wiersz uległ zmianie.
- Pętla kursora – dla każdego zmodyfikowanego rekordu sprawdza kolumny osobno.
- Obsługa wielu typów danych (`VARCHAR`, `DECIMAL`, `DATE`) w stałym formacie VARCHAR2 (dla porównań i raportowania).
- Możliwość uruchomienia procedury w dwóch trybach:
  - **tylko statusy** (`P_BUILD_DIFF = FALSE`),
  - **statusy + szczegóły różnic** (`P_BUILD_DIFF = TRUE`).

---

## Przykład użycia

```sql
BEGIN
    PKG_COMPARE_FACT.COMPARE_FACT(100, 200, TRUE);
END;
/

-- PL/SQL procedure successfully completed.


-- Podgląd statusów
SELECT * FROM TMP_FACT_HISTORY_COMPARE_STATUS ORDER BY ID_FACT;

| ID_FACT | STATUS |
| ------- |--------|
| 101     | 3      |
| 102     | 3      |
| 103     | 3      |
| 104     | 2      |
| 105     | 1      |

-- Podgląd różnic
SELECT * FROM TMP_FACT_HISTORY_COMPARE_DIFF ORDER BY ID_FACT, COL_NAME;

| ID_FACT | COL_NAME   | COL_TYPE       | COL_OLD_VALUE | COL_NEW_VALUE |
|---------|------------|----------------|---------------|---------------|
| 105     | FACT_NAME  | VARCHAR(100)   | val1          | val2          |
| 105     | FACT_VALUE | DECIMAL(10,2)  | 200           | 199           |
```