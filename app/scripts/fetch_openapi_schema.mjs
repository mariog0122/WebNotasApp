const supabaseUrl = 'https://ykokuwkvplifbjxgdveu.supabase.co';
const supabaseAnonKey = 'sb_publishable_CBUK56HIo7g0mfA8HneTnQ_bcO2bTPk';

async function fetchSchema() {
  const res = await fetch(`${supabaseUrl}/rest/v1/`, {
    headers: {
      'apikey': supabaseAnonKey,
      'Authorization': `Bearer ${supabaseAnonKey}`
    }
  });
  
  if (!res.ok) {
    console.error('Error fetching OpenAPI schema:', res.status, res.statusText);
    return;
  }

  const spec = await res.json();
  console.log('API Title:', spec.info?.title);
  console.log('Definitions (Tables):', Object.keys(spec.definitions || {}));
  
  if (spec.definitions?.courses) {
    console.log('\n--- COURSES TABLE SCHEMA ---');
    console.log(JSON.stringify(spec.definitions.courses.properties, null, 2));
  }
  
  if (spec.definitions?.academic_years) {
    console.log('\n--- ACADEMIC_YEARS TABLE SCHEMA ---');
    console.log(JSON.stringify(spec.definitions.academic_years.properties, null, 2));
  }

  if (spec.definitions?.students) {
    console.log('\n--- STUDENTS TABLE SCHEMA ---');
    console.log(JSON.stringify(spec.definitions.students.properties, null, 2));
  }

  if (spec.definitions?.course_subjects) {
    console.log('\n--- COURSE_SUBJECTS TABLE SCHEMA ---');
    console.log(JSON.stringify(spec.definitions.course_subjects.properties, null, 2));
  }
}

fetchSchema();
