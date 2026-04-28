declare 
  reginfo1     sys.aq$_reg_info; 
  reginfolist  sys.aq$_reg_info_list; 
begin 
   -- AQの通知として呼び出されるプロシージャexec_jobの定義。
  reginfo1 := sys.aq$_reg_info('APEXDEV.OJ_MCP_TOOLS_IN_Q:APEXDEV', 
                     DBMS_AQ.NAMESPACE_AQ, 'plsql://apexdev.tools_call_async', 
                     HEXTORAW('FF'));
  -- 通知として登録する。
  reginfolist := sys.aq$_reg_info_list(reginfo1); 
  sys.dbms_aq.unregister(reginfolist, 1); 
end;
/