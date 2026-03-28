create table auth_users(
    employee_id number not null,
    department_id number not null,
    email varchar2(25),
    authenticated_identity varchar2(128) not null
);
