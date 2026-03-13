create or replace function view_daily_report(
    p_parameters in clob
) return clob
is
    -- Input parameters
    l_reporter_name varchar2(100);
    l_report_date   date;

    -- Query results
    l_employee_name varchar2(100);
    l_summary       varchar2(2000);
    l_tomorrow_plan varchar2(2000);

    -- JSON objects
    l_input_json  json_object_t;
    l_output_json json_object_t;

begin
    -- Parse input JSON
    l_input_json := json_object_t.parse(p_parameters);

    -- Get reportDate (required)
    if l_input_json.has('reportDate') then
        l_report_date := to_date(l_input_json.get_string('reportDate'), 'YYYY-MM-DD');
    else
        raise_application_error(-20001, 'reportDate is required.');
    end if;

    -- Get employeeName (optional)
    if l_input_json.has('employeeName') and not l_input_json.get('employeeName').is_null() then
        l_reporter_name := l_input_json.get_string('employeeName');
    end if;

    -- Search DAILY_REPORTS
    -- Filter by date, and by employee name if specified
    select
        employee_name,
        summary,
        tomorrow_plan
    into
        l_employee_name,
        l_summary,
        l_tomorrow_plan
    from
        daily_reports
    where
        trunc(report_date) = trunc(l_report_date)
        and (l_reporter_name is null or employee_name = l_reporter_name)
    fetch first 1 row only;

    -- Build output JSON
    l_output_json := json_object_t();
    l_output_json.put('employeeName',  l_employee_name);
    l_output_json.put('reportDate',    to_char(l_report_date, 'YYYY-MM-DD'));
    l_output_json.put('summary',       l_summary);
    if l_tomorrow_plan is not null then
        l_output_json.put('tomorrowPlan', l_tomorrow_plan);
    else
        l_output_json.put_null('tomorrowPlan');
    end if;

    return l_output_json.to_clob();

exception
    when no_data_found then
        -- No matching record found
        l_output_json := json_object_t();
        l_output_json.put('error', 'No daily report found for the specified date/employee.');
        l_output_json.put('reportDate', to_char(l_report_date, 'YYYY-MM-DD'));
        if l_reporter_name is not null then
            l_output_json.put('employeeName', l_reporter_name);
        end if;
        return l_output_json.to_clob();

    when others then
        -- Unexpected error
        l_output_json := json_object_t();
        l_output_json.put('error', sqlerrm);
        return l_output_json.to_clob();
end view_daily_report;
/