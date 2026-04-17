-- ============================================================
-- Drop all cohort-heatmap-server objects
-- ============================================================
drop function chs_get_cohort_data_response;
drop procedure chs_generate_cohort_data;

drop table chs_cohort_cells   cascade constraints purge;
drop table chs_cohorts        cascade constraints purge;
drop table chs_periods        cascade constraints purge;
drop table chs_dataset_meta   cascade constraints purge;
drop table chs_metric_params  cascade constraints purge;
exit;
