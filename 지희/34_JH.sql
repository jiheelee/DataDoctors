ALTER SESSION SET WORKAREA_SIZE_POLICY  = MANUAL;
ALTER SESSION SET SORT_AREA_SIZE = 1000000000;

--1)
CREATE INDEX YOON.IX_T1_34_01
ON YOON.T1_34(C5);

DROP INDEX YOON.IX_T2_34_02;
CREATE INDEX YOON.IX_T2_34_02
ON YOON.T2_34(C1, C2, C3);

--2)
DROP INDEX YOON.IX_T2_34_03;
CREATE INDEX YOON.IX_T2_34_03
ON YOON.T2_34(C1);

DROP INDEX YOON.IX_T2_34_02;
CREATE INDEX YOON.IX_T2_34_02
ON YOON.T2_34(C2, C3);

EXECUTE DBMS_STATS.GATHER_TABLE_STATS('YOON', 'T1_34');
EXECUTE DBMS_STATS.GATHER_TABLE_STATS('YOON', 'T2_34');

ALTER SESSION SET STATISTICS_LEVEL = ALL;

SELECT /*+ ORDERED USE_HASH(T2) INDEX(T1 IX_T1_34_01) INDEX(T2  IX_T2_34_01) */ * 
FROM T1_34 T1, T2_34 T2
WHERE T1.C5 = 'A'
 AND  T2.C1 = T1.C1
 AND  T2.C2 = 10
 AND  T2.C3 = 123
;

SELECT /*+ ORDERED USE_HASH(T2) INDEX(T1 IX_T1_34_01) INDEX(T2  IX_T2_34_02) */ *
FROM T1_34 T1, T2_34 T2
WHERE T1.C5 = 'A'
 AND  T2.C1 = T1.C1
 AND  T2.C2 = 10
 AND  T2.C3 = 123
;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));
/*
---------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                    | Name        | Starts | E-Rows | A-Rows |   A-Time   | Buffers |  OMem |  1Mem | Used-Mem |
---------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |             |      1 |        |   1000 |00:00:00.04 |    2028 |       |       |          |
|*  1 |  HASH JOIN                   |             |      1 |    100 |   1000 |00:00:00.04 |    2028 |   776K|   776K|   74M (0)|
|   2 |   TABLE ACCESS BY INDEX ROWID| T1_34       |      1 |    100 |    100 |00:00:00.01 |       4 |       |       |          |
|*  3 |    INDEX RANGE SCAN          | IX_T1_34_01 |      1 |     98 |    100 |00:00:00.01 |       3 |       |       |          |
|   4 |   TABLE ACCESS BY INDEX ROWID| T2_34       |      1 |   2012 |   2012 |00:00:00.01 |    2024 |       |       |          |
|*  5 |    INDEX RANGE SCAN          | IX_T2_34_01 |      1 |   2053 |   2012 |00:00:00.01 |      14 |       |       |          |
---------------------------------------------------------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
   1 - access("T2"."C1"="T1"."C1")
   3 - access("T1"."C5"='A')
   5 - access("T2"."C2"=10 AND "T2"."C3"=123)
 
  
---------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                    | Name        | Starts | E-Rows | A-Rows |   A-Time   | Buffers |  OMem |  1Mem | Used-Mem |
---------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |             |      1 |        |   1000 |00:00:00.04 |    1040 |       |       |          |
|*  1 |  HASH JOIN                   |             |      1 |    100 |   1000 |00:00:00.04 |    1040 |   776K|   776K|   74M (0)|
|   2 |   TABLE ACCESS BY INDEX ROWID| T1_34       |      1 |    100 |    100 |00:00:00.01 |       4 |       |       |          |
|*  3 |    INDEX RANGE SCAN          | IX_T1_34_01 |      1 |     98 |    100 |00:00:00.01 |       3 |       |       |          |
|   4 |   TABLE ACCESS BY INDEX ROWID| T2_34       |      1 |   2012 |   2012 |00:00:00.01 |    1036 |       |       |          |
|*  5 |    INDEX RANGE SCAN          | IX_T2_34_02 |      1 |   2053 |   2012 |00:00:00.01 |      10 |       |       |          |
---------------------------------------------------------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
   1 - access("T2"."C1"="T1"."C1")
   3 - access("T1"."C5"='A')
   5 - access("T2"."C2"=10 AND "T2"."C3"=123)


T2_34 테이블을 읽을 때 IX_T2_34_01 과 IX_T2_34_02 인덱스 사용시 Buffer를 읽는 수치의 차이는
IX_T2_34_02 인덱스의 C.F가 좋아 buffer pinning 효과가 높아 발생하는 것으로 의미 없음.
 
 */

--3
ALTER SESSION SET STATISTICS_LEVEL = ALL;
 
DROP INDEX YOON.IX_T2_34_01;
CREATE INDEX YOON.IX_T2_34_01
ON YOON.T2_34(C2, C3, C1);

SELECT /*+ NO_QUERY_TRANSFORMATION LEADING(T1 T2_BRG T2)  USE_HASH(T2_BRG) */ T1.*, T2.*
FROM   T1_34 T1, T2_34 T2, T2_34 T2_BRG
WHERE  T1.C5 = 'A'
 AND   T2_BRG.C1 = T1.C1
 AND   T2_BRG.C2 = 10
 AND   T2_BRG.C3 = 123
 AND   T2.ROWID  = T2_BRG.ROWID;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'IOSTATS LAST -ROWS'));
EXECUTE DBMS_STATS.GATHER_TABLE_STATS('YOON', 'T1_34');
EXECUTE DBMS_STATS.GATHER_TABLE_STATS('YOON', 'T2_34');
/*
PLAN_TABLE_OUTPUT
-------------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name        | Starts | A-Rows |   A-Time   | Buffers | Reads  |
-------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |             |      1 |   1000 |00:00:00.05 |    1032 |     19 |
|   1 |  NESTED LOOPS                 |             |      1 |   1000 |00:00:00.05 |    1032 |     19 |
|*  2 |   HASH JOIN                   |             |      1 |   1000 |00:00:00.04 |      32 |      5 |
|   3 |    TABLE ACCESS BY INDEX ROWID| T1_34       |      1 |    100 |00:00:00.01 |       4 |      0 |
|*  4 |     INDEX RANGE SCAN          | IX_T1_34_01 |      1 |    100 |00:00:00.01 |       3 |      0 |
|*  5 |    INDEX RANGE SCAN           | IX_T2_34_01 |      1 |   1996 |00:00:00.01 |      28 |      5 |
|   6 |   TABLE ACCESS BY USER ROWID  | T2_34       |   1000 |   1000 |00:00:00.01 |    1000 |     14 |
-------------------------------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   2 - access("T2_BRG"."C1"="T1"."C1")
   4 - access("T1"."C5"='A')
   5 - access("T2_BRG"."C2"=10 AND "T2_BRG"."C3"=123)
*/