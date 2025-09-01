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
WHERE s.dt >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -12)
  AND s.dt < TRUNC(SYSDATE, 'MM')
GROUP BY p.id, p.imie, p.nazwisko, TO_CHAR(s.dt, 'YYYY-MM')
ORDER BY okres_sprzedazy, suma_sprzedazy DESC;