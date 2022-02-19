/*  테이블 
       - 사원 (약10만건), 부서(100건)

    INDEX 
       - 사원PK : EMP_NO   
       - 부서PK : DEPT_CODE

아래 SQL을 튜닝 하세요.

  문제 1) E.DIV_CODE='01'의 결과 : 10건,   D.LOC='01'의 결과 30건
  문제 2) E.DIV_CODE='01'의 결과 : 100건,   D.LOC='01'의 결과 3건
*/

/* 문제 1번 */
/* 1) 데이터 건수 맞추기 
E.DIV_CODE='01'의 결과 : 10건,   D.LOC='01'의 결과 30건
*/
SELECT  /*+ GATHER_PLAN_STATISTICS ORDERED USE_NL(D) */
        E.EMP_NO,  E.EMP_NAME,  E.DIV_CODE,  
        D.DEPT_CODE,  D.DEPT_NAME,  D.LOC
FROM  T_EMP  E,  T_DEPT  D
WHERE E.DIV_CODE    = '01'
 AND  D.DEPT_CODE   = E.DEPT_CODE
 AND  D.LOC = '01';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('',1,'ADVANCED ALLSTATS LAST'));
/*튜닝전 실행 결과*/
/*------------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                    | Name      | Starts | E-Rows |E-Bytes| Cost (%CPU)| E-Time   | A-Rows |   A-Time   | Buffers |
------------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |           |      1 |        |       |   259 (100)|          |      5 |00:00:00.01 |     963 |
|   1 |  NESTED LOOPS                |           |      1 |        |       |            |          |      5 |00:00:00.01 |     963 |
|   2 |   NESTED LOOPS               |           |      1 |     10 |   700 |   259   (1)| 00:00:04 |     10 |00:00:00.01 |     953 |
|*  3 |    TABLE ACCESS FULL         | T_EMP     |      1 |     10 |   370 |   259   (1)| 00:00:04 |     10 |00:00:00.01 |     949 |
|*  4 |    INDEX UNIQUE SCAN         | PK_T_DEPT |     10 |      1 |       |     0   (0)|          |     10 |00:00:00.01 |       4 |
|*  5 |   TABLE ACCESS BY INDEX ROWID| T_DEPT    |     10 |      1 |    33 |     0   (0)|          |      5 |00:00:00.01 |      10 |
------------------------------------------------------------------------------------------------------------------------------------

2) 문제점 :
- EMP 인덱스가 없어 테이블 풀스캔중임
- DEPT 테이블의 LOC 인덱스가 없어 테이블에 직접 접근하여 필터로 걸러내기 때문에 시간이 오래 걸림

3) 개선방향:
- EMP,DEPT 테이블의 INDEX 생성*/
/* 인덱스 튜닝 */
DROP INDEX IX_T_EMP_01;
CREATE INDEX IX_T_EMP_01 ON T_EMP(DIV_CODE);
CREATE INDEX IX_T_DEPT_01 ON T_DEPT(DEPT_CODE, LOC);
SELECT  /*+ GATHER_PLAN_STATISTICS ORDERED USE_NL(D) INDEX(E IX_T_EMP_01) INDEX(D IX_T_DEPT_01) */
        E.EMP_NO,  E.EMP_NAME,  E.DIV_CODE,  
        D.DEPT_CODE,  D.DEPT_NAME,  D.LOC
FROM  T_EMP  E,  T_DEPT  D
WHERE E.DIV_CODE    = '01'
 AND  D.DEPT_CODE   = E.DEPT_CODE
 AND  D.LOC = '01';
 SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('',1,'ADVANCED ALLSTATS LAST'));
/* 튜닝 후 실행결과
----------------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name         | Starts | E-Rows |E-Bytes| Cost (%CPU)| E-Time   | A-Rows |   A-Time   | Buffers |
----------------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |              |      1 |        |       |    17 (100)|          |      5 |00:00:00.01 |       7 |
|   1 |  NESTED LOOPS                 |              |      1 |        |       |            |          |      5 |00:00:00.01 |       7 |
|   2 |   NESTED LOOPS                |              |      1 |     10 |   700 |    17   (0)| 00:00:01 |      5 |00:00:00.01 |       6 |
|   3 |    TABLE ACCESS BY INDEX ROWID| T_EMP        |      1 |     10 |   370 |     7   (0)| 00:00:01 |     10 |00:00:00.01 |       3 |
|*  4 |     INDEX RANGE SCAN          | IX_T_EMP_01  |      1 |     10 |       |     1   (0)| 00:00:01 |     10 |00:00:00.01 |       2 |
|*  5 |    INDEX RANGE SCAN           | IX_T_DEPT_01 |     10 |      1 |       |     0   (0)|          |      5 |00:00:00.01 |       3 |
|   6 |   TABLE ACCESS BY INDEX ROWID | T_DEPT       |      5 |      1 |    33 |     1   (0)| 00:00:01 |      5 |00:00:00.01 |       1 |
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   4 - access("E"."DIV_CODE"='01')
   5 - access("D"."DEPT_CODE"="E"."DEPT_CODE" AND "D"."LOC"='01')
*/
/* 문제 2번 E.DIV_CODE='01'의 결과 : 100건,   D.LOC='01'의 결과 3건*/
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('',1,'ADVANCED ALLSTATS LAST'));
/* 
1)튜닝 전 실행결과 
-------------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                    | Name       | Starts | E-Rows |E-Bytes| Cost (%CPU)| E-Time   | A-Rows |   A-Time   | Buffers |
-------------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |            |      1 |        |       |   259 (100)|          |     10 |00:00:00.01 |    1053 |
|   1 |  NESTED LOOPS                |            |      1 |        |       |            |          |     10 |00:00:00.01 |    1053 |
|   2 |   NESTED LOOPS               |            |      1 |      5 |   350 |   259   (1)| 00:00:04 |    100 |00:00:00.01 |     953 |
|*  3 |    TABLE ACCESS FULL         | T_EMP2     |      1 |     10 |   370 |   259   (1)| 00:00:04 |    100 |00:00:00.01 |     949 |
|*  4 |    INDEX UNIQUE SCAN         | PK_T_DEPT2 |    100 |      1 |       |     0   (0)|          |    100 |00:00:00.01 |       4 |
|*  5 |   TABLE ACCESS BY INDEX ROWID| T_DEPT2    |    100 |      1 |    33 |     0   (0)|          |     10 |00:00:00.01 |     100 |
-------------------------------------------------------------------------------------------------------------------------------------

2) 문제점 :
- EMP 인덱스가 없어 테이블 풀스캔중임
- DEPT 테이블의 LOC 인덱스가 없어 테이블에 직접 접근하여 필터로 걸러내기 때문에 시간이 오래 걸림
- 조인시 DEPT 테이블보다 EMP 테이블이 커서 쓸데없는 데이터들을 많이 읽고 있음

3) 개선방향:
- EMP,DEPT 테이블의 INDEX 생성
- 선행 테이블을 EMP => DEPT로 변경
*/
CREATE INDEX IX_T_EMP2_01 ON T_EMP2(DEPT_CODE, DIV_CODE);
CREATE INDEX IX_T_DEPT2_01 ON T_DEPT2(LOC);
SELECT  /*+ GATHER_PLAN_STATISTICS USE_NL(E) INDEX(E T_EMP2_01) INDEX(D T_DEPT2_01) */
        E.EMP_NO,  E.EMP_NAME,  E.DIV_CODE,  
        D.DEPT_CODE,  D.DEPT_NAME,  D.LOC
FROM  T_EMP2  E,  T_DEPT2  D
WHERE E.DIV_CODE    = '01'
 AND  D.DEPT_CODE   = E.DEPT_CODE
 AND  D.LOC = '01';

/* 튜닝후 실행결과 
--------------------------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name          | Starts | E-Rows |E-Bytes| Cost (%CPU)| E-Time   | A-Rows |   A-Time   | Buffers | Reads  |
--------------------------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |               |      1 |        |       |    62 (100)|          |     10 |00:00:00.01 |      10 |      5 |
|   1 |  NESTED LOOPS                 |               |      1 |        |       |            |          |     10 |00:00:00.01 |      10 |      5 |
|   2 |   NESTED LOOPS                |               |      1 |      5 |   350 |    62   (0)| 00:00:01 |     10 |00:00:00.01 |       9 |      5 |
|   3 |    TABLE ACCESS BY INDEX ROWID| T_DEPT2       |      1 |      5 |   165 |     2   (0)| 00:00:01 |      5 |00:00:00.01 |       2 |      0 |
|*  4 |     INDEX RANGE SCAN          | IX_T_DEPT2_01 |      1 |      5 |       |     1   (0)| 00:00:01 |      5 |00:00:00.01 |       1 |      0 |
|*  5 |    INDEX RANGE SCAN           | IX_T_EMP2_01  |      5 |     10 |       |     1   (0)| 00:00:01 |     10 |00:00:00.01 |       7 |      5 |
|   6 |   TABLE ACCESS BY INDEX ROWID | T_EMP2        |     10 |      1 |    37 |    12   (0)| 00:00:01 |     10 |00:00:00.01 |       1 |      0 |
--------------------------------------------------------------------------------------------------------------------------------------------------
   4 - access("D"."LOC"='01')
   5 - access("D"."DEPT_CODE"="E"."DEPT_CODE" AND "E"."DIV_CODE"='01')
*/
/*
--------------------------------------------------------------------
| Id  | Operation                    | Name      |A-Rows | Buffers |
--------------------------------------------------------------------
|   0 | SELECT STATEMENT             |           |     1 |     965 |
|   1 |  NESTED LOOPS                |           |     1 |     965 |
|   2 |   NESTED LOOPS               |           |    10 |     955 |
|*  3 |    TABLE ACCESS FULL         | T_EMP     |    10 |     950 |
|*  4 |    INDEX UNIQUE SCAN         | PK_T_DEPT |    10 |       5 |
|*  5 |   TABLE ACCESS BY INDEX ROWID| T_DEPT    |     1 |      10 |
--------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   3 - filter("E"."DIV_CODE"='01')
   4 - access("D"."DEPT_CODE"="E"."DEPT_CODE")
   5 - filter("D"."LOC"='01')
*/
