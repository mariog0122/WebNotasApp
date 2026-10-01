import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://ykokuwkvplifbjxgdveu.supabase.co';
const supabaseAnonKey = 'sb_publishable_CBUK56HIo7g0mfA8HneTnQ_bcO2bTPk';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function inspect() {
  console.log('1. Checking courses select...');
  const { data: courses, error: coursesError } = await supabase.from('courses').select('*').limit(5);
  console.log('Courses error:', coursesError);
  console.log('Courses sample:', courses);

  console.log('\n2. Checking academic_years select...');
  const { data: years, error: yearsError } = await supabase.from('academic_years').select('*').limit(5);
  console.log('Years error:', yearsError);
  console.log('Years sample:', years);

  console.log('\n3. Checking schools select...');
  const { data: schools, error: schoolsError } = await supabase.from('schools').select('*').limit(5);
  console.log('Schools error:', schoolsError);
  console.log('Schools sample:', schools);

  console.log('\n4. Checking students select...');
  const { data: students, error: studentsError } = await supabase.from('students').select('*').limit(5);
  console.log('Students error:', studentsError);
  console.log('Students count:', students?.length);

  console.log('\n5. Checking quarters select...');
  const { data: quarters, error: quartersError } = await supabase.from('quarters').select('*').limit(5);
  console.log('Quarters error:', quartersError);
  console.log('Quarters sample:', quarters);
}

inspect();
