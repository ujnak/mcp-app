create or replace FUNCTION UPDATE_DAILY_REPORT (
    p_parameters in clob
) return clob
is
    pragma autonomous_transaction;

    l_employee_name  daily_reports.employee_name%type;
    l_report_date    daily_reports.report_date%type;
    l_summary        daily_reports.summary%type;
    l_tomorrow_plan  daily_reports.tomorrow_plan%type;
    l_report_id      daily_reports.report_id%type;
    l_action         varchar2(10);
    l_result         clob;
begin
    l_employee_name := json_value(p_parameters, '$.employeeName');
    l_report_date   := to_date(json_value(p_parameters, '$.reportDate'), 'YYYY-MM-DD');
    l_summary       := json_value(p_parameters, '$.summary');
    l_tomorrow_plan := json_value(p_parameters, '$.tomorrowPlan');

    if l_employee_name is null then
        l_employee_name := sys_context('USERENV', 'SESSION_USER');
    end if;

    begin
        select report_id
          into l_report_id
          from daily_reports
         where report_date   = l_report_date
           and employee_name = l_employee_name;

        update daily_reports
           set summary       = nvl(l_summary,       summary),
               tomorrow_plan = nvl(l_tomorrow_plan, tomorrow_plan)
         where report_id = l_report_id;

        l_action := 'updated';

    exception
        when no_data_found then
            insert into daily_reports (
                report_date, employee_name, summary, tomorrow_plan, created_at
            ) values (
                l_report_date, l_employee_name, l_summary, l_tomorrow_plan, systimestamp
            )
            returning report_id into l_report_id;

            l_action := 'created';
    end;

    commit;

    -- success / action / reportId を含むレスポンスを返す
    select to_clob(json_object(
               'success'      value 'true'   format json,
               'action'       value l_action,
               'reportId'     value l_report_id,
               'employeeName' value employee_name,
               'reportDate'   value to_char(report_date, 'YYYY-MM-DD'),
               'summary'      value summary,
               'tomorrowPlan' value tomorrow_plan
           ))
      into l_result
      from daily_reports
     where report_id = l_report_id;

    return l_result;

exception
    when others then
        rollback;
        return json_object(
            'success' value 'false' format json,
            'message' value sqlerrm
        );
end UPDATE_DAILY_REPORT;
/