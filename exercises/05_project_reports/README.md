# Zadanie 5 - Najlepsi sprzedawcy

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

`WITH sprzedaz_luty AS (...)` - agreguje sprzedaż pracowników za luty 2024,

`RANK() OVER (PARTITION BY region ORDER BY suma_sprzedazy DESC)` - przydziela pozycje w każdym regionie,

`WHERE pozycja = 1` - wybiera tylko najlepszych sprzedawców w regionie,

`REFRESH ON DEMAND` - umożliwia ręczne odświeżenie widoku `(EXEC DBMS_MVIEW.REFRESH('mv_najlepsi_sprzedawcy_02_2024'))`.


Przykład użycia: 

```sql
SELECT * FROM mv_najlepsi_sprzedawcy_02_2024;
```

| pracownik_id | imie  | nazwisko   | region   | suma_sprzedazy |
| ------------ | ----- | ---------- | -------- | --------------- |
| 1            | Jan   | Kowalski   | Warszawa | 12000.00        |
| 5            | Anna  | Nowak      | Kraków   | 9800.00         |
| 7            | Piotr | Wiśniewski | Wrocław  | 10200.00        |
