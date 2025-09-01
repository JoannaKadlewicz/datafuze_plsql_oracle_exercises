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