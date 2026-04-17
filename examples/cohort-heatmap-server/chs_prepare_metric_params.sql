set define off

-- Mirror of TypeScript paramsMap in generateCohortData()
insert into chs_metric_params (metric, base_retention, decay_rate, floor_value, noise)
values ('retention', 0.75, 0.12, 0.08, 0.04);

insert into chs_metric_params (metric, base_retention, decay_rate, floor_value, noise)
values ('revenue',   0.70, 0.10, 0.15, 0.06);

insert into chs_metric_params (metric, base_retention, decay_rate, floor_value, noise)
values ('active',    0.60, 0.18, 0.05, 0.05);

commit;

set define on
