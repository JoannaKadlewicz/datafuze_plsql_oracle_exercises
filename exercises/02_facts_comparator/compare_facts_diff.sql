CREATE OR REPLACE PACKAGE PKG_COMPARE_FACT IS
    C_STATUS_MODIFIED CONSTANT NUMBER := 1;
    C_STATUS_NEW      CONSTANT NUMBER := 2;
    C_STATUS_DELETED  CONSTANT NUMBER := 3;

    PROCEDURE COMPARE_FACT(
        P_ID_PACK_OLD IN FACT_HISTORY.ID_PACK%TYPE,
        P_ID_PACK_NEW IN FACT_HISTORY.ID_PACK%TYPE,
        P_BUILD_DIFF  IN BOOLEAN DEFAULT FALSE);
END PKG_COMPARE_FACT;
/

CREATE OR REPLACE PACKAGE BODY PKG_COMPARE_FACT IS

    PROCEDURE COMPARE_FACT(
            P_ID_PACK_OLD IN FACT_HISTORY.ID_PACK%TYPE,
            P_ID_PACK_NEW IN FACT_HISTORY.ID_PACK%TYPE,
            P_BUILD_DIFF  IN BOOLEAN DEFAULT FALSE) IS
        BEGIN
                -- Dropping table and ignore error if tables does not exist
            BEGIN
                EXECUTE IMMEDIATE 'DROP TABLE TMP_FACT_HISTORY_COMPARE_STATUS';
                EXECUTE IMMEDIATE 'DROP TABLE TMP_FACT_HISTORY_COMPARE_DIFF';
            EXCEPTION
                WHEN OTHERS THEN
                    IF SQLCODE != -942 THEN
                        RAISE;
                    END IF;
            END;

        EXECUTE IMMEDIATE 'CREATE TABLE TMP_FACT_HISTORY_COMPARE_STATUS (ID_FACT NUMBER NOT NULL, STATUS NUMBER NOT NULL)';
        EXECUTE IMMEDIATE 'CREATE TABLE TMP_FACT_HISTORY_COMPARE_DIFF (ID_FACT NUMBER NOT NULL, COL_NAME VARCHAR2(100) NOT NULL, COL_TYPE VARCHAR2(30) NOT NULL, COL_OLD_VALUE VARCHAR2(4000), COL_NEW_VALUE VARCHAR2(4000))';

                -- If record exists in OLD, but is missing in NEW -> DELETED
        INSERT INTO TMP_FACT_HISTORY_COMPARE_STATUS (ID_FACT, STATUS)
        SELECT ID_FACT, C_STATUS_DELETED
        FROM (SELECT ID_FACT
            FROM FACT_HISTORY
            WHERE ID_PACK = P_ID_PACK_OLD
                MINUS
            SELECT ID_FACT
            FROM FACT_HISTORY
            WHERE ID_PACK = P_ID_PACK_NEW) t;

                 -- If record exists in NEW, but is missing in OLD -> NEW
        INSERT INTO TMP_FACT_HISTORY_COMPARE_STATUS (ID_FACT, STATUS)
        SELECT ID_FACT, C_STATUS_NEW
        FROM (SELECT ID_FACT
              FROM FACT_HISTORY
              WHERE ID_PACK = P_ID_PACK_NEW
                  MINUS
              SELECT ID_FACT
              FROM FACT_HISTORY
              WHERE ID_PACK = P_ID_PACK_OLD) t;

                 -- Iterating over modified facts (hashes differ)
                FOR rec IN(
                    WITH FACTS_WITH_HASH AS (
                        SELECT ID_FACT,
                               ID_PACK,
                               FACT_NAME,
                               FACT_VALUE,
                               FACT_DATE,
                               ORA_HASH(ID_FACT || FACT_NAME || FACT_DATE || FACT_VALUE) AS ROW_HASH  -- calculate hash
                        FROM FACT_HISTORY
                        WHERE ID_PACK IN (P_ID_PACK_NEW, P_ID_PACK_OLD)
                    )
                    SELECT
                        n.ID_FACT,
                        n.ID_PACK,
                        n.FACT_NAME AS NEW_FACT_NAME,
                        O.FACT_NAME AS OLD_FACT_NAME,
                        n.FACT_VALUE AS NEW_FACT_VALUE,
                        O.FACT_VALUE AS OLD_FACT_VALUE,
                        n.FACT_DATE AS NEW_FACT_DATE,
                        O.FACT_DATE AS OLD_FACT_DATE
                    FROM FACTS_WITH_HASH n
                             JOIN FACTS_WITH_HASH o
                                  ON n.ID_FACT = o.ID_FACT
                                      AND n.ID_PACK = P_ID_PACK_NEW
                                      AND o.ID_PACK = P_ID_PACK_OLD
                    WHERE n.ROW_HASH != o.ROW_HASH
                    ) LOOP

                        INSERT INTO TMP_FACT_HISTORY_COMPARE_STATUS VALUES (rec.ID_FACT, C_STATUS_MODIFIED);

                        IF P_BUILD_DIFF THEN

                            IF rec.NEW_FACT_NAME != rec.OLD_FACT_NAME THEN
                                INSERT INTO TMP_FACT_HISTORY_COMPARE_DIFF VALUES (rec.ID_FACT, 'FACT_NAME', 'VARCHAR(100)', rec.OLD_FACT_NAME, rec.NEW_FACT_NAME);
                            END IF;

                            IF rec.NEW_FACT_VALUE != rec.OLD_FACT_VALUE THEN
                                INSERT INTO TMP_FACT_HISTORY_COMPARE_DIFF VALUES (rec.ID_FACT, 'FACT_VALUE', 'DECIMAL(10,2)', rec.OLD_FACT_VALUE, rec.NEW_FACT_VALUE);
                            END IF;

                             IF rec.NEW_FACT_DATE != rec.OLD_FACT_DATE THEN
                                INSERT INTO TMP_FACT_HISTORY_COMPARE_DIFF VALUES (rec.ID_FACT, 'FACT_DATE', 'DATE', rec.NEW_FACT_DATE, rec.OLD_FACT_DATE);
                            END IF;

                        END IF;

                    END LOOP;

                COMMIT;
            END COMPARE_FACT;
END PKG_COMPARE_FACT;
/
