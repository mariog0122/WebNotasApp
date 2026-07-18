import https from 'node:https';

const options = {
  hostname: 'vtysqhyavijdveeaxobk.supabase.co',
  port: 443,
  path: '/rest/v1/',
  method: 'GET',
  headers: {
    'apikey': 'sb_publishable_avfYVCc72b6V-sToxq6Orw_NGavpvxA',
    'Authorization': 'Bearer sb_publishable_avfYVCc72b6V-sToxq6Orw_NGavpvxA'
  }
};

console.log('Intentando conectar a:', options.hostname);

const req = https.request(options, (res) => {
  console.log('Status:', res.statusCode);
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    console.log('Response:', data.substring(0, 300));
  });
});

req.on('error', (err) => {
  console.error('Error:', err.message);
  console.error('Code:', err.code);
});

req.setTimeout(10000, () => {
  console.log('Timeout');
  req.destroy();
});