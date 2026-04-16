declare
    l_config_id bas_budget_config.id%type;
begin
    insert into bas_budget_config(default_budget, currency, currency_symbol) values(100000,'USD','$') returning id into l_config_id;
    insert into bas_budget_config_preset_budgets(config_id, sort_order, preset_value) values(l_config_id, 0, 50000);
    insert into bas_budget_config_preset_budgets(config_id, sort_order, preset_value) values(l_config_id, 0, 100000);
    insert into bas_budget_config_preset_budgets(config_id, sort_order, preset_value) values(l_config_id, 0, 250000);
    insert into bas_budget_config_preset_budgets(config_id, sort_order, preset_value) values(l_config_id, 0, 500000);
    commit;
end;
/
