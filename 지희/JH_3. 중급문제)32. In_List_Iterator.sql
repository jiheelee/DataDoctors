--¾Æ·¡ SQLÀ» Æ©´× Àü ÈÄÀÇ ½ÇÇà°èÈ¹À» º¸°í Æ©´×ÇÏ½Ã¿À.
--´Ü ÀÎµ¦½º´Â º¯°æÇÒ ¼ö ¾ø½À´Ï´Ù.
CREATE INDEX IX_T_IN_LIST_01 ON T_IN_LIST(C2, C4, C3);
select * from T_IN_LIST;
ALTER SESSION SET STATIS
ALTER SESSION SET STATISTICS_LEVEL = ALL;
TICS_LEVEL = ALL;

SELECT  /*+ GATHER_PLAN_STATISTICS INDEX(T1 IX_T_IN_LIST_01) */ *
FROM T_IN_LIST T1
WHERE T1.C2 = '00186'
 AND  T1.C3 IN ('00033', '00034'
 , '00035', '00036', '00043', '00044', '00045'
            ,'00046', '00053', '00054', '00055', '00056', '00063', '00064' 
            ,'00065', '00066', '00073', '00074', '00075', '00076', '00083', 
            '00084', '00085', '00086'
             )
 AND  T1.C4 = '00016';
 
 SELECT * FROM TABLE(DBMS_XPLAN.display_cursor(NULL,NULL, 'ADVANCED ALLSTATS LAST'));
/* Æ©´×Àü °èÈ¹ 
------------------------------------------------------------------------------------------------------------------
| Id  | Operation                   | Name            | Starts | E-Rows | A-Rows |   A-Time   | Buffers | Reads  |
------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |                 |      1 |        |      1 |00:00:00.01 |       4 |      3 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T_IN_LIST       |      1 |      1 |      1 |00:00:00.01 |       4 |      3 |
|*  2 |   INDEX RANGE SCAN          | IX_T_IN_LIST_01 |      1 |      1 |      1 |00:00:00.01 |       3 |      2 |
------------------------------------------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   2 - access("C2"='00050' AND "C4"='00054')
       filter(("C3"='00033' OR "C3"='00034' OR "C3"='00035' OR "C3"='00036' OR "C3"='00043' OR 
              "C3"='00044' OR "C3"='00045' OR "C3"='00046' OR "C3"='00053' OR "C3"='00054' OR "C3"='00055' OR 
              "C3"='00056' OR "C3"='00063' OR "C3"='00064' OR "C3"='00065' OR "C3"='00066' OR "C3"='00073' OR 
              "C3"='00074' OR "C3"='00075' OR "C3"='00076' OR "C3"='00083' OR "C3"='00084' OR "C3"='00085' OR 
              "C3"='00086'))
*/
SELECT  /*+ GATHER_PLAN_STATISTICS INDEX(T1 IX_T_IN_LIST_01) */ *
FROM T_IN_LIST T1
WHERE T1.C2 = '00186'
 AND  TRIM(T1.C3) IN ('00033', '00034'
 , '00035', '00036', '00043', '00044', '00045'
            ,'00046', '00053', '00054', '00055', '00056', '00063', '00064' 
            ,'00065', '00066', '00073', '00074', '00075', '00076', '00083', 
            '00084', '00085', '00086'
             )
 AND  T1.C4 = '00016';


SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST - ROWS'));
/*
ÀÎµ¦½º
CREATE INDEX YOON.IX_T_IN_LIST_01  ON YOON.T_IN_LIST(C2, C4, C3); 

Æ©´× Àü
PLAN_TABLE_OUTPUT
-------------------------------------------------------------------------
| Id  | Operation                    | Name            |A-Rows| Buffers |
-------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                 |     3|      40 |
|   1 |  INLIST ITERATOR             |                 |     3|      40 |
|   2 |   TABLE ACCESS BY INDEX ROWID| T_IN_LIST       |     3|      40 |
|*  3 |    INDEX RANGE SCAN          | IX_T_IN_LIST_01 |     3|      37 |
-------------------------------------------------------------------------

Æ©´× ÈÄ
PLAN_TABLE_OUTPUT
------------------------------------------------------------------------
| Id  | Operation                   | Name            |A-Rows| Buffers |
------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |                 |     3|       7 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T_IN_LIST       |     3|       7 |
|*  2 |   INDEX RANGE SCAN          | IX_T_IN_LIST_01 |     3|       4 |
------------------------------------------------------------------------
*/




-----------------------------------------------------------------------------------------------------------------------------------------