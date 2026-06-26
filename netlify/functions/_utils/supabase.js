const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

function getHeaders() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    throw new Error('Supabase environment variables not configured (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY)');
  }
  return {
    'Content-Type': 'application/json',
    'apikey': SUPABASE_SERVICE_KEY,
    'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
  };
}

async function insertRow(table, data) {
  const h = getHeaders();
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: 'POST',
    headers: { ...h, 'Prefer': 'return=representation' },
    body: JSON.stringify(data),
  });
  let result;
  try { result = await res.json(); } catch { result = {}; }
  if (!res.ok) {
    const msg = result.message || result.details || result.hint || `Insert into ${table} failed (HTTP ${res.status})`;
    console.error(`insertRow(${table}) error:`, JSON.stringify(result));
    throw new Error(msg);
  }
  return Array.isArray(result) ? result[0] : result;
}

async function updateRows(table, filters, data) {
  const h = getHeaders();
  const query = Object.entries(filters).map(([k, v]) => `${k}=eq.${v}`).join('&');
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${query}`, {
    method: 'PATCH',
    headers: { ...h, 'Prefer': 'return=representation' },
    body: JSON.stringify(data),
  });
  let result;
  try { result = await res.json(); } catch { result = {}; }
  if (!res.ok) {
    const msg = result.message || result.details || result.hint || `Update ${table} failed (HTTP ${res.status})`;
    console.error(`updateRows(${table}) error:`, JSON.stringify(result));
    throw new Error(msg);
  }
  return Array.isArray(result) ? result : [result];
}

async function selectRows(table, filters, select = '*') {
  const h = getHeaders();
  const query = Object.entries(filters).map(([k, v]) => `${k}=eq.${v}`).join('&');
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${query}&select=${encodeURIComponent(select)}`, {
    method: 'GET',
    headers: h,
  });
  let result;
  try { result = await res.json(); } catch { result = {}; }
  if (!res.ok) {
    const msg = result.message || result.details || result.hint || `Select from ${table} failed (HTTP ${res.status})`;
    console.error(`selectRows(${table}) error:`, JSON.stringify(result));
    throw new Error(msg);
  }
  return result;
}

module.exports = { insertRow, updateRows, selectRows };
