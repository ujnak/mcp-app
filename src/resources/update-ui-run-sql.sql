set define off
declare
    l_text clob;
begin
    /*
     * Everything was written by Claude Sonnet 4.6.
     * 
     * 2026/03/06 ynakakos
     */
    l_text := q'~<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Run SQL</title>
  <meta name="mcp-app-width" content="1140">
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html, body { width: 100%; min-width: 320px; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--color-background-primary, #f9fafb);
      color: var(--color-text-primary, #111827);
      display: flex;
      align-items: flex-start;
      justify-content: center;
      min-height: 100vh;
      padding: 16px;
    }
    .card {
      background: var(--color-background-secondary, #fff);
      border: 1px solid var(--color-border-primary, #e5e7eb);
      border-radius: 10px;
      padding: 24px;
      width: 100%;
      max-width: 1140px;
      box-shadow: 0 1px 4px rgba(0,0,0,0.08);
    }
    h2 { font-size: 15px; font-weight: 600; margin-bottom: 14px; }
    #status { font-size: 12px; color: #6b7280; min-height: 18px; margin-bottom: 10px; }
    .input-row {
      display: flex;
      gap: 8px;
      margin-bottom: 14px;
      align-items: flex-start;
    }
    textarea {
      flex: 1;
      padding: 8px 10px;
      font-size: 13px;
      font-family: "SFMono-Regular", Consolas, monospace;
      border: 1px solid var(--color-border-primary, #e5e7eb);
      border-radius: 6px;
      background: var(--color-background-primary, #f9fafb);
      color: var(--color-text-primary, #111827);
      resize: vertical;
      min-height: 72px;
      line-height: 1.5;
    }
    textarea:focus { outline: none; border-color: #2563eb; }
    button {
      padding: 9px 18px;
      font-size: 13px;
      font-weight: 500;
      color: #fff;
      background: #2563eb;
      border: none;
      border-radius: 6px;
      cursor: pointer;
      transition: background .15s;
      white-space: nowrap;
      align-self: flex-end;
    }
    button:hover:not(:disabled) { background: #1d4ed8; }
    button:disabled { background: #93c5fd; cursor: not-allowed; }
    #error-box {
      display: none;
      background: #fef2f2;
      border: 1px solid #fecaca;
      color: #991b1b;
      border-radius: 8px;
      padding: 10px 14px;
      font-size: 13px;
      margin-bottom: 12px;
    }
    .table-wrap {
      display: none;
      overflow-x: auto;
    }
    .scroll-body {
      max-height: calc(10 * 36px);
      overflow-y: auto;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
    }
    thead th {
      position: sticky;
      top: 0;
      background: var(--color-background-secondary, #fff);
      border-bottom: 2px solid var(--color-border-primary, #e5e7eb);
      padding: 8px 10px;
      text-align: left;
      font-weight: 600;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: .04em;
      opacity: .75;
      white-space: nowrap;
      z-index: 1;
    }
    tbody tr { border-bottom: 1px solid var(--color-border-primary, #e5e7eb); }
    tbody tr:last-child { border-bottom: none; }
    tbody tr:hover { background: var(--color-background-primary, #f9fafb); }
    tbody td {
      padding: 8px 10px;
      vertical-align: top;
      word-break: break-word;
      max-width: 320px;
    }
    .row-count {
      font-size: 11px;
      color: #6b7280;
      margin-top: 8px;
      text-align: right;
    }
  </style>
</head>
<body>
  <div class="card">
    <h2>Run SQL</h2>
    <div id="status">Initializing...</div>
    <div class="input-row">
      <textarea id="sql-input" placeholder="SELECT * FROM dual"></textarea>
      <button id="btn" disabled>Run</button>
    </div>
    <div id="error-box"></div>
    <div class="table-wrap" id="table-wrap">
      <div class="scroll-body" id="scroll-body">
        <table>
          <thead id="thead"><tr id="header-row"></tr></thead>
          <tbody id="tbody"></tbody>
        </table>
      </div>
      <div class="row-count" id="row-count"></div>
    </div>
  </div>
  <script type="module">
    import { App, applyHostStyleVariables, applyDocumentTheme }
      from 'https://cdn.jsdelivr.net/npm/@modelcontextprotocol/ext-apps@1.2.2/+esm';

    const statusEl   = document.getElementById('status');
    const sqlInput   = document.getElementById('sql-input');
    const btn        = document.getElementById('btn');
    const errorBox   = document.getElementById('error-box');
    const tableWrap  = document.getElementById('table-wrap');
    const headerRow  = document.getElementById('header-row');
    const tbody      = document.getElementById('tbody');
    const rowCount   = document.getElementById('row-count');

    function esc(s) {
      return String(s == null ? '' : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;')
        .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function showError(msg) {
      errorBox.textContent   = msg;
      errorBox.style.display = 'block';
      tableWrap.style.display = 'none';
      statusEl.textContent   = '';
      btn.disabled = false;
    }

    function renderTable(rows) {
      errorBox.style.display  = 'none';
      tableWrap.style.display = 'block';
      headerRow.innerHTML = '';
      tbody.innerHTML = '';

      if (!rows || rows.length === 0) {
        rowCount.textContent = '0 rows';
        tableWrap.style.display = 'none';
        statusEl.textContent = 'Query returned no rows.';
        btn.disabled = false;
        return;
      }

      // build header from first row keys
      const cols = Object.keys(rows[0]);
      cols.forEach(col => {
        const th = document.createElement('th');
        th.textContent = col;
        headerRow.appendChild(th);
      });

      // build rows
      rows.forEach(row => {
        const tr = document.createElement('tr');
        cols.forEach(col => {
          const td = document.createElement('td');
          const val = row[col];
          td.innerHTML = esc(val == null ? '' : (typeof val === 'object' ? JSON.stringify(val) : val));
          tr.appendChild(td);
        });
        tbody.appendChild(tr);
      });

      rowCount.textContent = rows.length + ' row' + (rows.length === 1 ? '' : 's');
      statusEl.textContent = '';
      btn.disabled = false;
    }

    function handleResult(result) {
      const content = result?.result?.content ?? result?.content ?? [];
      const block   = content.find(c => c.type === 'text');
      const text    = block?.text ?? JSON.stringify(result);
      let parsed = null;
      try { parsed = JSON.parse(text); } catch (_) {}

      if (Array.isArray(parsed)) {
        renderTable(parsed);
      } else if (parsed?.error) {
        showError(parsed.error);
      } else {
        // fallback: show raw text
        errorBox.textContent   = text;
        errorBox.style.display = 'block';
        tableWrap.style.display = 'none';
        statusEl.textContent = '';
        btn.disabled = false;
      }
    }

    // ── App setup ──────────────────────────────────────────────────────────
    const app = new App(
      { name: 'run-sql-app', version: '1.0.0' },
      {},
      { autoResize: true, initialSize: { width: 1140 } }
    );

    app.onerror = (_err) => { /* suppress init errors */ };

    app.onhostcontextchanged = (ctx) => {
      if (ctx?.theme)              applyDocumentTheme(ctx.theme);
      if (ctx?.styles?.variables)  applyHostStyleVariables(ctx.styles.variables);
    };

    btn.addEventListener('click', async () => {
      const sql = sqlInput.value.trim();
      if (!sql) { showError('Please enter a SELECT statement.'); return; }
      btn.disabled = true;
      errorBox.style.display   = 'none';
      tableWrap.style.display  = 'none';
      statusEl.textContent     = 'Running query...';

      try {
        const result = await app.callServerTool({ "name": "run_sql", "arguments": { "sql": sql } });
        handleResult(result);
      } catch (err) {
        showError(err?.message ?? String(err));
      }
    });

    // ── Connect ────────────────────────────────────────────────────────────
    try {
      statusEl.textContent = 'Connecting...';
      await app.connect();

      app.onerror = (err) => {
        statusEl.textContent = 'Error: ' + (err?.message ?? String(err));
      };

      const ctx = app.getHostContext();
      if (ctx?.theme)              applyDocumentTheme(ctx.theme);
      if (ctx?.styles?.variables)  applyHostStyleVariables(ctx.styles.variables);

      statusEl.textContent = 'Ready. Enter a SELECT statement and click Run.';
      btn.disabled = false;

    } catch (err) {
      app.onerror = (e) => {
        statusEl.textContent = 'Error: ' + (e?.message ?? String(e));
      };
      statusEl.textContent = 'Init failed: ' + (err?.message ?? String(err));
      btn.disabled = false;
    }
  </script>
</body>
</html>~';
    update oj_mcp_ui_resources set text = l_text where id = (
        select resource_id from oj_mcp_uc_ai_tools where code = 'Run SQL'
    );
    commit;
end;
/
