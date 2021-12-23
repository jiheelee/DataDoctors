/*
##################################################################################################################################################################################################
2021.08.01
문23)고객주문 환경설정
##################################################################################################################################################################################################
*/
DROP   TABLE SQLP_JS.T_고객23;
CREATE TABLE SQLP_JS.T_고객23
  (고객번호      VARCHAR2(7),
   고객명        VARCHAR2(50),
   고객성향코드  VARCHAR2(3),
   C1            VARCHAR2(30),
   C2            VARCHAR2(30),
   C3            VARCHAR2(30),
   C4            VARCHAR2(30),
   C5            VARCHAR2(30),
   CONSTRAINT PK_T_고객23 PRIMARY KEY (고객번호)
  );

CREATE PUBLIC SYNONYM T_고객23 FOR SQLP_JS.T_고객23;

INSERT /*+ APPEND */ INTO T_고객23
SELECT LPAD(TO_CHAR(ROWNUM), 7, '0')                                    고객번호
     , RPAD(TO_CHAR(ROUND(DBMS_RANDOM.VALUE(1, 65000))), 10, '0')       고객명
     , LPAD(TO_CHAR(ROUND(DBMS_RANDOM.VALUE(1, 200))) || '0', 3, '0')   고객성향코드
     , 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                     C1
     , 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                     C2
     , 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                     C3
     , 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                     C4
     , 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                                     C5
FROM DUAL
CONNECT BY LEVEL <= 20000;

COMMIT;

DROP   TABLE SQLP_JS.T_DATE23;
CREATE TABLE SQLP_JS.T_DATE23 AS
SELECT TO_CHAR(TO_DATE('20170101', 'YYYYMMDD') + LEVEL, 'YYYYMMDD') WORK_DATE
FROM DUAL
CONNECT BY LEVEL <= 100;

CREATE PUBLIC SYNONYM T_DATE23 FOR SQLP_JS.T_DATE23;

DROP TABLE  SQLP_JS.T_주문23 ;
CREATE TABLE SQLP_JS.T_주문23 AS
SELECT  'O' || LPAD(TO_CHAR(ROWNUM), 7, '0')                                    주문번호
      ,  C.고객번호
      , 'P' || LPAD(TO_CHAR(ROUND(DBMS_RANDOM.VALUE(1, 200))) || '0', 3, '0')   상품코드
      ,  D.WORK_DATE                                                            주문일자
      , ROUND(DBMS_RANDOM.VALUE(1, 3))                                          주문수량        
FROM T_고객23 C, T_DATE23 D
;

CREATE PUBLIC SYNONYM T_주문23 FOR SQLP_JS.T_주문23;

ALTER TABLE SQLP_JS.T_주문23 
ADD CONSTRAINT PK_T_주문23 PRIMARY KEY(주문번호)
;

EXECUTE DBMS_STATS.GATHER_TABLE_STATS('SQLP_JS', 'T_고객23');
EXECUTE DBMS_STATS.GATHER_TABLE_STATS('SQLP_JS', 'T_주문23');
/*
##################################################################################################################################################################################################
2021.08.01
문23)고객주문 기본문제
##################################################################################################################################################################################################
*/
/* 아래 SQL을 OLTP에 최적화 하여 튜닝 하세요.  (인덱스 및 SQL 수정 가능)
   최종 결과 값 : 18건
   
   T_고객23 
      - 총건수               : 2만건
      - 고객성향코드 = '920' : 101건
      - 고객성향코드 종류    : 200종류      
      - 인덱스 : PK_T_고객23 (고객번호)

   T_주문23
      - 총 건수: 200만건
      - 아래 조건의 결과 : 10,000건
        O.주문일자 LIKE '201701%' AND O.상품코드 = 'P103'   
      - 인덱스 : PK_T_주문23 (주문번호)   
*/

SELECT /*+ GATHER_PLAN_STATISTICS */
       C.고객번호, C.고객명, C.C1,
       O.주문번호, O.상품코드, O.주문일자, O.주문수량
  FROM T_고객23 C, T_주문23 O
 WHERE C.고객성향코드 = '920'
   AND  O.고객번호     = C.고객번호
   AND  O.주문일자     LIKE '201701%'
   AND  O.상품코드     = 'P103';

desc t_고객23; Q)...?

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));
/*
PLAN_TABLE_OUTPUT
------------------------------------------------------------
| Id  | Operation          | Name   |A-Rows | Buffers | Reads 
-------------------------------------------------------------
|   0 | SELECT STATEMENT   |        |    18 |   11363 |  10793 
|*  1 |  HASH JOIN         |        |    18 |   11363 |  10793 
|*  2 |   TABLE ACCESS FULL| T_고객2|   108 |     461 |      0
|*  3 |   TABLE ACCESS FULL| T_주문2|  3070 |   10902 |  10793 
--------------------------------------------------------------
 */
 
 /*
##################################################################################################################################################################################################
2021.08.01
문23)인덱스매칭도 문제풀이
##################################################################################################################################################################################################
*/
#현재
SELECT /*+ GATHER_PLAN_STATISTICS */
       C.고객번호, C.고객명, C.C1,
       O.주문번호, O.상품코드, O.주문일자, O.주문수량
  FROM T_고객23 C, T_주문23 O
 WHERE O.고객번호     = C.고객번호
   AND O.주문일자     LIKE '201701%'
   AND O.상품코드     = 'P103';
   AND C.고객성향코드 = '920'
---------------------------------------------------------------------------------------------------------------------------
| Id  | Operation          | Name   | Starts | E-Rows | A-Rows |   A-Time   | Buffers | Reads  |  OMem |  1Mem | Used-Mem |
---------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |        |      1 |        |     15 |00:00:00.03 |   11279 |  10754 |       |       |          |
|*  1 |  HASH JOIN         |        |      1 |    114 |     15 |00:00:00.03 |   11279 |  10754 |   851K|   851K| 1289K (0)|
|*  2 |   TABLE ACCESS FULL| T_고객2|      1 |    106 |     79 |00:00:00.01 |     458 |      0 |       |       |          |
|*  3 |   TABLE ACCESS FULL| T_주문2|      1 |   3015 |   3096 |00:00:00.13 |   10821 |  10754 |       |       |          |
---------------------------------------------------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   1 - access("O"."고객번호"="C"."고객번호")
   2 - filter("C"."고객성향코드"='920')
   3 - filter(("O"."상품코드"='P103' AND "O"."주문일자" LIKE '201701%'));

#해석
INDEX : 
PK_T_고객23 = T_고객23(고객번호)
PK_T_주문23 = T_주문23(주문번호)
BUFFER : ID 3)의 FROM T_주문2에서 BUFFER 사이즈가 너무 큼. (블락을 많이 읽어옴) 즉, TABLAE ACCESS FULL의 과정에서 INDEX를 사용하지 못하고 있음.
ID : 2 -> 3 -> 1 -> 0
ID 2) FROM T_고객23 TABLE ACCESS FULL, filter 고객성향코드
ID 3) FROM T_주문23 TABLE ACCESS FULL, filter 상품코드, 주문일자, BUFFER 문제        
ID 1) HASH JOIN이기 때문에, 드라이빙 테이블이 작으면 좋고(TO make hash map), 굳이 이너 테이블에 join 키가 없어도 됨.
ID 0) SELECT

#풀이
-SQL과 인덱스를 모두 수정해보자?
-T_주문23에 접근하는 방법으로 USE_NL을 이용해본다면? 왜냐면 고객23과 JOIN하고 이 때 고객번호가 T_고객23의 PK니까? -> X -> 이러면 조인 과정에서 아우터가 T_주문23으로 잡히는데 테이블 사이즈가 너무 크다.
-SQLP_JS.IX_T_고객23_01(C.고객성향코드) 만들고, SQLP_JS.IX_T_주문23_01(O.상품코드, O.주문일자) 만들고 LEADING(C O) USE_HASH(O) 하면 어떨까?

#SOL)
CREATE INDEX SQLP_JS.IX_T_고객23_01 ON SQLP_JS.T_고객23(고객성향코드);
CREATE INDEX SQLP_JS.IX_T_주문23_01 ON SQLP_JS.T_주문23(상품코드, 주문일자);

SELECT /*+ GATHER_PLAN_STATISTICS 
        LEADING(C O) USE_HASH(O C)INDEX(C IX_T_고객23_01) INDEX(D IX_T_주문23_01)*/
       C.고객번호, C.고객명, C.C1,
       O.주문번호, O.상품코드, O.주문일자, O.주문수량
  FROM T_고객23 C, T_주문23 O
 WHERE C.고객성향코드 = '920'
   AND  O.고객번호     = C.고객번호
   AND  O.주문일자     LIKE '201701%'
   AND  O.상품코드     = 'P103';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));

DROP INDEX SQLP_JS.IX_T_고객23_01 ;  
DROP INDEX SQLP_JS.IX_T_주문23_01 ;  

#결과
-------------------------------------------------------------------------------------------------------------------------------------------
| Id  | Operation                    | Name         | Starts | E-Rows | A-Rows |   A-Time   | Buffers | Reads  |  OMem |  1Mem | Used-Mem |
-------------------------------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |              |      1 |        |     15 |00:00:00.01 |    2106 |      1 |       |       |          |
|*  1 |  HASH JOIN                   |              |      1 |    114 |     15 |00:00:00.01 |    2106 |      1 |   851K|   851K| 1267K (0)|
|   2 |   TABLE ACCESS BY INDEX ROWID| T_고객23     |      1 |    106 |     79 |00:00:00.01 |      76 |      0 |       |       |          |
|*  3 |    INDEX RANGE SCAN          | IX_T_고객23_0|      1 |    106 |     79 |00:00:00.01 |       2 |      0 |       |       |          |
|   4 |   TABLE ACCESS BY INDEX ROWID| T_주문23     |      1 |   3015 |   3096 |00:00:00.01 |    2030 |      1 |       |       |          |
|*  5 |    INDEX RANGE SCAN          | IX_T_주문23_0|      1 |   3015 |   3096 |00:00:00.01 |      14 |      0 |       |       |          |
-------------------------------------------------------------------------------------------------------------------------------------------
 
Predicate Information (identified by operation id):
---------------------------------------------------
 
   1 - access("O"."고객번호"="C"."고객번호")
   3 - access("C"."고객성향코드"='920')
   5 - access("O"."상품코드"='P103' AND "O"."주문일자" LIKE '201701%')
       filter("O"."주문일자" LIKE '201701%')

#다른풀이
- 두개의 테이블 수가 확연히 차이나고, T_고객23의 사이즈가 2만건으로 확연히 작으니까 USE_NL을 쓰면 안될까?
- 이 경우, 인덱스로 T_고객23(고객성향코드)와 T_주문23(고객번호, 상품코드, 주문일자) 가 필요하다. -> 이너 테이블에 고객번호가 인덱스로 들어가야 함으로.. 

#SOL2)
CREATE INDEX SQLP_JS.IX_T_고객23_01 ON SQLP_JS.T_고객23(고객성향코드);
CREATE INDEX SQLP_JS.IX_T_주문23_02 ON SQLP_JS.T_주문23(고객번호, 상품코드, 주문일자);

SELECT /*+ GATHER_PLAN_STATISTICS 
        LEADING(C O) USE_NL(O)INDEX(C IX_T_고객23_01) INDEX(D IX_T_주문23_02)*/
       C.고객번호, C.고객명, C.C1,
       O.주문번호, O.상품코드, O.주문일자, O.주문수량
  FROM T_고객23 C, T_주문23 O
 WHERE C.고객성향코드 = '920'
   AND  O.고객번호     = C.고객번호
   AND  O.주문일자     LIKE '201701%'
   AND  O.상품코드     = 'P103';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));

DROP INDEX SQLP_JS.IX_T_고객23_01 ;  
DROP INDEX SQLP_JS.IX_T_주문23_02 ; 