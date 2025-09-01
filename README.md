# Zadanie 1 – Pakiet `PKG_COMPARE_FACT`

## Opis problemu
Projekt **COMPARATOR** zakłada porównywanie wersji danych z tabeli `FACT_HISTORY`.  
Tabela ta przechowuje historyczne wersje danych z tabeli `FACT`, gdzie:
- Klucz główny `PK_FACT_HISTORY (ID_PACK, ID_FACT)` składa się z:
  - `ID_PACK` – numer paczki (wersji danych),
  - `ID_FACT` – klucz główny z tabeli źródłowej `FACT`.
- Oprócz klucza, tabela zawiera kolumny danych (`VARCHAR2`, `DATE`, `NUMBER`, itp.).

Celem zadania było napisanie procedury `COMPARE_FACT`, która porównuje dane pomiędzy dwiema paczkami (`ID_PACK_OLD`, `ID_PACK_NEW`) i zwraca wynik w tabeli pomocniczej:

`TMP_FACT_HISTORY_COMPARE_STATUS`
- `ID_FACT` – identyfikator rekordu,
- `STATUS`:
  - `1` – **MODIFIED** (rekord istnieje w obu paczkach, ale jego dane się różnią),
  - `2` – **NEW** (rekord pojawił się tylko w nowej paczce),
  - `3` – **DELETED** (rekord był w starej paczce, ale nie ma go w nowej).

Brak wpisu dla `ID_FACT` oznacza brak zmian.

---

## Rozwiązanie

Pakiet `PKG_COMPARE_FACT` zawiera:
- Stałe definiujące statusy porównania (`C_STATUS_MODIFIED`, `C_STATUS_NEW`, `C_STATUS_DELETED`),
- Procedurę `COMPARE_FACT`, która:
  1. Tworzy tabelę tymczasową `TMP_FACT_HISTORY_COMPARE_STATUS`.
  2. Wstawia rekordy:
     - **DELETED** – rekordy obecne w starej paczce, brakujące w nowej.
     - **NEW** – rekordy obecne w nowej paczce, brakujące w starej.
     - **MODIFIED** – rekordy obecne w obu paczkach, ale z innymi wartościami (wyliczanymi za pomocą funkcji `ORA_HASH`).

---

## Kluczowe elementy implementacji

- Obsługa błędu przy `DROP TABLE` – jeśli tabela tymczasowa nie istnieje, procedura nie przerywa działania.
- Użycie operatora `MINUS` do porównania zestawów rekordów między paczkami.
- Zastosowanie funkcji `ORA_HASH` do wyliczania uproszczonego hasha zawartości rekordu (w celu wykrycia modyfikacji).
- Zastosowanie `CTE` w celu ułatwienia porównania rekordów dla statusu `MODIFIED`.

---

## Przykład użycia

```sql
BEGIN
    PKG_COMPARE_FACT.COMPARE_FACT(100, 200);
END;
/

--  PL/SQL procedure successfully completed.

 
SELECT * FROM TMP_FACT_HISTORY_COMPARE_STATUS ORDER BY ID_FACT;

| ID_FACT | STATUS |
| ------- |--------|
| 101     | 3      |
| 102     | 3      |
| 103     | 3      |
| 104     | 2      |
| 105     | 1      |
```


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


# Zadanie 3 - Pakiet `PKG_BOOKING_TICKET`

## Opis problemu
Projekt **REZERWACJA MIEJSC** zakłada implementację systemu rezerwacji biletów na koncert.  
Celem jest napisanie procedury, która:

- umożliwia rezerwację biletu dla użytkownika na podstawie numeru **PESEL**,  
- zwraca status próby rezerwacji (`OUT`),  
- zwraca unikalny identyfikator rezerwacji (`IDR`) w przypadku powodzenia.  

### Ograniczenia biznesowe
- Maksymalna liczba rezerwacji: **50 000**,
- Maksymalna liczba rezerwacji na użytkownika: **5**,
- Procedury mogą być wywoływane równolegle przez wiele sesji (np. 50 równoległych wywołań),
- Każda próba rezerwacji zapisywana jest w tabeli **BOOKING_HISTORY** w celu audytu.  

### Tabele

#### BOOKING
- `IDR` - unikalny identyfikator rezerwacji (np. UUID),
- `PESEL` - identyfikator użytkownika.

#### BOOKING_HISTORY
- `IDR` - identyfikator rezerwacji (może być NULL w przypadku nieudanej rezerwacji),
- `PESEL` - identyfikator użytkownika,
- `STATUS` - status próby rezerwacji:
  - `0` - rezerwacja OK,
  - `1` - limit całkowity przekroczony,
  - `2` - limit użytkownika przekroczony,
  - `3` - anulowana rezerwacja.

---

## Rozwiązanie

Pakiet `PKG_BOOKING_TICKET` zawiera dwie procedury:

1. **`BOOK_TICKET`**
   - Sprawdza limit całkowity (`50 000`) oraz limit rezerwacji na użytkownika (`5`),
   - Jeśli limit zostanie przekroczony, zapisuje status w **BOOKING_HISTORY** i zwraca odpowiedni kod,
   - W przypadku powodzenia:
     - generuje `IDR` (UUID),
     - wstawia wpis do **BOOKING** i **BOOKING_HISTORY**,
     - ustawia `p_status = 0` i zwraca `p_idr`.

2. **`CANCEL_BOOKING`**
   - Usuwa rezerwację z tabeli **BOOKING** na podstawie `IDR` i `PESEL`,
   - Dodaje wpis w **BOOKING_HISTORY** ze statusem `3` (CANCELLED),
   - Umożliwia kontrolę nadużyć (anulowania własnych rezerwacji).

### Ważne elementy implementacji

- **Isolation Level SERIALIZABLE** - zapewnia brak konfliktów przy równoległych rezerwacjach,
- **Stałe statusów** - `C_STATUS_OK`, `C_STATUS_LIMIT_EXCEEDED`, `C_STATUS_USER_OVERBOOKING`, `C_STATUS_CANCELLED`,
- **Zapisywanie historii** - każda próba rezerwacji (udana lub nieudana) jest audytowana w tabeli `BOOKING_HISTORY`,
- **Limit per user** - każda osoba może mieć maksymalnie 5 rezerwacji.

---

## Przykład użycia

```sql
DECLARE
    v_status BOOKING_HISTORY.status%TYPE;
    v_idr    BOOKING_HISTORY.idr%TYPE;
BEGIN
    -- Próba rezerwacji biletu
    PKG_BOOKING_TICKET.BOOK_TICKET('90010112345', v_status, v_idr);

    DBMS_OUTPUT.PUT_LINE('Status: ' || v_status);   -- Status: 0
    DBMS_OUTPUT.PUT_LINE('IDR: ' || v_idr);         -- IDR: 3DBDF410E2BA00CEE063020012AC86A1

    -- Anulowanie rezerwacji
    PKG_BOOKING_TICKET.CANCEL_BOOKING(v_idr, '90010112345', v_status);
    DBMS_OUTPUT.PUT_LINE('Status po anulowaniu: ' || v_status);   -- Status po anulowaniu: 3 CANCELLED
END;
/
```


# Zadanie 4 - Raport sprzedaży

## Opis problemu
Celem jest przygotowanie raportu sprzedaży dla wszystkich pracowników firmy za **ostatnie 12 miesięcy**, z wyłączeniem bieżącego miesiąca.  

Dane pochodzą z tabel:

### Pracownicy
- `id` - klucz główny,
- `imie`, `nazwisko` - dane pracownika,
- `reg_id` - klucz obcy do tabeli `Regiony`.

### Regiony
- `id` - klucz główny,
- `nazwa` - nazwa regionu.

### Sprzedaż
- `id` - klucz główny,
- `dt` - data transakcji (indeksowana),
- `prac_id` - klucz obcy do `Pracownicy`,
- `wartosc` - wartość transakcji.

Raport ma zawierać dla każdego pracownika i każdego miesiąca:
- liczbę transakcji,
- sumę sprzedaży,
- średnią wartość pojedynczej transakcji,
- maksymalną wartość transakcji.

---

## Rozwiązanie

```sql
SELECT
    TO_CHAR(s.dt, 'YYYY-MM') AS okres_sprzedazy,
    p.id AS p_id,
    p.imie,
    p.nazwisko,
    COUNT(s.id) AS ilosc_transakcji,
    SUM(s.wartosc) AS suma_sprzedazy,
    ROUND(AVG(s.wartosc), 2) AS srednia_sprzedazy,
    MAX(s.wartosc) AS max_sprzedaz
FROM Sprzedaz s
JOIN Pracownicy p ON s.prac_id = p.id
WHERE s.dt >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)             -- 12 miesięcy wstecz, od początku miesiąca
  AND s.dt < TRUNC(SYSDATE, 'MM')                               -- wykluczając bieżący miesiąc
GROUP BY p.id, p.imie, p.nazwisko, TO_CHAR(s.dt, 'YYYY-MM')
ORDER BY okres_sprzedazy, suma_sprzedazy DESC;
```

Wyjaśnienie zapytania: 

`TO_CHAR(s.dt, 'YYYY-MM')` - grupowanie według roku i miesiąca,

`ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)` - początek okresu 12 miesięcy wstecz,

`TRUNC(SYSDATE, 'MM')` - koniec okresu (wyłączenie bieżącego miesiąca),

`COUNT`, `SUM`, `AVG`, `MAX` - agregacje dla każdej grupy pracownika i miesiąca.


Przykładowy wynik: 

| okres_sprzedazy | p_id | imie  | nazwisko   | ilosc_transakcji | suma_sprzedazy | srednia_sprzedazy | max_sprzedaz |
| --------------- | ---- | ----- | ---------- | ---------------- | -------------- | ----------------- | ------------ |
| 2024-02         | 1    | Jan   | Kowalski   | 5                | 1200.00        | 240.00            | 500.00       |
| 2024-02         | 2    | Anna  | Nowak      | 3                | 750.00         | 250.00            | 300.00       |
| 2024-03         | 1    | Jan   | Kowalski   | 4                | 1000.00        | 250.00            | 400.00       |
| 2024-03         | 3    | Piotr | Wiśniewski | 2                | 500.00         | 250.00            | 300.00       |


# Zadanie 5 – Najlepsi sprzedawcy

## Opis problemu
Zarząd firmy chce przyznać premię dla najlepszych sprzedawców w każdym regionie.  
Kryterium wyboru:
- Najlepszy sprzedawca w regionie = pracownik, którego **suma sprzedaży w danym miesiącu była najwyższa**.

Celem jest przygotowanie raportu dla kadry, pokazującego pracowników kwalifikujących się do premii za **luty 2024**.

---

## Rozwiązanie

Wykorzystano **materialized view**, aby:

- szybko prezentować historyczne wyniki dla kadry,
- umożliwić odświeżanie danych w dowolnym momencie (REFRESH ON DEMAND).

```sql
CREATE MATERIALIZED VIEW mv_najlepsi_sprzedawcy_02_2024
BUILD IMMEDIATE
REFRESH ON DEMAND
AS
WITH sprzedaz_luty AS (
    SELECT
        p.id AS pracownik_id,
        p.imie,
        p.nazwisko,
        r.nazwa AS region,
        SUM(s.wartosc) AS suma_sprzedazy
    FROM sprzedaz s
    JOIN pracownicy p ON p.id = s.prac_id
    JOIN regiony r ON r.id = p.reg_id
    WHERE s.dt >= DATE '2024-02-01'
      AND s.dt < DATE '2024-03-01'
    GROUP BY p.id, p.imie, p.nazwisko, r.nazwa
)
SELECT
    pracownik_id,
    imie,
    nazwisko,
    region,
    suma_sprzedazy
FROM (
    SELECT
        s.*,
        RANK() OVER (PARTITION BY s.region ORDER BY s.suma_sprzedazy DESC) AS pozycja
    FROM sprzedaz_luty s
)
WHERE pozycja = 1
ORDER BY suma_sprzedazy DESC;
```

Wyjaśnienie zapytania

`WITH sprzedaz_luty AS (...)` – agreguje sprzedaż pracowników za luty 2024,

`RANK() OVER (PARTITION BY region ORDER BY suma_sprzedazy DESC)` – przydziela pozycje w każdym regionie,

`WHERE pozycja = 1` – wybiera tylko najlepszych sprzedawców w regionie,

`REFRESH ON DEMAND` – umożliwia ręczne odświeżenie widoku.


Przykład użycia: 

```sql
SELECT * FROM mv_najlepsi_sprzedawcy_02_2024;
```

| pracownik_id | imie  | nazwisko   | region   | suma_sprzedazy |
| ------------ | ----- | ---------- | -------- | --------------- |
| 1            | Jan   | Kowalski   | Warszawa | 12000.00        |
| 5            | Anna  | Nowak      | Kraków   | 9800.00         |
| 7            | Piotr | Wiśniewski | Wrocław  | 10200.00        |
