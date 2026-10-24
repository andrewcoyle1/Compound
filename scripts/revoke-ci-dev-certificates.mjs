// Revokes the development certificates that release runs leave behind.
//
// `xcodebuild archive -allowProvisioningUpdates` on a fresh GitHub runner creates a new Apple
// Development certificate through the App Store Connect API ("Created via API") to sign the
// archive; the export then re-signs with a cloud-managed distribution certificate. The runner,
// and the certificate's private key, are thrown away afterwards, but the certificate stays on the
// account. At the account's limit (twelve) the next archive fails with "Your account has reached
// the maximum number of certificates" (20 Oct 2026). Releases never overlap (the workflow's
// concurrency group), so every "Created via API" development certificate is a leftover: this
// revokes them all. Certificates made in Xcode carry their owner's name and are never touched.
//
//   ASC_API_KEY_PATH=… ASC_API_KEY_ID=… ASC_API_ISSUER_ID=… node scripts/revoke-ci-dev-certificates.mjs
import { readFileSync } from 'node:fs';
import { createSign } from 'node:crypto';

const { ASC_API_KEY_PATH, ASC_API_KEY_ID, ASC_API_ISSUER_ID } = process.env;
if (!ASC_API_KEY_PATH || !ASC_API_KEY_ID || !ASC_API_ISSUER_ID) throw new Error('ASC_API_KEY_PATH, ASC_API_KEY_ID and ASC_API_ISSUER_ID are required');

const b64u = (value) => Buffer.from(typeof value === 'string' ? value : JSON.stringify(value)).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const head = b64u({ alg: 'ES256', kid: ASC_API_KEY_ID, typ: 'JWT' });
const body = b64u({ iss: ASC_API_ISSUER_ID, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' });
const signature = createSign('SHA256').update(`${head}.${body}`).sign({ key: readFileSync(ASC_API_KEY_PATH, 'utf8'), dsaEncoding: 'ieee-p1363' }).toString('base64url');
const headers = { Authorization: `Bearer ${head}.${body}.${signature}` };
const api = 'https://api.appstoreconnect.apple.com/v1/certificates';

const listing = await fetch(`${api}?limit=200&filter[certificateType]=DEVELOPMENT&fields[certificates]=certificateType,displayName,expirationDate`, { headers });
if (!listing.ok) throw new Error(`listing certificates: HTTP ${listing.status}`);
const leftovers = (await listing.json()).data.filter(
  (c) => c.attributes.certificateType === 'DEVELOPMENT' && c.attributes.displayName === 'Created via API',
);
console.log(`Revoking ${leftovers.length} development certificate(s) created via API.`);
for (const certificate of leftovers) {
  const response = await fetch(`${api}/${certificate.id}`, { method: 'DELETE', headers });
  console.log(`  expiring ${certificate.attributes.expirationDate.slice(0, 10)}: HTTP ${response.status}`);
  if (!response.ok && response.status !== 404) process.exitCode = 1;
}
