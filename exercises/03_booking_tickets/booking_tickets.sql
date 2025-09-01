CREATE OR REPLACE PACKAGE PKG_BOOKING_TICKET IS
    C_STATUS_OK                   CONSTANT NUMBER := 0;
    C_STATUS_LIMIT_EXCEEDED       CONSTANT NUMBER := 1;
    C_STATUS_USER_OVERBOOKING     CONSTANT NUMBER := 2;
    C_STATUS_CANCELLED            CONSTANT NUMBER := 3;

    PROCEDURE BOOK_TICKET(
        p_pesel IN BOOKING_HISTORY.pesel%TYPE,
        p_status OUT BOOKING_HISTORY.status%TYPE,
        p_idr  OUT BOOKING_HISTORY.idr%TYPE);
       
    PROCEDURE CANCEL_BOOKING(
        p_idr IN BOOKING_HISTORY.idr%TYPE,
        p_pesel IN BOOKING_HISTORY.pesel%TYPE,
        p_status OUT BOOKING_HISTORY.status%TYPE);


END PKG_BOOKING_TICKET;
/


CREATE OR REPLACE PACKAGE BODY PKG_BOOKING_TICKET IS

    PROCEDURE BOOK_TICKET(
        p_pesel IN BOOKING_HISTORY.pesel%TYPE,
        p_status OUT BOOKING_HISTORY.status%TYPE,
        p_idr  OUT BOOKING_HISTORY.idr%TYPE) IS
       
        c_limit                  CONSTANT NUMBER := 50000;
        c_user_reservation_limit CONSTANT NUMBER := 5;
        v_count                  NUMBER;

    BEGIN
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;  -- changing isolation level to avoid race condition

                 -- Ensuring up to 50'000 reservations
        SELECT COUNT(*) INTO v_count FROM BOOKING;
        IF v_count >= c_limit THEN
             p_status := C_STATUS_LIMIT_EXCEEDED;
             p_idr := NULL;
            INSERT INTO BOOKING_HISTORY (pesel, status) VALUES (p_pesel, C_STATUS_LIMIT_EXCEEDED);
            RETURN;
        END IF;

                 -- Ensuring that each user can book up to 5 tickets
        SELECT COUNT(*) INTO v_count FROM BOOKING WHERE pesel = p_pesel;
        IF v_count >= c_user_reservation_limit THEN
           p_status := C_STATUS_USER_OVERBOOKING;
           p_idr := NULL;
            INSERT INTO BOOKING_HISTORY (pesel, status) VALUES (p_pesel, C_STATUS_USER_OVERBOOKING);
            RETURN;
        END IF;

        p_idr := SYS_GUID();
        p_status := C_STATUS_OK;
        INSERT INTO BOOKING (idr, pesel) VALUES (p_idr, p_pesel);
        INSERT INTO BOOKING_HISTORY (idr, pesel, status) VALUES (p_idr, p_pesel, C_STATUS_OK);
        COMMIT;

    END BOOK_TICKET;


    PROCEDURE CANCEL_BOOKING(
        p_idr IN BOOKING_HISTORY.idr%TYPE,
        p_pesel IN BOOKING_HISTORY.pesel%TYPE,
        p_status OUT BOOKING_HISTORY.status%TYPE) IS
       
        v_reservation_count NUMBER;

    BEGIN
        SELECT COUNT(*) INTO v_reservation_count FROM BOOKING WHERE idr = p_idr AND pesel = p_pesel;
        IF v_reservation_count >= 0 THEN
            DELETE FROM BOOKING WHERE idr = p_idr AND pesel = p_pesel;
            INSERT INTO BOOKING_HISTORY (idr, pesel, status) VALUES (p_idr, p_pesel, C_STATUS_CANCELLED);
            p_status := C_STATUS_CANCELLED;
            COMMIT;
        END IF;
    END CANCEL_BOOKING;
END PKG_BOOKING_TICKET;
/