import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const {getGlobalDefaultAccount} = require('firebase-tools/lib/auth');
const {requireAuth} = require('firebase-tools/lib/requireAuth');
const {Client} = require('firebase-tools/lib/apiv2');
const id = 'climasense-gs26-b27e91';
try {
  const conta = getGlobalDefaultAccount();
  await requireAuth({project:id,projectId:id,user:conta.user,tokens:conta.tokens});
  const cliente = new Client({urlPrefix:'https://identitytoolkit.googleapis.com',apiVersion:'admin/v2',auth:true});
  let auth = false, anonymous = false;
  try {
    const r = await cliente.request({method:'GET',path:`/projects/${id}/config`});
    auth = true; anonymous = r.body?.signIn?.anonymous?.enabled === true;
  } catch (e) { if (!e.message.includes('CONFIGURATION_NOT_FOUND')) throw e; }
  const billing = new Client({urlPrefix:'https://cloudbilling.googleapis.com',apiVersion:'v1',auth:true});
  let billingEnabled = 'não consultado';
  try {
    const r = await billing.request({method:'GET',path:`/projects/${id}/billingInfo`});
    billingEnabled = r.body.billingEnabled === true;
  } catch (_) { /* A configuração não vincula uma conta de faturamento. */ }
  console.log(JSON.stringify({projectId:id,authInitialized:auth,anonymousEnabled:anonymous,billingEnabled}));
} catch (e) { console.error(e.message); process.exitCode=1; }
