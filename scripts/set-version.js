const fs = require('node:fs');

const version = process.argv[2];
if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version ?? '')) {
  throw new Error(`Invalid semantic version: ${version}`);
}

const frontendPath = 'frontend/package.json';
const frontend = JSON.parse(fs.readFileSync(frontendPath, 'utf8'));
frontend.version = version;
fs.writeFileSync(frontendPath, `${JSON.stringify(frontend, null, 2)}\n`);

const backendPath = 'backend/build.gradle';
const backend = fs.readFileSync(backendPath, 'utf8');
const updated = backend.replace(/^version\s*=\s*['"][^'"]+['"]$/m, `version = '${version}'`);
if (updated === backend) {
  throw new Error('Could not find the backend version declaration in backend/build.gradle');
}
fs.writeFileSync(backendPath, updated);
