import { createClient } from '@supabase/supabase-js';

const url = 'https://ykokuwkvplifbjxgdveu.supabase.co';
const key = 'sb_publishable_CBUK56HIo7g0mfA8HneTnQ_bcO2bTPk';
const supabase = createClient(url, key);

async function checkAll() {
  console.log('--- AUDITORIA DE TABLAS SUPABASE ---');
  const tables = [
    'schools', 'profiles', 'tenant_memberships', 'platform_roles', 'user_platform_roles',
    'courses', 'subjects', 'students', 'grades', 'supplementary_grades', 'quarters',
    'academic_years', 'grade_definitions', 'system_config', 'subscriptions', 'plans',
    'tenant_limits', 'tenant_features', 'tenant_billing_profiles', 'invoices',
    'invoice_lines', 'invoice_payment_allocations', 'payments', 'payment_events',
    'tenant_status_logs', 'client_telemetry_events', 'audit_log', 'student_alerts',
    'course_subjects', 'project_grades', 'project_subject_grades'
  ];

  const tableResults = {};
  for (const t of tables) {
    const { data, error } = await supabase.from(t).select('*').limit(1);
    if (!error) {
      tableResults[t] = 'PRESENTE (Accesible)';
    } else if (error.code === '42P01' || error.message?.includes('relation') || error.message?.includes('does not exist')) {
      tableResults[t] = 'FALTA (No existe en Supabase)';
    } else if (error.code === '42501' || error.message?.includes('row-level security') || error.message?.includes('permission denied')) {
      tableResults[t] = 'PRESENTE (Protegida por RLS)';
    } else {
      tableResults[t] = `PRESENTE (${error.code || error.message})`;
    }
  }

  for (const [t, status] of Object.entries(tableResults)) {
    console.log(`${t.padEnd(30)}: ${status}`);
  }

  console.log('\n--- AUDITORIA DE FUNCIONES RPC SUPABASE ---');
  const rpcs = [
    'save_grade_batch',
    'save_supplementary_batch',
    'set_tenant_status',
    'record_manual_payment',
    'get_my_access_context',
    'upload_tenant_payment_proof',
    'delete_tenant',
    'get_platform_health',
    'get_tenant_usage_stats',
    'copy_courses_to_academic_year',
    'has_platform_role',
    'is_platform_admin',
    'get_user_school_id'
  ];

  const rpcResults = {};
  for (const r of rpcs) {
    const { data, error } = await supabase.rpc(r, {});
    if (!error) {
      rpcResults[r] = 'PRESENTE (Ejecutable)';
    } else if (error.message?.includes('Could not find the function') || error.code === '42883') {
      rpcResults[r] = 'FALTA (Función no encontrada en Supabase)';
    } else if (error.code === '42501' || error.message?.includes('permission denied')) {
      rpcResults[r] = 'PRESENTE (Requiere rol / Permiso denegado)';
    } else {
      rpcResults[r] = `PRESENTE (Existe - ${error.message})`;
    }
  }

  for (const [r, status] of Object.entries(rpcResults)) {
    console.log(`${r.padEnd(30)}: ${status}`);
  }

  console.log('\n--- AUDITORIA DE COLUMNAS ESPECIFICAS ---');
  const columnChecks = [
    { table: 'courses', column: 'tutor_name' },
    { table: 'profiles', column: 'phone' },
    { table: 'schools', column: 'suspended_reason' },
    { table: 'subscriptions', column: 'agreed_price' },
    { table: 'tenant_billing_profiles', column: 'latest_receipt_url' }
  ];

  for (const { table, column } of columnChecks) {
    const { data, error } = await supabase.from(table).select(column).limit(1);
    if (!error) {
      console.log(`${(table + '.' + column).padEnd(35)}: PRESENTE`);
    } else if (error.message?.includes('column') && error.message?.includes('does not exist')) {
      console.log(`${(table + '.' + column).padEnd(35)}: FALTA (Columna no existe)`);
    } else {
      console.log(`${(table + '.' + column).padEnd(35)}: ${error.message}`);
    }
  }
}

checkAll().catch(console.error);
