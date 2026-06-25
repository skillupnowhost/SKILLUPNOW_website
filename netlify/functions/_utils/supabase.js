const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const headers = {
  'Content-Type': 'application/json',
  'apikey': SUPABASE_SERVICE_KEY,
  'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
};

async function insertRow(table, data) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: 'POST',
    headers: { ...headers, 'Prefer': 'return=representation' },
    body: JSON.stringify(data),
  });
  const result = await res.json();
  if (!res.ok) throw new Error(result.message || `Insert into ${table} failed`);
  return Array.isArray(result) ? result[0] : result;
}

async function updateRows(table, filters, data) {
  const query = Object.entries(filters).map(([k, v]) => `${k}=eq.${v}`).join('&');
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${query}`, {
    method: 'PATCH',
    headers: { ...headers, 'Prefer': 'return=representation' },
    body: JSON.stringify(data),
  });
  const result = await res.json();
  if (!res.ok) throw new Error(result.message || `Update ${table} failed`);
  return Array.isArray(result) ? result : [result];
}

async function selectRows(table, filters, select = '*') {
  const query = Object.entries(filters).map(([k, v]) => `${k}=eq.${v}`).join('&');
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${query}&select=${encodeURIComponent(select)}`, {
    method: 'GET',
    headers,
  });
  const result = await res.json();
  if (!res.ok) throw new Error(result.message || `Select from ${table} failed`);
  return result;
}

module.exports = { insertRow, updateRows, selectRows };
