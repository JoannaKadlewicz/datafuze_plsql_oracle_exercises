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
