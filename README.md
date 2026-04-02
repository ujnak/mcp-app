# MCP App Experimental Implementation on Oracle Database and ORDS

## Overview

This repository provides an experimental implementation of an MCP App running on top of Oracle Database and Oracle REST Data Services (ORDS).

This implementation is intended for experimentation and reference purposes.

## Mandatory components

- Oracle Database (19c or 26ai)
- Oracle REST Data Services (ORDS)
- Oracle APEX
- [United Codes UC_AI](https://github.com/United-Codes/uc_ai)

## Repository Structure

- src

    tables, views, packages, and sample definitions
- ords

    ORDS REST module export
- nginx

    configuration files for nginx to support OpenID Connect

## Verification Status

| Client          | Version                 | OS                 | Worked?  | Auth |
|-----------------|-------------------------|--------------------|----------|------|
| MCP Inspector   | v0.21.1                 | macOS Tahoe 26.3.1 | Yes      | Yes  |
| ChatGPT Desktop | 1.2026.048 (1771630681) | macOS Tahoe 26.3.1 | Yes      | Yes  |
| ChatGPT App     | 1.2026.062              | iOS 26.3.1         | Yes      | Yes  |
| ChatGPT App     | 1.2026.062              | iPadOS 26.3.1      | Yes      | Yes  |
| chatgpt.com     |                         |                    | Yes      | Yes  |     
| Claude Desktop  | 1.1.6041 (62e193)       | macOS Tahoe 26.3.1 | Yes      | Yes  |
| Claude App      | 1.260309.1              | iPadOS 26.3.1      | No       |      | 
| Claude App      | 1.260309.1              | iOS 26.3.1         | No       |      |
| claude.ai       |                         |                    | No       |      |
| Goose           | 1.27.2 (1.27.2)         | macOS Tahoe 26.3.1 | Yes      | N/A  |

- Microsoft Entra ID is used for authentication via OpenID Connect. 
- The ChatGPT application must be registered and authenticated on chatgpt.com, with Developer Mode enabled.
- Verification of authentication using OpenID Connect will be conducted against Autonomous AI Database.
- Once the connection is established as ChatGPT App, re-authentication is not required even if the platform differs (e.g., iPhone and iPad).

## Installation

### install-tables.sql

Creates:

- table `OJ_MCP_UI_RESOURCES`
- table `OJ_MCP_UI_CSP_DOMAINS`
- table `OJ_MCP_UI_PERMMISSIONS`
- table `OJ_MCP_TOOLS_EXTRAS`
- view `OJ_MCP_UC_AI_TOOLS`

### install-packages.sql

Creates the following packages:

- `OJ_MCP_RAS_CTX`
- `OJ_MCP_JSONRPC_UTILS`
- `OJ_MCP_APP_UTILS`
- `OJ_MCP_APP_METHODS`
- `OJ_MCP_APP_SERVER`

procedures:

- `OJ_MCP_POST_HANDLER`
- `OJ_MCP_DELETE_HANDLER`
- `OJ_MCP_RAS_POST_HANDLER`
- `OJ_MCP_RAS_DELETE_HANDLER`

### install-sampleserver.sql

- ORDS REST module `sampleserver`
- PL/SQL functions
  - `get_schema`
  - `run_sql`
  - `get_current_user`
- UC_AI tool definitions for the PL/SQL functions
- UI resources for tool `get_current_user`
- Table `AUTH_USERS`
- Package `OJ_MCP_RAS_CONFIG`

## Requirements for Running the Sample Server

**The APEX workspace name must match the ORDS alias.**

In most configurations, APEX workspace name and ORDS alias are identical.

**The URI prefix must be the module name enclosed in "/".**

The ORDS REST module `sampleserver` will be created with the following prefix: /sampleserver/

**An APEX application whose alias matches the ORDS module name must exist.**

Create an APEX application with the alias: sampleserver

## Related blog articles

All articles are written in Japanese.

### MCP App hosting environment

All scripts in this article are updated and are contained in this repository.

- [MCPを話すOracle Databaseを作成する - Autonomous AI Database編](https://apexugj.blogspot.com/2026/03/create-oracle-database-that-supports-mcp.html)

- [MCPを話すOracle Databaseを作成する - ローカル・データベース編](https://apexugj.blogspot.com/2026/03/create-mcp-app-on-ords.html)

- [APEXアプリケーションのページ生成をMCP Appの簡易バンドラとして利用する](https://apexugj.blogspot.com/2026/03/generate-ui-resources-bundle-from-apex-page.html)

- [MCP Appとして日報アプリを作成する](https://apexugj.blogspot.com/2026/03/simple-daily-report-mcp-app.html)

### Implementation of OpenResty(nginx) as a reverse proxy

- [Oracle APEXの実行環境とリバース・プロキシを構成する - Oracle Linux 10編](https://apexugj.blogspot.com/2026/02/configure-reverse-proxy-using-nginx-for-apex-and-ords.html)

- [Oracle APEXの実行環境とリバース・プロキシを構成する - Ubuntu 24.04編](https://apexugj.blogspot.com/2025/12/building-oracle-apex-on-ubuntu.html)

- [Oracle APEXの実行環境とリバース・プロキシを構成する - 追加手順](https://apexugj.blogspot.com/2026/02/building-oracle-apex-appendix.html)

- [リバース・プロキシとして構成したnginxでWWW-Authenticateヘッダーを書き換える](https://apexugj.blogspot.com/2025/12/nginx-more-clear-headers-to-rewrite-www-authenticate.html)

### Implementation of OIDC authentication

- [Role based JWT profileで保護したORDS REST APIにアクセスする - Microsoft Entra ID編](https://apexugj.blogspot.com/2025/12/call-ords-rest-api-by-chatgpt-and-claude-with-entraid.html)

- [Role based JWT profileで保護したORDS REST APIにアクセスする - Okta Integrator編](https://apexugj.blogspot.com/2025/12/call-ords-rest-api-by-mcp-inspector-with-okta.html)

- [Role based JWT profileで保護したORDS REST APIにアクセスする - Auth0編](https://apexugj.blogspot.com/2025/12/call-ords-rest-api-by-mcp-inspector-with-auth0.html)

- [Role based JWT profileで保護したORDS REST APIにアクセスする - Oracle IAM編](https://apexugj.blogspot.com/2025/12/call-ords-rest-api-by-mcp-inspector-with-oracle-iam.html)
