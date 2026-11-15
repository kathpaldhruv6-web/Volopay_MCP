import fs from 'node:fs';
import assert from 'node:assert/strict';
const validation = fs.readFileSync(new URL('../src/proposal-validation.ts', import.meta.url), 'utf8');
const routes = fs.readFileSync(new URL('../src/routes.ts', import.meta.url), 'utf8');
const sql = fs.readFileSync(new URL('../supabase/migrations/20261115000300_proposal_transactions.sql', import.meta.url), 'utf8');
const checks = [
  ['strict event payload schema', /event:\s*\{[\s\S]*?create:\s*z\.object\([\s\S]*?\)\.strict\(\)/.test(validation)],
  ['strict commitment payload schema', /commitment:\s*\{[\s\S]*?create:\s*z\.object\([\s\S]*?\)\.strict\(\)/.test(validation)],
  ['strict task payload schema', /task:\s*\{[\s\S]*?create:\s*z\.object\([\s\S]*?\)\.strict\(\)/.test(validation)],
  ['strict decision payload schema', /decision:\s*\{[\s\S]*?create:\s*z\.object\([\s\S]*?\)\.strict\(\)/.test(validation)],
  ['strict comment parent schema', /Exactly one comment parent is required/.test(validation)],
  ['update target and version required', /Updates require targetRecordId and baseRecordVersion/.test(validation)],
  ['create cannot include update metadata', /Creates must not include targetRecordId or baseRecordVersion/.test(validation)],
  ['route uses strict shared schema', /proposalBodySchema\.safeParse\(req\.body\)/.test(routes)],
  ['SQL rejects empty payload', /jsonb_object_length\(p_payload\)=0/.test(sql)],
  ['SQL supports explicit nullable clears', /then v_proposal\.payload->>'description' else description end/.test(sql) && /then nullif\(v_proposal\.payload->>'dueDate',''\)::date else due_date end/.test(sql)],
  ['RPC execute remains authenticated-only', /revoke all on function public\.submit_change_proposal[\s\S]*?grant execute on function public\.submit_change_proposal[\s\S]*?to authenticated/.test(sql)]
];
for (const [name, ok] of checks) { console.log(`${ok ? 'PASS' : 'FAIL'} ${name}`); assert.ok(ok, name); }
console.log(`v0.6 static proposal guard checks: ${checks.length}/${checks.length} passed`);
