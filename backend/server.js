'use strict';

require('dotenv').config();

const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');
const express = require('express');
const cors = require('cors');
const {
  Configuration,
  PlaidApi,
  PlaidEnvironments,
  Products,
} = require('plaid');

const PORT = Number(process.env.FINANCE_API_PORT || 8787);
const CERT_DIR = path.join(__dirname, 'certs');
const CERT_PATH = path.join(CERT_DIR, 'localhost.pem');
const KEY_PATH = path.join(CERT_DIR, 'localhost-key.pem');
const DATA_DIR = path.join(__dirname, '.data');
const SESSION_PATH = path.join(DATA_DIR, 'session.json');

const PLAID_CLIENT_ID = process.env.PLAID_CLIENT_ID;
const PLAID_SECRET = process.env.PLAID_SECRET;
const PLAID_ENV = process.env.PLAID_ENV || 'sandbox';
const PLAID_REDIRECT_URI =
  process.env.PLAID_REDIRECT_URI || 'https://localhost:8787/plaid/oauth';
const PLAID_COMPLETION_URI =
  process.env.PLAID_COMPLETION_URI || 'https://localhost:8787/plaid/complete';

/** @type {{ linkToken: string | null, finished: boolean }} */
let pendingLink = { linkToken: null, finished: false };

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

function readSession() {
  ensureDataDir();
  if (!fs.existsSync(SESSION_PATH)) return null;
  try {
    return JSON.parse(fs.readFileSync(SESSION_PATH, 'utf8'));
  } catch {
    return null;
  }
}

function writeSession(session) {
  ensureDataDir();
  fs.writeFileSync(SESSION_PATH, JSON.stringify(session, null, 2));
}

function clearSession() {
  if (fs.existsSync(SESSION_PATH)) fs.unlinkSync(SESSION_PATH);
}

function requirePlaidConfig(_req, res, next) {
  if (!PLAID_CLIENT_ID || !PLAID_SECRET) {
    return res.status(503).json({
      error: 'missing_plaid_credentials',
      message:
        'Add PLAID_CLIENT_ID and PLAID_SECRET to backend/.env (see backend/.env.example).',
    });
  }
  next();
}

const configuration = new Configuration({
  basePath: PlaidEnvironments[PLAID_ENV],
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': PLAID_CLIENT_ID,
      'PLAID-SECRET': PLAID_SECRET,
      'Plaid-Version': '2020-09-14',
    },
  },
});

const plaid = new PlaidApi(configuration);

const app = express();
app.use(cors());
app.use(express.json());

app.get('/api/health', (_req, res) => {
  res.json({
    ok: true,
    plaidConfigured: Boolean(PLAID_CLIENT_ID && PLAID_SECRET),
    environment: PLAID_ENV,
  });
});

app.get('/api/status', (_req, res) => {
  const session = readSession();
  res.json({
    connected: Boolean(session?.access_token),
    institutionName: session?.institution_name ?? null,
    itemId: session?.item_id ?? null,
    lastSyncedAt: session?.last_synced_at ?? null,
  });
});

app.post('/api/link/token', requirePlaidConfig, async (_req, res, next) => {
  try {
    const response = await plaid.linkTokenCreate({
      user: { client_user_id: 'grimy-grills' },
      client_name: 'Grimy Grills',
      products: [Products.Transactions],
      country_codes: ['US'],
      language: 'en',
      redirect_uri: PLAID_REDIRECT_URI,
      transactions: { days_requested: 730 },
      hosted_link: {
        completion_redirect_uri: PLAID_COMPLETION_URI,
        is_mobile_app: false,
      },
    });

    pendingLink = { linkToken: response.data.link_token, finished: false };

    res.json({
      link_token: response.data.link_token,
      hosted_link_url: response.data.hosted_link_url,
      expiration: response.data.expiration,
    });
  } catch (error) {
    next(error);
  }
});

app.get('/plaid/oauth', (_req, res) => {
  res.type('html').send(`
    <!doctype html>
    <html><body style="font-family: system-ui; background:#07080a; color:#f4f4f6; padding:2rem;">
      <h1>Grimy Grills</h1>
      <p>Finishing bank sign-in… you can return to the Automations app.</p>
    </body></html>
  `);
});

app.get('/plaid/complete', (_req, res) => {
  pendingLink.finished = true;
  res.type('html').send(`
    <!doctype html>
    <html><body style="font-family: system-ui; background:#07080a; color:#f4f4f6; padding:2rem;">
      <h1>Bank connected</h1>
      <p>Wells Fargo is linked. Close this tab and return to Automations — spending will refresh automatically.</p>
    </body></html>
  `);
});

app.get('/api/link/wait', async (_req, res) => {
  if (!pendingLink.linkToken) {
    return res.json({ ready: false });
  }
  res.json({ ready: pendingLink.finished, linkToken: pendingLink.linkToken });
});

app.post('/api/link/complete', requirePlaidConfig, async (req, res, next) => {
  const linkToken = req.body?.link_token ?? pendingLink.linkToken;
  if (!linkToken) {
    return res.status(400).json({ error: 'missing_link_token' });
  }

  try {
    const sessionInfo = await plaid.linkTokenGet({ link_token: linkToken });
    const linkSessions = sessionInfo.data.link_sessions ?? [];
    const latest = linkSessions[linkSessions.length - 1];
    const results = latest?.results ?? {};
    const publicToken = results.public_token ?? results.public_tokens?.[0];

    if (!publicToken) {
      return res.status(409).json({
        error: 'link_not_finished',
        message: 'Plaid Link has not finished yet. Try again in a moment.',
      });
    }

    const exchange = await plaid.itemPublicTokenExchange({ public_token: publicToken });
    const accessToken = exchange.data.access_token;
    const itemId = exchange.data.item_id;

    let institutionName = 'Connected bank';
    try {
      const item = await plaid.itemGet({ access_token: accessToken });
      const institutionId = item.data.item.institution_id;
      if (institutionId) {
        const institution = await plaid.institutionsGetById({
          institution_id: institutionId,
          country_codes: ['US'],
        });
        institutionName = institution.data.institution.name;
      }
    } catch {
      // Non-fatal — we still have a valid Item.
    }

    writeSession({
      access_token: accessToken,
      item_id: itemId,
      institution_name: institutionName,
      cursor: null,
      last_synced_at: null,
    });

    pendingLink = { linkToken: null, finished: false };

    res.json({
      connected: true,
      institutionName,
      itemId,
    });
  } catch (error) {
    next(error);
  }
});

app.post('/api/disconnect', (_req, res) => {
  clearSession();
  res.json({ connected: false });
});

async function syncAllTransactions(accessToken, existingCursor) {
  let cursor = existingCursor ?? undefined;
  let added = [];
  let modified = [];
  let removed = [];
  let hasMore = true;
  let attempts = 0;

  while (hasMore) {
    const response = await plaid.transactionsSync({
      access_token: accessToken,
      cursor,
    });
    const data = response.data;

    if (!cursor && data.next_cursor === '') {
      attempts += 1;
      if (attempts > 15) {
        break;
      }
      await sleep(1500);
      continue;
    }

    cursor = data.next_cursor;
    added = added.concat(data.added);
    modified = modified.concat(data.modified);
    removed = removed.concat(data.removed);
    hasMore = data.has_more;
  }

  return { added, modified, removed, cursor };
}

function categoryLabel(transaction) {
  const pfc = transaction.personal_finance_category;
  if (pfc?.primary) {
    return pfc.primary.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  }
  if (transaction.category?.length) {
    return transaction.category[transaction.category.length - 1];
  }
  return 'Uncategorized';
}

function isOutflow(transaction) {
  // Depository: positive amount = money leaving the account.
  return transaction.amount > 0;
}

app.get('/api/spending', requirePlaidConfig, async (_req, res, next) => {
  const session = readSession();
  if (!session?.access_token) {
    return res.status(401).json({ error: 'not_connected' });
  }

  try {
    const sync = await syncAllTransactions(session.access_token, session.cursor);

    const byId = new Map();
    for (const txn of sync.added) byId.set(txn.transaction_id, txn);
    for (const txn of sync.modified) byId.set(txn.transaction_id, txn);
    for (const removedId of sync.removed) byId.delete(removedId);

    const transactions = [...byId.values()];
    const outflows = transactions.filter(isOutflow);

    const categories = new Map();
    for (const txn of outflows) {
      const label = categoryLabel(txn);
      const bucket = categories.get(label) ?? { category: label, total: 0, count: 0 };
      bucket.total += txn.amount;
      bucket.count += 1;
      categories.set(label, bucket);
    }

    const categoryBreakdown = [...categories.values()].sort((a, b) => b.total - a.total);
    const totalSpending = outflows.reduce((sum, txn) => sum + txn.amount, 0);

    writeSession({
      ...session,
      cursor: sync.cursor,
      last_synced_at: new Date().toISOString(),
    });

    res.json({
      totalSpending,
      transactionCount: outflows.length,
      categories: categoryBreakdown,
      recent: outflows
        .slice()
        .sort((a, b) => (a.date < b.date ? 1 : -1))
        .slice(0, 50)
        .map((txn) => ({
          id: txn.transaction_id,
          date: txn.date,
          name: txn.merchant_name || txn.name,
          amount: txn.amount,
          category: categoryLabel(txn),
          pending: txn.pending,
        })),
      syncedAt: new Date().toISOString(),
    });
  } catch (error) {
    next(error);
  }
});

app.use((error, _req, res, _next) => {
  const plaidError = error?.response?.data;
  console.error('[finance-api]', plaidError ?? error);
  res.status(error?.response?.status || 500).json({
    error: plaidError?.error_code || 'internal_error',
    message: plaidError?.error_message || error.message || 'Unexpected error',
  });
});

function startServer() {
  if (!PLAID_CLIENT_ID || !PLAID_SECRET) {
    console.warn('Plaid credentials missing — copy backend/.env.example to backend/.env');
  }

  const hasCerts = fs.existsSync(CERT_PATH) && fs.existsSync(KEY_PATH);

  if (hasCerts) {
    const server = https.createServer(
      {
        key: fs.readFileSync(KEY_PATH),
        cert: fs.readFileSync(CERT_PATH),
      },
      app
    );
    server.listen(PORT, () => {
      console.log(`Grimy Grills finance API listening on https://localhost:${PORT}`);
      console.log(`  OAuth redirect: ${PLAID_REDIRECT_URI}`);
    });
    return;
  }

  console.warn(
    'No local HTTPS certs found — run: Scripts/setup-local-https.sh\n' +
      'Plaid requires https redirect URIs. HTTP fallback is dev-only and may fail OAuth.'
  );
  http.createServer(app).listen(PORT, () => {
    console.log(`Grimy Grills finance API listening on http://127.0.0.1:${PORT}`);
  });
}

startServer();
