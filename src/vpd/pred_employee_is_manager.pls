CREATE OR REPLACE FUNCTION pred_employee_is_manager
(
    schema_p IN VARCHAR2,
    table_p IN VARCHAR2
)
RETURN VARCHAR2
AS
    pred VARCHAR2(80);
BEGIN
    pred := q'~manager_id = SYS_CONTEXT('emp_dept_ctx', 'employee_id')~'; 
RETURN pred;
END;
/
