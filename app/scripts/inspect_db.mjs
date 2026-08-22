import pg from 'pg';

const passwords = ['DcTrI3GpEKARIB76', 'AmKrknhAEkp82ugS'];
const hosts = [
  'db.ykokuwkvplifbjxgdveu.supabase.co',
  'aws-0-sa-east-1.pooler.supabase.com',
  'aws-0-us-east-1.pooler.supabase.com',
  'aws-0-us-west-1.pooler.supabase.com'
];

async function test() {
  for (const host of hosts) {
    for (const pass of passwords) {
      const user = host.includes('pooler') ? 'postgres.ykokuwkvplifbjxgdveu' : 'postgres';
      const client = new pg.Client({
        host,
        port: host.includes('pooler') ? 6543 : 5432,
        user,
        password: pass,
        database: 'postgres',
        ssl: { rejectUnauthorized: false }
      });
      try {
        await client.connect();
        console.log('SUCCESS connecting to host:', host, 'user:', user);
        const res = await client.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'courses'");
        console.log('COURSES COLUMNS:', res.rows);
        
        const tablesRes = await client.query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'");
        console.log('PUBLIC TABLES:', tablesRes.rows.map(r => r.table_name));
        
        await client.end();
        return;
      } catch (err) {
        // try next
      }
    }
  }
  console.log('Could not connect with tested credentials');
}

test();
