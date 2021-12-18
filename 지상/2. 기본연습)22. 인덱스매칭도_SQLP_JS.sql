/*
##################################################################################################################################################################################################
2021.08.01
문22)인덱스매칭도 환경설정
##################################################################################################################################################################################################
*/

DROP TABLE SQLP_JS.T_CUST22;
CREATE TABLE SQLP_JS.T_CUST22
  (CUST_NO       VARCHAR2(7),
   CUS_NM        VARCHAR2(50),
   CUST_CD       VARCHAR2(3),
   FLAG          VARCHAR2(3),
   DIV          VARCHAR2(2),
   C1            VARCHAR2(30),
   C2            VARCHAR2(30),
   C3            VARCHAR2(30),
   C4            VARCHAR2(30),
   C5            VARCHAR2(30),
   CONSTRAINT PK_T_CUST22 PRIMARY KEY (CUST_NO)
  );

CREATE PUBLIC SYNONYM T_CUST22 FOR SQLP_JS.T_CUST22;

INSERT /*+ APPEND */ INTO T_CUST22
SELECT LPAD(TO_CHAR(ROWNUM), 7, '0')                                    CUST_NO
     , RPAD(TO_CHAR(ROUND(DBMS_RANDOM.VALUE(1, 65000))), 10, '0')       CUS_NM
     , LPAD(TO_CHAR(ROUND(DBMS_RANDOM.VALUE(1, 200))) || '0', 3, '0')   CUST_CD
     , LPAD(TO_CHAR(ROUND(DBMS_RANDOM.VALUE(1, 100))) || '0', 3, '0')   FLAG
     , LPAD(TO_CHAR(ROUND(DBMS_RANDOM.VALUE(1, 10)))  || '0', 2, '0')   DIV
     , 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                     C1
     , 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                     C2
     , 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                     C3
     , 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                     C4
     , 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                     C5
FROM DUAL
CONNECT BY LEVEL <= 200000;

COMMIT;

CREATE INDEX SQLP_JS.IX_T_CUST22_01 ON SQLP_JS.T_CUST22(CUST_CD, FLAG, DIV);

EXECUTE DBMS_STATS.GATHER_TABLE_STATS('SQLP_JS', 'T_CUST22');
/*
DROP   TABLE SQLP_JS.T_주문23;
CREATE TABLE SQLP_JS.T_주문23
  (주문번호            VARCHAR2(8),
   주문고객            VARCHAR2(7),
   주문상품코드        VARCHAR2(3),
   주문일자            VARCHAR2(8)
   );
*/

/*
##################################################################################################################################################################################################
2021.08.01
문22)인덱스매칭도 기본문제
##################################################################################################################################################################################################
*/
/*
PRIMARY KEY : CUST_NO
인덱스      : CUST_CD + FLAG + DIV

T_CUST22  200만건
  - CUST_CD   200개 종류(001 ~ 200),  코드당 건수는 약  1만건 
  - DIV       100개 종류(001 ~ 100),  코드당 건수는 약  2만건
  - FLAG      10개  종류,    코드당 건수는 약 20만건

-----------------------------------------------------------------------
| Id  | Operation                   | Name           |A-Rows| Buffers |
-----------------------------------------------------------------------
|   0 | SELECT STATEMENT            |                |   122|     296 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T_CUST22       |   122|     296 |
|*  2 |   INDEX RANGE SCAN          | IX_T_CUST22_01 |   122|     174 |
-----------------------------------------------------------------------
  
아래 SQL을 보고 튜닝 하시오(인덱스 및 SQL변경 가능)
*/

ALTER SESSION SET STATISTICS_LEVEL = ALL;

SELECT /*+ GATHER_PLAN_STATISTICS */
       *
  FROM T_CUST22 
 WHERE CUST_CD BETWEEN '150' AND '200' 
   AND DIV IN ('30', '40')
   AND FLAG = '160';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));

/*
##################################################################################################################################################################################################
2021.07.25
문22)인덱스매칭도 문제풀이
##################################################################################################################################################################################################
*/

#현재
SELECT /*+ GATHER_PLAN_STATISTICS */
       *
  FROM T_CUST22 
 WHERE CUST_CD BETWEEN '150' AND '200' 
   AND DIV IN ('30', '40')
   AND FLAG = '160';
--------------------------------------------------------------------------------------------------------
| Id  | Operation                   | Name           | Starts | E-Rows | A-Rows |   A-Time   | Buffers |
--------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |                |      1 |        |    125 |00:00:00.01 |     216 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T_CUST22       |      1 |     28 |    125 |00:00:00.01 |     216 |
|*  2 |   INDEX SKIP SCAN           | IX_T_CUST22_01 |      1 |     28 |    125 |00:00:00.01 |      91 |
--------------------------------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   2 - access("CUST_CD">='150' AND "FLAG"='160' AND "CUST_CD"<='200')
       filter(("FLAG"='160' AND INTERNAL_FUNCTION("DIV")));

#해석
INDEX : 
PK_T_CUST22    = T_CUST22(CUST_NO)
IX_T_CUST22_01 = T_CUST22(CUST_CD, FLAG, DIV)
BUFFER : 특이사항 x
ID : 2 -> 1 -> 0
ID 2) FROM T_CUST22 를 하기 위해 IX_T_CUST22_01 인덱스 사용 옵티마이즈.
      access CUST_CD  -> FLAG / filter FLAG -> DIV
ID 1) FROM T_CUST22       
ID 0) SELECT *

#풀이
-IX_T_CUST22_01 인덱스의 컬럼 3개 모두 WHERE절에 들어가 있는건 OK
-IX_T_CUST22_01 인덱스의 컬럼 접근 순서는, 1) 해당 컬럼의 데이터 수 2) 해당 컬럼의 도메인 값의 종류 가 다양한가? 예시로 성별과 식별번호 컬럼을 두개다 써야한다면 식별번호를 앞에 두는 것이 더 유리하다.
-CUST_CD, DIV, FLAG는 모두 데이터 수가 200만건으로 동일하다. 하지만, 값의 종류는 CUST_CD 200개 DIV 100개 FLAG 10개이다.
-즉, IX_T_CUST22_02(CUST_CD, DIV, FLAG)를 만들면 어떨까?

SOL)
CREATE INDEX SQLP_JS.IX_T_CUST22_02 ON SQLP_JS.T_CUST22(CUST_CD, DIV, FLAG);

SELECT /*+ GATHER_PLAN_STATISTICS 
           INDEX(A IX_T_CUST22_02)*/
       *
  FROM T_CUST22 A
 WHERE CUST_CD BETWEEN '150' AND '200' 
   AND DIV IN ('30', '40')
   AND FLAG = '160';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));

DROP INDEX SQLP_JS.IX_T_CUST22_02 ;      

#결과
-----------------------------------------------------------------------------------------------------------------
| Id  | Operation                   | Name           | Starts | E-Rows | A-Rows |   A-Time   | Buffers | Reads  |
-----------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |                |      1 |        |     50 |00:00:00.01 |     121 |     71 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T_CUST22       |      1 |     28 |     50 |00:00:00.01 |     121 |     71 |
|*  2 |   INDEX SKIP SCAN           | IX_T_CUST22_02 |      1 |     28 |     50 |00:00:00.01 |      71 |     71 |
-----------------------------------------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   2 - access("CUST_CD">='150' AND "FLAG"='160' AND "CUST_CD"<='200')
       filter(("FLAG"='160' AND INTERNAL_FUNCTION("DIV"))); #리뷰# 이놈이 문제가 될 수 있다는 점을 몰랐음.

#다른풀이
-지금 쓰이고 있는 IX_T_CUST22_02의 Operation이 INDEX SKIP SCAN이다.
-INDEX SKIP SCAN은 인덱스 선행 컬럼 순으로 INDEX RANGE SCAN이 안되고, 인덱스 후행 컬럼으로 바로 넘어가는 경우이다.
-이런 경우는 인덱스 선행 컬럼이 가공되거나, 인덱스 선행 컬럼의 위치를 찾을 수 없는 경우이다.
-기존 풀이는 인덱스 컬럼 접근 순서를 고려했으나, WHERE절에서 각 컬럼의 접근 조건을 고려하지 않았다. (CUST_CD로 INDEX RANGE SCAN하면서 찾아지길 바랬으나, 시작점이 너무 다양함으로 자동적으로 INDEX SKIP SCAN으로 DIV와 FLAG의 시작점을 옵티마이즈 해서 찾음)
-즉, IX_T_CUST22_02(FLAG, DIV, CUST_CD)를 만들면 어떨까? : 시작점이 작은 순서...는 좋긴한데.. 데이터 값의 종류로 생각하면 오히려 안좋음. -> Q) 기존풀이 처럼 인덱스를 추가하고, CUST_CD의 범위를 길게 가져가는 경우 FULL_SCAN은?

SOL2)
CREATE INDEX SQLP_JS.IX_T_CUST22_03 ON SQLP_JS.T_CUST22(FLAG, DIV, CUST_CD);

SELECT /*+ GATHER_PLAN_STATISTICS 
           INDEX(A IX_T_CUST22_03)*/
       *
  FROM T_CUST22 A
 WHERE CUST_CD BETWEEN '150' AND '200' 
   AND DIV IN ('30', '40')
   AND FLAG = '160';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));

DROP INDEX SQLP_JS.IX_T_CUST22_03 ;  

#결과
------------------------------------------------------------------------------------------------------------------
| Id  | Operation                    | Name           | Starts | E-Rows | A-Rows |   A-Time   | Buffers | Reads  |
------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                |      1 |        |     50 |00:00:00.01 |      53 |      2 |
|   1 |  INLIST ITERATOR             |                |      1 |        |     50 |00:00:00.01 |      53 |      2 |
|   2 |   TABLE ACCESS BY INDEX ROWID| T_CUST22       |      1 |     28 |     50 |00:00:00.01 |      53 |      2 |
|*  3 |    INDEX RANGE SCAN          | IX_T_CUST22_03 |      1 |     28 |     50 |00:00:00.01 |       3 |      2 |
------------------------------------------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   3 - access("FLAG"='160' AND (("DIV"='30' OR "DIV"='40')) AND "CUST_CD">='150' AND "CUST_CD"<='200');

SOL3)
CREATE INDEX SQLP_JS.IX_T_CUST22_04 ON SQLP_JS.T_CUST22(DIV, FLAG, CUST_CD);

SELECT /*+ GATHER_PLAN_STATISTICS 
           INDEX(A IX_T_CUST22_04)*/
       *
  FROM T_CUST22 A
 WHERE CUST_CD BETWEEN '150' AND '200' 
   AND DIV IN ('30', '40')
   AND FLAG = '160';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));

DROP INDEX SQLP_JS.IX_T_CUST22_04 ;  

#결과
------------------------------------------------------------------------------------------------------------------
| Id  | Operation                    | Name           | Starts | E-Rows | A-Rows |   A-Time   | Buffers | Reads  |
------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                |      1 |        |     50 |00:00:00.01 |      53 |      2 |
|   1 |  INLIST ITERATOR             |                |      1 |        |     50 |00:00:00.01 |      53 |      2 |
|   2 |   TABLE ACCESS BY INDEX ROWID| T_CUST22       |      1 |     28 |     50 |00:00:00.01 |      53 |      2 |
|*  3 |    INDEX RANGE SCAN          | IX_T_CUST22_04 |      1 |     28 |     50 |00:00:00.01 |       3 |      2 |
------------------------------------------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   3 - access((("DIV"='30' OR "DIV"='40')) AND "FLAG"='160' AND "CUST_CD">='150' AND "CUST_CD"<='200');