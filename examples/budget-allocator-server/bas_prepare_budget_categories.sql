set define off

insert into bas_budget_categories (id, name, color, default_percent, trend_per_month)
values ('marketing',   'Marketing',   '#3b82f6', 25, 0.15);

insert into bas_budget_categories (id, name, color, default_percent, trend_per_month)
values ('engineering', 'Engineering', '#10b981', 35, -0.1);

insert into bas_budget_categories (id, name, color, default_percent, trend_per_month)
values ('operations',  'Operations',  '#f59e0b', 15, 0.05);

insert into bas_budget_categories (id, name, color, default_percent, trend_per_month)
values ('sales',       'Sales',       '#ef4444', 15, 0.08);

insert into bas_budget_categories (id, name, color, default_percent, trend_per_month)
values ('rd',          'R&D',         '#8b5cf6', 10, -0.18);

commit;

set define on