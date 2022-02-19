--아래의 SQL을 실행하여 얻은 Trace 결과이다.
ALTER SESSION SET STATISTICS_LEVEL = ALL;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));

SELECT /*+ GATHER_PLAN_STATISTICS LEADING(M P O) USE_NL(P) USE_NL(O) INDEX(O IX_T_ORDER_01) */
       P.PROD_NM, P.PROD_ID, O.ORDER_QTY
FROM   T_MANUF M, T_PRODUCT P,  T_ORDER O
WHERE  M.M_CODE BETWEEN 'M00001' AND 'M00100'
 AND   P.M_CODE  = M.M_CODE
 AND   O.PROD_ID = P.PROD_ID
 AND   O.ORDER_DT = '20160412'
 AND   O.ORDER_QTY > 9000;
DROP INDEX IX_T_ORDER_01;
CREATE INDEX IX_T_ORDER_01 ON T_ORDER  (ORDER_DT, ORDER_QTY, PROD_ID);
CREATE INDEX IX_T_ORDER_01 ON T_ORDER  (ORDER_DT, PROD_ID, ORDER_QTY);

/* Index 정보
PK_T_MANUF    : T_MANUF  (M_CODE)
PK_T_PRODUCT  : T_PRODUCT(M_CODE)
IX_T_ORDER_01 : T_ORDER  (ORDER_DT + ORDER_QTY + PROD_ID)

CREATE UNIQUE INDEX YOON.PK_T_MANUF    ON YOON.T_MANUF  (M_CODE);
CREATE UNIQUE INDEX YOON.PK_T_PRODUCT  ON YOON.T_PRODUCT(M_CODE);
CREATE        INDEX YOON.IX_T_ORDER_01 ON YOON.T_ORDER  (ORDER_DT, ORDER_QTY, PROD_ID);

Rows     Row Source Operation
-------  ---------------------------------------------------
   32  NESTED LOOPS  (cr=10148 pr=0 pw=0 time=27590 us cost=629 ...)
10000   NESTED LOOPS  (cr=10138 pr=0 pw=0 time=14682 us cost=108 ...)
  100    INDEX RANGE SCAN PK_T_MANUF (cr=3 pr=0 pw=0 time=99 us cost=2 ...)
10000    TABLE ACCESS BY INDEX ROWID T_PRODUCT (cr=10135 pr=0 pw=0 time=12005 us cost=106...)
10000     INDEX RANGE SCAN PK_T_PRODUCT (cr=135 pr=0 pw=0 time=1810 us cost=1...)
   32   INDEX RANGE SCAN IX_T_ORDER_01 (cr=10 pr=0 pw=0 time=0 us cost=5 ...)

---------------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name          | Starts | E-Rows | A-Rows |   A-Time   | Buffers |
---------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |               |      1 |        |     32 |00:00:00.04 |   10143 |
|   1 |  NESTED LOOPS                 |               |      1 |     36 |     32 |00:00:00.04 |   10143 |
|   2 |   NESTED LOOPS                |               |      1 |  11750 |  10000 |00:00:00.02 |   10135 |
|*  3 |    INDEX RANGE SCAN           | PK_T_MANUF    |      1 |    100 |    100 |00:00:00.01 |       2 |
|   4 |    TABLE ACCESS BY INDEX ROWID| T_PRODUCT     |    100 |    117 |  10000 |00:00:00.01 |   10133 |
|*  5 |     INDEX RANGE SCAN          | PK_T_PRODUCT  |    100 |      1 |  10000 |00:00:00.01 |     133 |
|*  6 |   INDEX RANGE SCAN            | IX_T_ORDER_01 |  10000 |      1 |     32 |00:00:00.03 |       8 |
---------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------
문제) SQL 정보 변경없이 인덱스 정보를 변경하여 튜닝한 결과의 Trace 파일이다.  
어떤 정보가 변경되었는가?
--------------------------------------------------------------------

Rows     Row Source Operation
-------  ---------------------------------------------------
     32  NESTED LOOPS  (cr=224 pr=0 pw=0 time=9300 us cost=11554...)
  10000   NESTED LOOPS  (cr=214 pr=0 pw=0 time=3797 us cost=1252...)
    100    INDEX RANGE SCAN PK_T_MANUF (cr=3 pr=0 pw=0 time=99 us cost=3...)
  10000    INDEX RANGE SCAN IX_T_PRODUCT_01 (cr=211 pr=0 pw=0 time=2844 us cost=2 ...)
     32   INDEX RANGE SCAN IX_T_ORDER_02 (cr=10 pr=0 pw=0 time=0 us cost=1...)
*/
/*튜닝후*/
CREATE INDEX IX_T_PRODUCT_01  ON T_PRODUCT(M_CODE, PROD_ID, PROD_NM);
CREATE INDEX IX_T_ORDER_02 ON T_ORDER  (PROD_ID, ORDER_DT, ORDER_QTY);

SELECT /*+ GATHER_PLAN_STATISTICS NO_QUERY_TRANSFORMATION LEADING(M P O) USE_NL(P) USE_NL(O) INDEX(P IX_T_PRODUCT_01) INDEX(O IX_T_ORDER_01) */ 
       P.PROD_NM, P.PROD_ID, O.ORDER_QTY
FROM   T_MANUF M, T_PRODUCT P,  T_ORDER O
WHERE  M.M_CODE BETWEEN 'M00001' AND 'M00100'
 AND   P.M_CODE  = M.M_CODE
 AND   O.PROD_ID = P.PROD_ID
 AND   O.ORDER_DT = '20160412'
 AND   O.ORDER_QTY > 9000;

MCODE, PROD_ID, PROD_NM
PROD_ID, ORDER_DT, ORDER_QTY;

---------------------------------------------------------------------------------------------------------
| Id  | Operation          | Name            | Starts | E-Rows | A-Rows |   A-Time   | Buffers | Reads  |
---------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |                 |      1 |        |     32 |00:00:00.06 |   10213 |    152 |
|   1 |  NESTED LOOPS      |                 |      1 |     36 |     32 |00:00:00.06 |   10213 |    152 |
|   2 |   NESTED LOOPS     |                 |      1 |  11750 |  10000 |00:00:00.03 |     211 |    108 |
|*  3 |    INDEX RANGE SCAN| PK_T_MANUF      |      1 |    100 |    100 |00:00:00.01 |       2 |      0 |
|*  4 |    INDEX RANGE SCAN| IX_T_PRODUCT_01 |    100 |    117 |  10000 |00:00:00.03 |     209 |    108 |
|*  5 |   INDEX RANGE SCAN | IX_T_ORDER_02   |  10000 |      1 |     32 |00:00:00.03 |   10002 |     44 |
---------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
| Id  | Operation          | Name            | Starts | E-Rows | A-Rows |   A-Time   | Buffers |
------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |                 |      1 |        |     32 |00:00:00.04 |     219 |
|   1 |  NESTED LOOPS      |                 |      1 |     36 |     32 |00:00:00.04 |     219 |
|   2 |   NESTED LOOPS     |                 |      1 |  11750 |  10000 |00:00:00.01 |     211 |
|*  3 |    INDEX RANGE SCAN| PK_T_MANUF      |      1 |    100 |    100 |00:00:00.01 |       2 |
|*  4 |    INDEX RANGE SCAN| IX_T_PRODUCT_01 |    100 |    117 |  10000 |00:00:00.01 |     209 |
|*  5 |   INDEX RANGE SCAN | IX_T_ORDER_01   |  10000 |      1 |     32 |00:00:00.03 |       8 |
------------------------------------------------------------------------------------------------

/*
튜닝포인트!!!
1. 조건절, SELECT 절을 모두 인덱스에 때려넣어봄
2. 작은 테이블부터 JOIN
3. 조인 컬럼이 후행 테이블의 선두 컬럼이 아니더라도, 인덱스에 있으면 조인됨
*/