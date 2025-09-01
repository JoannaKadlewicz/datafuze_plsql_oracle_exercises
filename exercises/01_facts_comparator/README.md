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