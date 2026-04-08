set verify off
set serveroutput on
define RESOURCE_MANAGER_PLAN   = MY_PDB_PLAN
define RESOURCE_CONSUMER_GROUP = RESTRICT_RUNAWAY
-- ADMINISTER_RESOURCE_MANAGER is required to run this script.
-- To activate this plan:
-- alter system set resource_manager_plan = 'MY_PDB_PLAN';
declare
  e_object_already_exists exception;
  pragma exception_init(e_object_already_exists, -29357);
  e_plan_directive_already_exists exception;
  pragma exception_init(e_plan_directive_already_exists, -29364);
begin
  sys.dbms_resource_manager.clear_pending_area();
  sys.dbms_resource_manager.create_pending_area();

  begin    
    sys.dbms_resource_manager.create_consumer_group(
      consumer_group => '&RESOURCE_CONSUMER_GROUP'
    );
    sys.dbms_output.put_line('resource consumer group created &RESOURCE_CONSUMER_GROUP');
  exception
    when e_object_already_exists then
      sys.dbms_output.put_line(sqlerrm);
      sys.dbms_output.put_line('continue...');
  end;

  begin
    sys.dbms_resource_manager.create_plan(
      plan => '&RESOURCE_MANAGER_PLAN'
    );
    sys.dbms_output.put_line('resource manager plan created &RESOURCE_MANAGER_PLAN');
  exception
    when e_object_already_exists then
      sys.dbms_output.put_line(sqlerrm);
      sys.dbms_output.put_line('continue...');
  end;

  -- use dbms_resource_manager.update_plan_directive to change the conditions.
  begin
    sys.dbms_resource_manager.create_plan_directive(
      plan                => '&RESOURCE_MANAGER_PLAN',
      group_or_subplan    => '&RESOURCE_CONSUMER_GROUP',
      switch_group        => 'CANCEL_SQL',
      switch_for_call     => TRUE, -- cancel at call boundary (not session boundary)
      switch_elapsed_time => 20, -- Elapsed time, seconds
      switch_time         => 10  -- CPU time, seconds
    );
    sys.dbms_output.put_line('plan directives created &RESOURCE_CONSUMER_GROUP for &RESOURCE_MANAGER_PLAN');
  exception
    when e_plan_directive_already_exists then
      sys.dbms_output.put_line(sqlerrm);
      sys.dbms_output.put_line('continue...');
  end;

  begin
    sys.dbms_resource_manager.create_plan_directive(
      plan                => '&RESOURCE_MANAGER_PLAN',
      group_or_subplan    => 'OTHER_GROUPS'
      -- no restrictions: allows unlimited resource usage for all other sessions
    );
    sys.dbms_output.put_line('default plan directive created OTHER_GROUPS for &RESOURCE_MANAGER_PLAN');
  exception
    when e_plan_directive_already_exists then
      sys.dbms_output.put_line(sqlerrm);
      sys.dbms_output.put_line('continue...');
  end;

  -- Note: already-exists errors are intentionally suppressed to allow
  -- idempotent re-execution. validate_pending_area() will catch any
  -- inconsistencies before submit.
  sys.dbms_resource_manager.validate_pending_area();
  sys.dbms_resource_manager.submit_pending_area();
  sys.dbms_output.put_line('pending area submitted successfully.');
exception
  when others then
    sys.dbms_output.put_line(sqlerrm);
    sys.dbms_resource_manager.clear_pending_area();
    raise;
end;
/
