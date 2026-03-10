set define off
declare
    l_text clob;
begin
    /*
     * Everything was written by Claude Sonnet 4.6. One point it mentioned was 
     * that callServerTool() could not be used; however, that appears to have been 
     * based on an outdated specification. I changed the argument from a plain name 
     * to an object that includes the name.
     * 
     * 2026/03/06 ynakakos
     */
    -- UI HTML for get_current_user MCP App.
    --
    -- Uses the official @modelcontextprotocol/ext-apps SDK (App class) loaded
    -- from jsDelivr CDN, while working around two known Claude Desktop bugs:
    --
    -- Bug 1: "Not connected" (race condition)
    --   Claude Desktop sends ui/notifications/host-context-changed BEFORE
    --   the ui/initialize handshake completes.  The SDK's PostMessageTransport
    --   emits an onerror when the Zod schema parse fails for the malformed
    --   message.  Fix: attach app.onerror = () => {} early so the unhandled
    --   promise rejection is suppressed, then replace it with a real handler
    --   after connect() resolves.
    --
    -- Bug 2: callServerTool() rejected (ext-apps issue #386)
    --   The button therefore sends ui/message to ask the host/AI to re-run
    --   get_current_user, rather than calling the tool directly.
    --   The result arrives via app.ontoolresult as usual.

    l_text := q'~<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="mcp-app-width" content="1140">
  <title>Current User</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html, body { width: 400px; min-width: 200px; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--color-background-primary, #f9fafb);
      color: var(--color-text-primary, #111827);
      display: flex;
      align-items: center;
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
    #status { font-size: 12px; color: #6b7280; min-height: 18px; margin-bottom: 12px; }
    #result {
      display: none;
      border-radius: 8px;
      padding: 12px 14px;
      font-size: 13px;
      margin-bottom: 14px;
    }
    #result.success { background: #f0fdf4; border: 1px solid #bbf7d0; color: #166534; }
    #result.error   { background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; }
    .lbl {
      font-weight: 600; font-size: 11px; text-transform: uppercase;
      letter-spacing: .04em; opacity: .65; margin-bottom: 3px;
    }
    .val { font-size: 14px; word-break: break-all; }
    button {
      width: 100%; padding: 9px 16px; font-size: 13px; font-weight: 500;
      color: #fff; background: #2563eb; border: none; border-radius: 6px;
      cursor: pointer; transition: background .15s;
    }
    button:hover:not(:disabled) { background: #1d4ed8; }
    button:disabled { background: #93c5fd; cursor: not-allowed; }
  </style>
</head>
<body>
  <div class="card">
    <h2>Current User</h2>
    <div id="status">Initializing...</div>
    <div id="result"></div>
    <button id="btn" disabled>Get Current User</button>
  </div>

  <script type="module">
    import { App, applyHostStyleVariables, applyDocumentTheme }
      from 'https://cdn.jsdelivr.net/npm/@modelcontextprotocol/ext-apps@1.1.2/+esm';

    const statusEl = document.getElementById('status');
    const resultEl = document.getElementById('result');
    const btn      = document.getElementById('btn');

    // ── helpers ───────────────────────────────────────────────────────────
    function esc(s) {
      return String(s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;')
        .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function showResult(cls, label, value) {
      resultEl.className     = cls;
      resultEl.innerHTML     =
        `<div class="lbl">${esc(label)}</div><div class="val">${esc(value)}</div>`;
      resultEl.style.display = 'block';
      statusEl.textContent   = '';
      btn.disabled           = false;
      btn.textContent        = 'Refresh';
    }

    function handleResult(result) {
      const content = result?.result?.content ?? result?.content ?? [];
      const block   = content.find(c => c.type === 'text');
      const text    = block?.text ?? JSON.stringify(result);
      let parsed = null;
      try { parsed = JSON.parse(text); } catch (_) {}
      if (parsed?.username)      showResult('success', 'Username', parsed.username);
      else if (parsed?.result)   showResult('error',   'Notice',   parsed.result);
      else                       showResult('success', 'Response', text);
    }

    // ── App setup ─────────────────────────────────────────────────────────
    const app = new App(
      { name: 'get-current-user-app', version: '1.0.0' },
      {},
      { autoResize: true, initialSize: { width: 1140 } }
    );

    // Bug 1 workaround: suppress the "Not connected" / Zod parse error that
    // Claude Desktop triggers by sending host-context-changed BEFORE the
    // ui/initialize handshake completes.  We swallow the error here and
    // install the real error handler only after connect() succeeds.
    app.onerror = (_err) => { /* intentionally ignored during init */ };

    // Apply theme / style variables when the host context changes.
    app.onhostcontextchanged = (ctx) => {
      if (ctx?.theme)  applyDocumentTheme(ctx.theme);
      if (ctx?.styles?.variables) applyHostStyleVariables(ctx.styles.variables);
    };

    // ── Button: call get_current_user tool directly ───────────────────────
    btn.addEventListener('click', async () => {
      btn.disabled    = true;
      btn.textContent = 'Fetching...';
      statusEl.textContent   = 'Requesting current user...';
      resultEl.style.display = 'none';

      try {
        const result = await app.callServerTool({"name": "get_current_user"});
        handleResult(result);
      } catch (err) {
        showResult('error', 'Error', err?.message ?? String(err));
      }
    });

    // ── Connect ───────────────────────────────────────────────────────────
    try {
      statusEl.textContent = 'Connecting...';
      await app.connect();

      // Install a real error handler now that init is complete.
      app.onerror = (err) => {
        statusEl.textContent = 'Error: ' + (err?.message ?? String(err));
      };

      // Apply initial host context (theme, styles).
      const ctx = app.getHostContext();
      if (ctx?.theme)  applyDocumentTheme(ctx.theme);
      if (ctx?.styles?.variables) applyHostStyleVariables(ctx.styles.variables);

      statusEl.textContent = 'Waiting for result...';
      btn.disabled    = false;
      btn.textContent = 'Get Current User';

    } catch (err) {
      // Install real error handler even on failure so future errors are visible.
      app.onerror = (e) => {
        statusEl.textContent = 'Error: ' + (e?.message ?? String(e));
      };
      statusEl.textContent = 'Init failed: ' + (err?.message ?? String(err));
      btn.disabled    = false;
      btn.textContent = 'Get Current User';
    }
  </script>
</body>
</html>~';

    update oj_mcp_app_resources set text = l_text where id = (
        select resource_id from oj_mcp_uc_ai_tools where code = 'get_current_user'
    );
    commit;
end;
/