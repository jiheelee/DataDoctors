/*
T_CUST33 테이블 구조
   CUST_NO       VARCHAR2(7),
   CUST_NM       VARCHAR2(50),
   CUST_CD       VARCHAR2(3),
   DIV           VARCHAR2(3),
   FLAG          VARCHAR2(2),
   C1            VARCHAR2(30),
   C2            VARCHAR2(30),
   C3            VARCHAR2(30),
   C4            VARCHAR2(30),
   C5            VARCHAR2(30)
   
PRIMARY KEY : CUST_NO
인덱스      : CUST_CD + FLAG + DIV


T_CUST33  200만건
  - CUST_CD   200개 종류(001 ~ 200),  코드당 건수는 약  1만건 
  - DIV       100개 종류(001 ~ 100),  코드당 건수는 약  2만건
  - FLAG      10개  종류(01 ~ 10),    코드당 건수는 약 20만건

문제) 화면에 CUST_CD, FLAG,  DIV 3가지 조회 조건이 존재한다.  
      CUST_CD,  DIV는 필수이지만,  FLAG는 선택 조건이다.
      3조건이 모두 입력되었을 경우 평균 출력 건수는 11건이며,
      FLAG가 입력되지 않았을 경우 평균 출력 건수는 100여 건이다.
      아래의 SQL을 튜닝 하세요.   
      FLAG 조건이 들어왔을 경우는 연산자를 LIKE 대신 "="로
      변경해도 결과값은 동일하다.
      
      FLAG가 NULLABLE 일 경우와 NOT NULL 속성일 경우 2가지로 
      풀어 보세요.
*/
 ALTER SESSION SET STATISTICS_LEVEL = ALL;
 /*+ GATHER_PLAN_STATISTICS */
 SELECT * FROM TABLE(DBMS_XPLAN.display_cursor(NULL,NULL, 'ADVANCED ALLSTATS LAST'));
CUST_CD  FLAG  DIV 
124     	460	 50 	12
181     	030	 20	  14
110	      890  40	  24
SELECT /*+ GATHER_PLAN_STATISTICS */ * FROM T_CUST33 
WHERE CUST_CD =    :CUST_CD
  AND FLAG    LIKE :FLAG|| '%'
  AND DIV     =    :DIV 
;
/* 튜닝 전 실행 계획
1) FLAG NULLABLE 일때
- FLAG 변수 들어왔을 때
-------------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                   | Name        | Starts | E-Rows |E-Bytes| Cost (%CPU)| E-Time   | A-Rows |   A-Time   | Buffers |
-------------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |             |      1 |        |       |    13 (100)|          |     24 |00:00:00.01 |      27 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T_CUST33    |      1 |     81 | 10206 |    13   (0)| 00:00:01 |     24 |00:00:00.01 |      27 |
|*  2 |   INDEX RANGE SCAN          | IX_T_CUST33 |      1 |      6 |       |     7   (0)| 00:00:01 |     24 |00:00:00.01 |       3 |
-------------------------------------------------------------------------------------------------------------------------------------
- FLAG 변수 안 들어왔을 때
----------------------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                   | Name        | Starts | E-Rows |E-Bytes| Cost (%CPU)| E-Time   | A-Rows |   A-Time   | Buffers | Reads  |
----------------------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |             |      1 |        |       |    13 (100)|          |    191 |00:00:00.02 |     259 |    116 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T_CUST33    |      1 |     81 | 10206 |    13   (0)| 00:00:01 |    191 |00:00:00.02 |     259 |    116 |
|*  2 |   INDEX RANGE SCAN          | IX_T_CUST33 |      1 |      6 |       |     7   (0)| 00:00:01 |    191 |00:00:00.01 |      68 |      0 |
----------------------------------------------------------------------------------------------------------------------------------------------
   2 - access("CUST_CD"=:CUST_CD AND "FLAG" LIKE :FLAG||'%' AND "DIV"=:DIV)
       filter(("DIV"=:DIV AND "FLAG" LIKE :FLAG||'%'))
*/
/* 튜닝  - NULLABLE 일때 */
CREATE INDEX IX02_T_CUST33 ON T_CUST33(CUST_CD, DIV, FLAG);
 SELECT * FROM TABLE(DBMS_XPLAN.display_cursor(NULL,NULL, 'ADVANCED ALLSTATS LAST'));
SELECT /*+ GATHER_PLAN_STATISTICS NO_QUERY_TRANSFORMATION INDEX(T1 IX02_T_CUST33) */ 
* FROM t_cust33
WHERE :FLAG IS NULL
AND CUST_CD = :CUST_CD
AND DIV = :DIV
UNION ALL
SELECT /*+ GATHER_PLAN_STATISTICS NO_QUERY_TRANSFORMATION INDEX(T1 IX02_T_CUST33) */ 
* FROM T_CUST33 T1
WHERE CUST_CD =    :CUST_CD
  AND :FLAG IS NOT NULL
  AND FLAG    = :FLAG
  AND DIV     =    :DIV 
;
/* 튜닝 후 실행계획
- FLAG 변수로 들어왔을 때
-----------------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name          | Starts | E-Rows |E-Bytes| Cost (%CPU)| E-Time   | A-Rows |   A-Time   | Buffers |
-----------------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |               |      1 |        |       |    39 (100)|          |     24 |00:00:00.01 |      27 |
|   1 |  UNION-ALL                    |               |      1 |        |       |            |          |     24 |00:00:00.01 |      27 |
|*  2 |   FILTER                      |               |      1 |        |       |            |          |      0 |00:00:00.01 |       0 |
|   3 |    TABLE ACCESS BY INDEX ROWID| T_CUST33      |      0 |    208 | 26208 |    35   (0)| 00:00:01 |      0 |00:00:00.01 |       0 |
|*  4 |     INDEX RANGE SCAN          | IX02_T_CUST33 |      0 |     33 |       |     3   (0)| 00:00:01 |      0 |00:00:00.01 |       0 |
|*  5 |   FILTER                      |               |      1 |        |       |            |          |     24 |00:00:00.01 |      27 |
|   6 |    TABLE ACCESS BY INDEX ROWID| T_CUST33      |      1 |      2 |   252 |     4   (0)| 00:00:01 |     24 |00:00:00.01 |      27 |
|*  7 |     INDEX RANGE SCAN          | IX02_T_CUST33 |      1 |      1 |       |     3   (0)| 00:00:01 |     24 |00:00:00.01 |       3 |
-----------------------------------------------------------------------------------------------------------------------------------------
- FLAG 변수로 안 들어왔을 때
-----------------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name          | Starts | E-Rows |E-Bytes| Cost (%CPU)| E-Time   | A-Rows |   A-Time   | Buffers |
-----------------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |               |      1 |        |       |    39 (100)|          |    191 |00:00:00.01 |     197 |
|   1 |  UNION-ALL                    |               |      1 |        |       |            |          |    191 |00:00:00.01 |     197 |
|*  2 |   FILTER                      |               |      1 |        |       |            |          |    191 |00:00:00.01 |     197 |
|   3 |    TABLE ACCESS BY INDEX ROWID| T_CUST33      |      1 |    208 | 26208 |    35   (0)| 00:00:01 |    191 |00:00:00.01 |     197 |
|*  4 |     INDEX RANGE SCAN          | IX02_T_CUST33 |      1 |     33 |       |     3   (0)| 00:00:01 |    191 |00:00:00.01 |       6 |
|*  5 |   FILTER                      |               |      1 |        |       |            |          |      0 |00:00:00.01 |       0 |
|   6 |    TABLE ACCESS BY INDEX ROWID| T_CUST33      |      0 |      2 |   252 |     4   (0)| 00:00:01 |      0 |00:00:00.01 |       0 |
|*  7 |     INDEX RANGE SCAN          | IX02_T_CUST33 |      0 |      1 |       |     3   (0)| 00:00:01 |      0 |00:00:00.01 |       0 |
-----------------------------------------------------------------------------------------------------------------------------------------

*/

/* 튜닝  - NOT NULL 일때 */
CREATE INDEX IX02_T_CUST33 ON T_CUST33(CUST_CD, DIV, FLAG);
 SELECT * FROM TABLE(DBMS_XPLAN.display_cursor(NULL,NULL, 'ADVANCED ALLSTATS LAST'));
SELECT /*+ GATHER_PLAN_STATISTICS NO_QUERY_TRANSFORMATION INDEX(T1 IX02_T_CUST33) */ 
* FROM t_cust33 T1
WHERE FLAG = NVL(:FLAG, FLAG) 
AND CUST_CD = :CUST_CD
AND DIV = :DIV 
;
/* 튜닝 후 실행계획
- FLAG 변수로 안 들어왔을 때
---------------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                   | Name          | Starts | E-Rows |E-Bytes| Cost (%CPU)| E-Time   | A-Rows |   A-Time   | Buffers |
---------------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |               |      1 |        |       |     4 (100)|          |    191 |00:00:00.01 |     197 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T_CUST33      |      1 |      2 |   252 |     4   (0)| 00:00:01 |    191 |00:00:00.01 |     197 |
|*  2 |   INDEX RANGE SCAN          | IX02_T_CUST33 |      1 |      1 |       |     3   (0)| 00:00:01 |    191 |00:00:00.01 |       6 |
---------------------------------------------------------------------------------------------------------------------------------------
*/
/*
튜닝포인트!!!
1. 확실히 들어와서 = 로 조회해줄 수 있는 조건들은 INDEX 선두 컬럼으로
2. 들어올지 안 들어올지 모르는 컬럼은 마지막 INDEX로 지정해주고 UNION ALL 로 나누거나 OR_EXPANSION 으로 만든다.
3. NOT NULL 컬럼일 경우에는 NVL을 써서 쿼리를 깔끔하게 만들어줄 수 있다.
*/