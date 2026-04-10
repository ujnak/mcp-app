/**
 * Remove get_schema and run_sql from UC_AI_TOOLS.
 */
begin
    delete from uc_ai_tools where code in ('get_schema','run_sql','get_current_user','get_authenticated_identity','show_run_sql_ui');
    commit;
end;
/