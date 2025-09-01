CREATE MATERIALIZED VIEW mv_najlepsi_sprzedawcy_02_2024
BUILD IMMEDIATE REFRESH ON DEMAND AS
    WITH sprzedaz_luty AS (
        SELECT
            p.id            AS pracownik_id,
            p.imie,
            p.nazwisko,
            r.nazwa         AS region,
            SUM(s.wartosc)  AS suma_sprzedazy
        FROM sprzedaz s
        JOIN pracownicy p ON p.id = s.prac_id
        JOIN regiony r    ON r.id = p.reg_id
        WHERE s.dt >= DATE '2024-02-01'
          AND s.dt <  DATE '2025-03-01'
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
        FROM sprzedaz_luty s)
    WHERE pozycja = 1
    ORDER BY suma_sprzedazy DESC;


 SELECT * FROM mv_najlepsi_sprzedawcy_02_2024;