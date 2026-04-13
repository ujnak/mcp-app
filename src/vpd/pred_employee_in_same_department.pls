CREATE OR REPLACE FUNCTION pred_employee_in_same_department
(
    schema_p IN VARCHAR2,
    table_p IN VARCHAR2
)
RETURN VARCHAR2
AS
    pred VARCHAR2(80);
BEGIN
    pred := q'~department_id = SYS_CONTEXT('emp_dept_ctx','department_id')~'; 
RETURN pred;
END;
/