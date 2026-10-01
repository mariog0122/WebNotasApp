# P1 Commercial Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir la oferta pública de planes en reglas comerciales ejecutables por el backend, con trial real de 15 días, precio calculado por servidor y límites de estudiantes resistentes a concurrencia.

**Architecture:** PostgreSQL será la fuente de verdad para catálogo, suscripción, entitlement y límites. El frontend sólo mostrará el catálogo y enviará el plan/ciclo elegidos; nunca decidirá precios ni capacidad. Un trigger transaccional bloqueará inserciones que superen la capacidad y las pruebas SQL simularán concurrencia lógica, trial vencido y manipulación de precio.

**Tech Stack:** Vue 3, Vitest, Supabase Postgres 17, RLS, PL/pgSQL, Supabase Cron opcional.

---

### Task 1: Contrato comercial comprobable

**Files:**
- Create: `app/src/lib/commercialPlans.js`
- Create: `app/tests/commercialPlans.test.js`
- Modify: `app/src/views/Pricing.vue`

- [ ] **Step 1: Write the failing catalog test**

```js
expect(getPlan('institutional_500')).toMatchObject({ monthlyPrice: 89, annualPrice: 890, maxStudents: 500 })
expect(getPlan('institutional_1000')).toMatchObject({ monthlyPrice: 129, annualPrice: 1290, maxStudents: 1000 })
expect(getPlan('institutional_2000')).toMatchObject({ monthlyPrice: 179, annualPrice: 1790, maxStudents: 2000 })
expect(getPlanPrice('institutional_500', 'yearly')).toBe(890)
```

- [ ] **Step 2: Run RED**

Run: `npm test -- --run tests/commercialPlans.test.js`
Expected: FAIL because `commercialPlans.js` does not exist.

- [ ] **Step 3: Implement the immutable public catalog**

```js
export const COMMERCIAL_PLANS = Object.freeze([
  Object.freeze({ code: 'institutional_500', name: 'Plan Institucional 500', monthlyPrice: 89, annualPrice: 890, maxStudents: 500 }),
  Object.freeze({ code: 'institutional_1000', name: 'Plan Institucional 1000', monthlyPrice: 129, annualPrice: 1290, maxStudents: 1000 }),
  Object.freeze({ code: 'institutional_2000', name: 'Plan Institucional 2000', monthlyPrice: 179, annualPrice: 1790, maxStudents: 2000 }),
])
export const getPlan = (code) => COMMERCIAL_PLANS.find((plan) => plan.code === code) || null
export const getPlanPrice = (code, cycle) => cycle === 'yearly' ? getPlan(code)?.annualPrice : getPlan(code)?.monthlyPrice
```

- [ ] **Step 4: Make Pricing render plan cards from `COMMERCIAL_PLANS` and replace login trial links with a sales-contact CTA**

- [ ] **Step 5: Run GREEN**

Run: `npm test -- --run tests/commercialPlans.test.js`
Expected: PASS.

### Task 2: Catálogo y suscripciones como fuente de verdad

**Files:**
- Create: `migrations/14_p1_commercial_catalog_limits.sql`
- Create: `migrations/tests/14_p1_commercial_catalog_limits_test.sql`

- [ ] **Step 1: Write SQL assertions before applying DDL**

Assertions must require exactly the three paid codes/prices/capacities, a 15-day trial, server-derived subscription price, and rejection at the student limit.

- [ ] **Step 2: Verify RED against the current database**

Expected: missing `monthly_price`, `annual_price`, `student_limit`, `trial_days`, `tenant_limits` and enforcement trigger.

- [ ] **Step 3: Add catalog and subscription columns**

```sql
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS monthly_price numeric(10,2);
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS annual_price numeric(10,2);
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS student_limit integer;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS trial_days integer NOT NULL DEFAULT 15;
ALTER TABLE public.plans ADD COLUMN IF NOT EXISTS implementation_fee numeric(10,2) NOT NULL DEFAULT 350;
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS billing_cycle text NOT NULL DEFAULT 'monthly';
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS agreed_price numeric(10,2);
ALTER TABLE public.subscriptions ADD COLUMN IF NOT EXISTS trial_ends_at timestamptz;
```

- [ ] **Step 4: Seed the approved catalog and create tenant limits from the active subscription**

Paid values are 89/890/500, 129/1290/1000 and 179/1790/2000. All paid plans expose the same academic features; only capacity differs.

- [ ] **Step 5: Create concurrency-safe student enforcement**

```sql
PERFORM pg_advisory_xact_lock(hashtextextended(NEW.school_id::text, 0));
SELECT max_students INTO allowed FROM public.tenant_limits WHERE school_id = NEW.school_id;
SELECT count(*) INTO used FROM public.students WHERE school_id = NEW.school_id AND id IS DISTINCT FROM NEW.id;
IF used >= allowed THEN RAISE EXCEPTION 'STUDENT_LIMIT_REACHED'; END IF;
```

- [ ] **Step 6: Create entitlement checks**

Access is allowed for `active`, for `trial` only through `trial_ends_at`, and for `past_due/grace_period` only through `grace_period_until`. Suspended/cancelled/archived tenants are denied in the same backend predicate used by RLS.

- [ ] **Step 7: Harden provisioning**

The existing RPC signature remains compatible, but ignores `p_price`, validates `p_plan_id`, derives price from the selected billing cycle, creates a `trial` subscription ending in 15 days, creates limits/features, and never records a fake completed payment.

- [ ] **Step 8: Apply migration and run SQL GREEN tests**

Expected: all fixtures roll back and existing production row counts remain unchanged.

### Task 3: Wizard without client-controlled prices

**Files:**
- Modify: `app/src/views/superadmin/WizardTab.vue`
- Modify: `app/src/views/superadmin/TenantsTab.vue`
- Test: `app/tests/commercialPlans.test.js`

- [ ] **Step 1: Add a failing source invariant**

```js
expect(wizardSource).not.toMatch(/v-model="form\.price"/)
expect(wizardSource).not.toContain('p_price: parseFloat')
```

- [ ] **Step 2: Run RED**

- [ ] **Step 3: Display computed monthly/annual catalog prices read from Supabase**

The RPC receives `p_price: 0` only for backward signature compatibility; PostgreSQL ignores it.

- [ ] **Step 4: Replace table fallbacks with real `tenant_limits`/usage data and explicit load errors**

- [ ] **Step 5: Run GREEN and build**

Run: `npm test -- --run && npm run build`.

### Task 4: Lifecycle automation

**Files:**
- Create: `migrations/15_p1_subscription_lifecycle.sql`
- Create: `migrations/tests/15_p1_subscription_lifecycle_test.sql`

- [ ] **Step 1: Write failing SQL tests for expired trials and grace periods**

- [ ] **Step 2: Add `refresh_subscription_lifecycle()`**

The function moves expired trials to `suspended`, expired grace periods to `suspended`, synchronizes `schools.status/is_active`, and writes `tenant_status_logs` idempotently.

- [ ] **Step 3: Schedule daily execution only when `pg_cron` is installed**

```sql
IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
  PERFORM cron.schedule('refresh-subscription-lifecycle', '15 3 * * *', 'select public.refresh_subscription_lifecycle()');
END IF;
```

- [ ] **Step 4: Apply and verify with rolled-back fixtures**

### Task 5: Final verification and audit update

**Files:**
- Modify: `SAAS_PRODUCTION_AUDIT.md`

- [ ] **Step 1: Run unit tests, build and Playwright**
- [ ] **Step 2: Run SQL catalog/limit/lifecycle tests**
- [ ] **Step 3: Repeat anonymous REST probes and advisors**
- [ ] **Step 4: Record remaining blockers: payments, atomic grades/import, secure invitations, backup/restore and CI/CD**
