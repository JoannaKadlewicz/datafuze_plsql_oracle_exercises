
-- Test procedury BOOK_TICKET - C_STATUS_OK

DECLARE
    v_status BOOKING_HISTORY.status%TYPE;
    v_idr    BOOKING_HISTORY.idr%TYPE;
BEGIN
    -- próbujemy zarezerwować bilet dla danego PESEL
    PKG_BOOKING_TICKET.BOOK_TICKET(
        p_pesel => '12345678901',
        p_status => v_status,
        p_idr => v_idr
    );

    DBMS_OUTPUT.PUT_LINE('Status: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('ID rezerwacji: ' || v_idr);
END;
/

-- Test procedury CANCEL_BOOKING - C_STATUS_CANCELLED

DECLARE
    v_status BOOKING_HISTORY.status%TYPE;
BEGIN
    PKG_BOOKING_TICKET.CANCEL_BOOKING(
        p_idr => 'ID_Z_POPRZEDNIEGO_TESTU',
        p_pesel => '12345678901',
        p_status => v_status
    );

    DBMS_OUTPUT.PUT_LINE('Status po anulowaniu: ' || v_status);
END;
/

    -- Test limitów - C_STATUS_USER_OVERBOOKING

    DECLARE
        v_status BOOKING_HISTORY.status%TYPE;
        v_idr    BOOKING_HISTORY.idr%TYPE;
    BEGIN
        FOR i IN 1..6 LOOP
            PKG_BOOKING_TICKET.BOOK_TICKET(
                p_pesel => '11122233344',
                p_status => v_status,
                p_idr => v_idr
            );
            DBMS_OUTPUT.PUT_LINE('Próba ' || i || ': Status = ' || v_status);
        END LOOP;
    END;
    /

-- Test limitów - C_STATUS_LIMIT_EXCEEDED

DECLARE
    v_status BOOKING_HISTORY.status%TYPE;
    v_idr    BOOKING_HISTORY.idr%TYPE;
BEGIN
    FOR i IN 1..50000 LOOP
        BEGIN
            INSERT INTO BOOKING (idr, pesel) VALUES (SYS_GUID(), '99999999999');
        END;
    END LOOP;
    COMMIT;

    -- Krok 2: próbujemy dodać kolejną rezerwację, która powinna przekroczyć limit
    PKG_BOOKING_TICKET.BOOK_TICKET(
        p_pesel => '12345678901',
        p_status => v_status,
        p_idr => v_idr
    );

    DBMS_OUTPUT.PUT_LINE('Status po przekroczeniu limitu: ' || v_status);

END;
/
