// Firebase/GCP admin helper — derives an access token from the firebase-tools
// stored refresh token and calls Google admin APIs (Service Usage + Identity Toolkit).
// Node 25 has global fetch. No external deps. Never prints the token.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const PROJECT_ID = 'minikrutin-app';
const PROJECT_NUMBER = '352512787449';
// Public firebase-tools OAuth client (open-source, embedded in the CLI).
const CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

function readRefreshToken() {
  const p = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  const j = JSON.parse(fs.readFileSync(p, 'utf8'));
  const rt = j?.tokens?.refresh_token;
  if (!rt) throw new Error('No refresh_token in firebase-tools.json');
  return rt;
}

async function accessToken() {
  const body = new URLSearchParams({
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    refresh_token: readRefreshToken(),
    grant_type: 'refresh_token',
  });
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  const j = await r.json();
  if (!j.access_token) throw new Error('Token exchange failed: ' + JSON.stringify(j));
  return j.access_token;
}

async function api(token, method, url, body) {
  const r = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'X-Goog-User-Project': PROJECT_ID,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await r.text();
  let j;
  try { j = text ? JSON.parse(text) : {}; } catch { j = { raw: text }; }
  return { status: r.status, json: j };
}

const cmd = process.argv[2];
const token = await accessToken();

if (cmd === 'token') {
  console.log('OK: access token acquired (length ' + token.length + ')');
} else if (cmd === 'enable-apis') {
  const services = [
    'firestore.googleapis.com',
    'identitytoolkit.googleapis.com',
    'serviceusage.googleapis.com',
    'cloudresourcemanager.googleapis.com',
  ];
  const res = await api(token, 'POST',
    `https://serviceusage.googleapis.com/v1/projects/${PROJECT_NUMBER}/services:batchEnable`,
    { serviceIds: services });
  console.log('batchEnable status', res.status, JSON.stringify(res.json).slice(0, 400));
} else if (cmd === 'list-apis') {
  const res = await api(token, 'GET',
    `https://serviceusage.googleapis.com/v1/projects/${PROJECT_NUMBER}/services?filter=state:ENABLED&pageSize=200`);
  const names = (res.json.services || []).map(s => s.config?.name).filter(Boolean);
  console.log('ENABLED:', names.join('\n  '));
} else if (cmd === 'init-auth') {
  // Provision the Identity Platform Config resource for the project.
  const res = await api(token, 'POST',
    `https://identitytoolkit.googleapis.com/v2/projects/${PROJECT_ID}/identityPlatform:initializeAuth`,
    {});
  console.log('init-auth status', res.status, JSON.stringify(res.json).slice(0, 600));
} else if (cmd === 'enable-auth') {
  // Enable Email/Password sign-in via Identity Toolkit Admin v2 config.
  const res = await api(token, 'PATCH',
    `https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT_ID}/config?updateMask=signIn.email.enabled,signIn.email.passwordRequired`,
    { signIn: { email: { enabled: true, passwordRequired: true } } });
  console.log('enable-auth status', res.status, JSON.stringify(res.json).slice(0, 600));
} else if (cmd === 'get-auth') {
  const res = await api(token, 'GET',
    `https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT_ID}/config`);
  console.log('get-auth status', res.status, JSON.stringify(res.json.signIn || res.json).slice(0, 600));
} else {
  console.log('Unknown command:', cmd);
  process.exit(1);
}
