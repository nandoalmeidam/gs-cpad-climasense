import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const {getGlobalDefaultAccount} = require('firebase-tools/lib/auth');
const {requireAuth} = require('firebase-tools/lib/requireAuth');
const {Client} = require('firebase-tools/lib/apiv2');
const project = 'climasense-gs26-b27e91';
try {
  const conta = getGlobalDefaultAccount();
  await requireAuth({project,projectId:project,user:conta.user,tokens:conta.tokens});
  const api = new Client({urlPrefix:'https://identitytoolkit.googleapis.com',apiVersion:'admin/v2',auth:true});
  await api.request({method:'PATCH',path:`/projects/${project}/config`,queryParams:{updateMask:'signIn.email.enabled,signIn.email.passwordRequired'},body:{signIn:{email:{enabled:true,passwordRequired:true}}}});
  const resultado = await api.request({method:'GET',path:`/projects/${project}/config`});
  if (resultado.body?.signIn?.email?.enabled !== true || resultado.body?.signIn?.anonymous?.enabled !== true) throw Error('Configuração incompleta.');
  console.log(JSON.stringify({project,emailPasswordEnabled:true,anonymousEnabled:true}));
} catch(e) { console.error(e.message); process.exitCode = 1; }
