import { z } from 'zod';

// v0.6 CHANGE FROM v0.5: replace the permissive z.record(z.unknown()) proposal
// payload with per-kind, per-operation allowlists matching migration 00300.
// Unknown keys are rejected; SQL remains the final authority for ownership/version checks.
const nonBlank = (max: number) => z.string().trim().min(1).max(max);
const optionalText = (max: number) => z.string().max(max).nullable().optional();
const uuid = z.string().uuid();
const dateOnly = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine((v: string) => {
  const d = new Date(`${v}T00:00:00.000Z`);
  return !Number.isNaN(d.valueOf()) && d.toISOString().slice(0, 10) === v;
}, 'Expected a real calendar date');
const isoDateTime = z.string().datetime({ offset: true });
const itemStatus = z.enum(['Draft','Open','In Progress','Blocked','Completed','Cancelled','On Hold']);

const payloads = {
  event: {
    create: z.object({
      title: nonBlank(240), eventType: nonBlank(80).optional(),
      description: optionalText(10000), occurredAt: isoDateTime.optional()
    }).strict(),
    update: z.object({
      title: nonBlank(240).optional(), eventType: nonBlank(80).optional(),
      description: optionalText(10000), occurredAt: isoDateTime.optional()
    }).strict().refine((v: object) => Object.keys(v).length > 0, 'At least one field is required')
  },
  commitment: {
    create: z.object({
      title: nonBlank(240), description: optionalText(10000), ownerUserId: uuid.nullable().optional(),
      status: itemStatus.optional(), dueDate: dateOnly.nullable().optional(), externalStatus: optionalText(240)
    }).strict(),
    update: z.object({
      title: nonBlank(240).optional(), description: optionalText(10000), ownerUserId: uuid.nullable().optional(),
      status: itemStatus.optional(), dueDate: dateOnly.nullable().optional(), externalStatus: optionalText(240)
    }).strict().refine((v: object) => Object.keys(v).length > 0, 'At least one field is required')
  },
  task: {
    create: z.object({
      title: nonBlank(240), details: optionalText(10000), ownerUserId: uuid.nullable().optional(),
      status: itemStatus.optional(), priority: z.enum(['Low','Normal','High','Urgent']).optional(),
      dueDate: dateOnly.nullable().optional(), externalStatus: optionalText(240)
    }).strict(),
    update: z.object({
      title: nonBlank(240).optional(), details: optionalText(10000), ownerUserId: uuid.nullable().optional(),
      status: itemStatus.optional(), priority: z.enum(['Low','Normal','High','Urgent']).optional(),
      dueDate: dateOnly.nullable().optional(), externalStatus: optionalText(240)
    }).strict().refine((v: object) => Object.keys(v).length > 0, 'At least one field is required')
  },
  decision: {
    create: z.object({
      title: nonBlank(240), rationale: optionalText(10000),
      decisionStatus: z.enum(['Proposed','Decided','Superseded']).optional(), decidedAt: isoDateTime.nullable().optional()
    }).strict(),
    update: z.object({
      title: nonBlank(240).optional(), rationale: optionalText(10000),
      decisionStatus: z.enum(['Proposed','Decided','Superseded']).optional(), decidedAt: isoDateTime.nullable().optional()
    }).strict().refine((v: object) => Object.keys(v).length > 0, 'At least one field is required')
  },
  comment: {
    create: z.object({
      body: nonBlank(10000), eventId: uuid.optional(), commitmentId: uuid.optional(),
      taskId: uuid.optional(), decisionId: uuid.optional()
    }).strict().superRefine((v: {eventId?: string; commitmentId?: string; taskId?: string; decisionId?: string}, ctx: z.RefinementCtx) => {
      const count = ['eventId','commitmentId','taskId','decisionId'].filter(k => v[k as keyof typeof v] !== undefined).length;
      if (count !== 1) ctx.addIssue({code:z.ZodIssueCode.custom,message:'Exactly one comment parent is required'});
    }),
    update: z.object({ body: nonBlank(10000) }).strict()
  }
} as const;

export const proposalBodySchema = z.object({
  onboardingId: uuid,
  kind: z.enum(['event','commitment','task','decision','comment']),
  operation: z.enum(['create','update']),
  targetRecordId: uuid.optional(),
  baseRecordVersion: z.number().int().positive().optional(),
  payload: z.unknown()
}).strict().superRefine((body: {onboardingId: string; kind: keyof typeof payloads; operation: 'create'|'update'; targetRecordId?: string; baseRecordVersion?: number; payload?: unknown}, ctx: z.RefinementCtx) => {
  const isUpdate = body.operation === 'update';
  if (isUpdate && (!body.targetRecordId || !body.baseRecordVersion)) {
    ctx.addIssue({code:z.ZodIssueCode.custom,path:['targetRecordId'],message:'Updates require targetRecordId and baseRecordVersion'});
  }
  if (!isUpdate && (body.targetRecordId !== undefined || body.baseRecordVersion !== undefined)) {
    ctx.addIssue({code:z.ZodIssueCode.custom,path:['targetRecordId'],message:'Creates must not include targetRecordId or baseRecordVersion'});
  }
  const schema = payloads[body.kind][body.operation];
  const result = schema.safeParse(body.payload);
  if (!result.success) {
    for (const issue of result.error.issues) ctx.addIssue({...issue,path:['payload',...issue.path]});
  }
});
