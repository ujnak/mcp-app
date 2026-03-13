create table daily_reports (
    report_id     number          generated always as identity primary key,
    report_date   date            not null,         -- 日報対象日
    employee_name varchar2(100)   not null,         -- 氏名
    summary       varchar2(2000)  not null,         -- 業務内容
    tomorrow_plan varchar2(2000),                   -- 明日の予定
    created_at    timestamp       default systimestamp not null
);

comment on table  daily_reports               is '日報テーブル';
comment on column daily_reports.report_id     is '日報id（主キー）';
comment on column daily_reports.report_date   is '日報対象日';
comment on column daily_reports.employee_name is '氏名';
comment on column daily_reports.summary       is '業務内容';
comment on column daily_reports.tomorrow_plan is '明日の予定';
comment on column daily_reports.created_at    is '作成日時';