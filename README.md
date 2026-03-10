# Experimental implementation of MCP App on top of Oracle Database and ORDS.

Mandatory components;
- Oracle Database, 19c or 26ai.
- Oracle REST Data Services
- Oracle APEX
- United Codes, UC_AI https://github.com/United-Codes/uc_ai

## Install

install-tables.sql
    Create table OJ_MCP_APP_RESOURCES and OJ_MCP_TOOLS_EXTRAS
    Create view OJ_MCP_UC_AI_TOOLS

install-packages.sql
    OJ_MCP_APP_SERVER, OJ_MCP_APP_UTILS, OJ_MCP_JSONRPC_UTILS

install-sampleserver.sql
    ORDS REST module sampleserver
    PL/SQL Functions, get_scheme, run_sql and get_current_user
    UC_AI tool definitiions for the PL/SQL functions.
    define UI resources for tool get_current_user

## Requirements to run sampleserver

1. The APEX workspace name must match the ORDS alias.

The APEX workspace name and the ORDS alias will typically match.

2. The URI prefix must be the module name enclosed in "/".

ORDS REST module "sampleserver" will be created. The URL prefix is "/sampleserver/".

3. An APEX application whose alias matches the ORDS module name must exist.

The APEX application alias “sampleserver” must be created in order to run this sample application.
