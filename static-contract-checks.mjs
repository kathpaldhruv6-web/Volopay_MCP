import fs from 'node:fs';
import assert from 'node:assert/strict';
const auth=fs.readFileSync(new URL('../src/auth.ts',import.meta.url),'utf8');
const routes=fs.readFileSync(new URL('../src/routes.ts',import.meta.url),'utf8');
const supa=fs.readFileSync(new URL('../src/supabase.ts',import.meta.url),'utf8');
assert.match(auth,/auth\.getUser\(token\)/);
assert.match(auth,/workspace_memberships/);
assert.match(auth,/active', true/);
assert.match(supa,/SUPABASE_ANON_KEY/);
assert.doesNotMatch(supa,/SERVICE_ROLE/i);
for(const route of ['/onboardings','/onboardings/:onboardingId','/records/search','/commitments','/tasks','/overdue-items','/onboardings/:onboardingId/summary','/activity','/proposals']) assert.ok(routes.includes(route),`missing ${route}`);
// CHANGE v0.5: the old v0.3 assertion expected proposal submission to be a 501 placeholder.
// v0.4 replaced that placeholder with durable RPC-backed submission and human approval routes.
assert.match(routes,/submit_change_proposal/);
assert.match(routes,/approve_change_proposal/);
assert.match(routes,/reject_change_proposal/);
assert.doesNotMatch(routes,/501,'NOT_IMPLEMENTED'/);
console.log('PASS: static API contract checks (9 route surfaces, verified user lookup, membership lookup, no service-role client, transactional proposal routes).');
console.log('LIMIT: no dependency installation, TypeScript build, DB execution, JWT integration, or live RLS test was performed.');
