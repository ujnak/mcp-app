begin
  dbms_resource_manager.create_pending_area();
  /* Create consumer group RESTRICT_RUNAWAY. */
  dbms_resource_manager.create_consumer_group(consumer_group => 'RESTRICT_RUNAWAY');
  /* Create resource manager plan MCP_PLAN. */
  dbms_resource_manager.create_plan(plan => 'MCP_PLAN');
  /*
   * Create plan directive.
   * Set elapsed time limit to 20 seconds and CPU time limit to 10 seconds.
   */
  dbms_resource_manager.create_plan_directive(
    plan                => 'MCP_PLAN',
    group_or_subplan    => 'RESTRICT_RUNAWAY',
    switch_group        => 'CANCEL_SQL',
    switch_for_call     => TRUE,
    switch_elapsed_time => 6, -- elapsed time
    switch_time         => 3  -- CPU time
  );
  /* Create default plan directive. */
  dbms_resource_manager.create_plan_directive(
    plan                => 'MCP_PLAN',
    group_or_subplan    => 'OTHER_GROUPS');
  /* End of operation */
  dbms_resource_manager.validate_pending_area();
  dbms_resource_manager.submit_pending_area();
end;
/

/*
 * Map the created consumer group to user WKSP_APEXDEV.
 */
begin
  dbms_resource_manager.create_pending_area();
  /* Apply consumer group to user MCPUSER. */
  dbms_resource_manager.set_consumer_group_mapping(
    attribute      => DBMS_RESOURCE_MANAGER.ORACLE_USER,
    value          => 'WKSP_APEXDEV',
    consumer_group => 'RESTRICT_RUNAWAY');
  /* End of operation */
  dbms_resource_manager.validate_pending_area();
  dbms_resource_manager.submit_pending_area();
end;
/

/*
 * Update plan directive.
 */
begin
    dbms_resource_manager.create_pending_area();
        dbms_resource_manager.update_plan_directive(
            plan                => 'MCP_PLAN',
            group_or_subplan    => 'RESTRICT_RUNAWAY',
            new_switch_elapsed_time => 6,
            new_switch_time         => 3
        );
    dbms_resource_manager.validate_pending_area();
    dbms_resource_manager.submit_pending_area();
end;
/

/*
 * check initial resource consumer group
 */
select username, initial_rsrc_consumer_group from dba_users
where username = 'WKSP_APEXDEV';

/*
 * Change initial consumer group.
 */
begin
    dbms_resource_manager.set_initial_consumer_group(
        user         => 'WKSP_APEXDEV',
        consumer_group => 'DEFAULT_CONSUMER_GROUP'
    );
end;
/
