/*
##################################################################################################################################################################################################
2021.07.25
문21)사원_부서 환경설정
##################################################################################################################################################################################################
*/
drop table SQLP_JS.t_emp;
create table SQLP_JS.t_emp 
  (emp_no      varchar2(5),
   emp_name    varchar2(50),
   dept_code   varchar2(2),
   div_code    varchar2(2)       
   );

create public synonym t_emp for SQLP_JS.t_emp;

alter table SQLP_JS.t_emp
add constraint pk_t_emp primary key(emp_no)
using index;

insert /*+ append */ into t_emp
select  lpad(trim(to_char(rownum)), 5, '0') emp_no
      , '12345678901234567890123456789012345678901234567890' emp_name
      , lpad(to_char(round(dbms_random.value(1, 99))), 2, '0') dept_code
      , lpad(to_char(round(dbms_random.value(2, 99))), 2, '0') div_code
from dual connect by level <= 99999;

COMMIT;

UPDATE T_EMP
SET DIV_CODE = '01'
WHERE EMP_NO <= '00010';

SELECT * FROM T_EMP WHERE EMP_NO <= '00010';  
SELECT * FROM T_EMP WHERE DIV_CODE = '01';

commit;

drop table SQLP_JS.t_dept;

create table SQLP_JS.t_dept
 (
  dept_code   varchar2(2),
  dept_name   varchar2(50),
  loc         varchar2(2)
);

create public synonym t_dept for SQLP_JS.t_dept;

alter table SQLP_JS.t_dept
add constraint pk_t_dept primary key(dept_code)
using index;

insert /*+ append */ into t_dept
select lpad(trim(to_char(rownum)), 2, '0') dept_code
     , lpad(trim(to_char(rownum)), 2, '0') dept_name
     , lpad(to_char(round(dbms_random.value(1, 10))), 2, '0') loc
from dual connect by level <= 99;

commit;

SELECT * FROM T_DEPT;

EXECUTE DBMS_STATS.GATHER_TABLE_STATS('SQLP_JS', 'T_EMP');
EXECUTE DBMS_STATS.GATHER_TABLE_STATS('SQLP_JS', 'T_DEPT');
/*
##################################################################################################################################################################################################
2021.07.25
문21)사원_부서 기본문제
##################################################################################################################################################################################################
*/
/*  테이블 
       - 사원 (약10만건), 부서(100건)

    INDEX 
       - 사원PK : EMP_NO   
       - 부서PK : DEPT_CODE

아래 SQL을 튜닝 하세요.

  문제 1) E.DIV_CODE='01'의 결과 : 10건,   D.LOC='01'의 결과 30건
  문제 2) E.DIV_CODE='01'의 결과 : 100건,   D.LOC='01'의 결과 3건


*/
SELECT E.*
  FROM T_EMP E
 WHERE E.DIV_CODE = '01';

SELECT D.*
  FROM T_DEPT D
 WHERE D.LOC = '01';

UPDATE T_DEPT D
   SET D.LOC = '01'
 WHERE D.DEPT_CODE = '11';
 
COMMIT;

SELECT  /*+ GATHER_PLAN_STATISTICS 
            ORDERED USE_NL(D) */
        E.EMP_NO,  E.EMP_NAME,  E.DIV_CODE,  
        D.DEPT_CODE,  D.DEPT_NAME,  D.LOC
FROM  T_EMP  E,  T_DEPT  D
WHERE D.DEPT_CODE   = E.DEPT_CODE;
 AND  E.DIV_CODE    = '01' 
 AND  D.LOC         = '01';

select * from table(dbms_xplan.display_cursor(null,null, 'allstats last'));

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

/*
##################################################################################################################################################################################################
2021.07.25
문21)사원_부서 문제풀이
##################################################################################################################################################################################################
*/

#현재
SELECT  /*+ GATHER_PLAN_STATISTICS 
            ORDERED USE_NL(D) */
        E.EMP_NO,  E.EMP_NAME,  E.DIV_CODE,  
        D.DEPT_CODE,  D.DEPT_NAME,  D.LOC
FROM  T_EMP  E,  T_DEPT  D
WHERE D.DEPT_CODE   = E.DEPT_CODE
 AND  E.DIV_CODE    = '01' 
 AND  D.LOC         = '01';

#해석
INDEX : E.EMP_NO , D.DEPT_CODE
ORDER : 드라이빙 E, 이너 D

FROM E : 필요한 E만 가져오고 싶음.
- E의 DIV_CODE 이용? -> E.DIV_CODE = '01' 가져올 수 있나? -> 해당 INDEX 없음. 불가.
- E의 EMP_NO 이용? -> WHERE절에서 사용 안됨 -> FULL_CSAN 과 동일
- D의 PK_T_DEPT(DEPT_CODE) 이용? -> JOIN조건 E.DEPT_CODE = D.DEPT_CODE 임으로 (O)
WHERE E : E를 가져오면서 FILTER
- E.DIV_CODE = '01'
문제점 분석 :
- 더블 인덱스 효과 -> 필요에 따라 효과적, 인덱스를 새로 추가할 수 없을시 괜찮음. (파티션을 나누는 효과?)
- PK_T_DEPT(DEPT_CODE)를 드라이빙으로 두고, T_EMP를 NL로 찾기에 효율적이지 못함(TALBE ACCESS FULL) -> INDEX로 T_EMP(E.DEPT_CODE)를 두는 것을 추천 #틀림#드라이빙 위치 반대임ㅋㅋ#
- 애초에 T_EMP(E.DIV_CODE) INDEX를 가지고 있었다면?

FROM D : 필요한 D만 가져오고 싶음.
- D의 LOC 이용? -> D.LOC = '01' 가져올 수 있나? -> 해당 INDEX 없음. 불가.
- D의 DEPT_CODE이용? -> WHERE절에서 사용함 JOIN 조건 E.DEPT_CODE = D.DEPT_CODE, 스칼라 조건은 없음. -> FULL_SCAN과 동일 -> TABLE ACCESS BY INDEX ROWID #
WHERE D : D를 가져오면서 FILTER
- D.LOC = '01'
문제점 분석 :
- 애초에 T_DEPT(D.LOC) INDEX를 가지고 있었다면?


#풀이
문제 1) E.DIV_CODE='01'의 결과 : 10건,   D.LOC='01'의 결과 30건
- E의 결과가 더 적으므로 드라이빙 테이블 순서 유지
- FROM E의 결과가 필터를 제외하고 더 적게 나올 수 있도록, INDEX로 T_EMP(E.DEPT_CODE)를 추가.
- FROM D의 결과가 필터를 제외하고 더 적게 나올 수 있도록, INDEX로 T_DEPT(D.LOC)를 추가. + 이너 테이블임으로 JOIN을 위한 INDEX KEY로 D.DEPT_CODE 추가

SOL);
CREATE INDEX SQLP_JS.IX_T_EMP_01 ON SQLP_JS.T_EMP(DEPT_CODE);
CREATE INDEX SQLP_JS.IX_T_DEPT_01 ON SQLP_JS.T_DEPT(DEPT_CODE, LOC);

SELECT  /*+ GATHER_PLAN_STATISTICS 
            ORDERED USE_NL(D) INDEX(E IX_T_EMP_01) INDEX(D IX_T_DEPT_01)*/
        E.EMP_NO,  E.EMP_NAME,  E.DIV_CODE,  
        D.DEPT_CODE,  D.DEPT_NAME,  D.LOC
FROM  T_EMP  E,  T_DEPT  D
WHERE D.DEPT_CODE   = E.DEPT_CODE
 AND  E.DIV_CODE    = '01' 
 AND  D.LOC         = '01';

select * from table(dbms_xplan.display_cursor(null,null, 'allstats last'));

DROP INDEX SQLP_JS.IX_T_EMP_01 ;
DROP INDEX SQLP_JS.IX_T_DEPT_01 ;

문제 2) E.DIV_CODE='01'의 결과 : 100건,   D.LOC='01'의 결과 3건
- D의 결과가 더 적으므로 드라이빙 순서 변경 -> D E
- FROM D의 결과가 필터를 제외하고 더 적게 나올 수 있도록, INDEX로 T_DEPT(D.LOC)를 추가.
- FROM E의 결과가 필터를 제외하고 더 적게 나올 수 있도록, INDEX로 T_EMP(E.DIV_CODE)를 추가. + 이너 테이블임으로 JOIN을 위한 INDEX KEY로 E.DEPT_CODE 추가

SOL);
CREATE INDEX SQLP_JS.IX_T_DEPT_02 ON SQLP_JS.T_DEPT(LOC);
CREATE INDEX SQLP_JS.IX_T_EMP_02 ON SQLP_JS.T_EMP(DEPT_CODE, DIV_CODE);

SELECT  /*+ GATHER_PLAN_STATISTICS 
            LEADING(D E) USE_NL(E) INDEX(E IX_T_EMP_02) INDEX(D IX_T_DEPT_02)*/
        E.EMP_NO,  E.EMP_NAME,  E.DIV_CODE,  
        D.DEPT_CODE,  D.DEPT_NAME,  D.LOC
FROM  T_EMP  E,  T_DEPT  D
WHERE D.DEPT_CODE   = E.DEPT_CODE
 AND  E.DIV_CODE    = '01' 
 AND  D.LOC         = '01';

select * from table(dbms_xplan.display_cursor(null,null, 'allstats last'));

DROP INDEX SQLP_JS.IX_T_EMP_02 ;
DROP INDEX SQLP_JS.IX_T_DEPT_02 ;


# 질문?
1)
   AND  E.DIV_CODE    = '01' 
   AND  D.LOC         = '01';
   위 조건을 빼고 실행 시켰을 때 왜 BUFFER가 줄지?
2)
  문제1번의 풀이 왜...? 안좋을까..?

*/
