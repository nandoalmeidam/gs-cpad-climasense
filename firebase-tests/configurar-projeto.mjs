import { createRequire } from 'node:module';
import { readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
const require = createRequire(import.meta.url);
const projectId = 'climasense-gs26-b27e91';
const {getGlobalDefaultAccount} = require('firebase-tools/lib/auth');
const {requireAuth} = require('firebase-tools/lib/requireAuth');
const {Client} = require('firebase-tools/lib/apiv2');
const apps = require('firebase-tools/lib/management/apps');
const {ensure} = require('firebase-tools/lib/ensureApiEnabled');
const cli = require.resolve('firebase-tools/lib/bin/firebase.js');

function executar(args) {
  const r = spawnSync(process.execPath,[cli,...args,'--project',projectId,'--json','--non-interactive'],{encoding:'utf8',maxBuffer:4*1024*1024});
  let v; try {v=JSON.parse(r.stdout);}catch{}
  if (r.status !== 0 || v?.status !== 'success') throw Error(typeof v?.error === 'string' ? v.error : v?.error?.message || 'A etapa Firebase falhou.');
  return v.result;
}

try {
  const conta = getGlobalDefaultAccount();
  if (!conta) throw Error('Não há sessão Firebase conectada.');
  await requireAuth({project:projectId,projectId,user:conta.user,tokens:conta.tokens});
  const webExistentes = await apps.listFirebaseApps(projectId,'WEB');
  const web = webExistentes.find(a=>a.displayName==='ClimaSense Web') ?? await apps.createWebApp(projectId,{displayName:'ClimaSense Web'});
  console.log('Aplicação web registrada.');
  const androidExistentes = await apps.listFirebaseApps(projectId,'ANDROID');
  const android = androidExistentes.find(a=>a.packageName==='br.com.fiap.climasense') ?? await apps.createAndroidApp(projectId,{displayName:'ClimaSense Android',packageName:'br.com.fiap.climasense'});
  console.log('Aplicação Android registrada.');
  const configWeb = await apps.getAppConfig(web.appId,'WEB');
  const configAndroid = await apps.getAppConfig(android.appId,'ANDROID');
  const androidJson = JSON.parse(apps.getAppConfigFile(configAndroid,'ANDROID').fileContents);
  writeFileSync(new URL('../android/app/google-services.json',import.meta.url),JSON.stringify(androidJson,null,2)+'\n');
  writeFileSync(new URL('../web/firebase-config.json',import.meta.url),JSON.stringify(configWeb,null,2)+'\n');
  const info = androidJson.project_info;
  const cliente = androidJson.client.find(c=>c.client_info.android_client_info.package_name==='br.com.fiap.climasense');
  const dartString = v => JSON.stringify(v);
  function opcoes(c) {
    return Object.entries(c).filter(([,v])=>v!==undefined && v!==null).map(([k,v])=>`    ${k}: ${dartString(v)},`).join('\n');
  }
  writeFileSync(new URL('../lib/firebase_options.dart',import.meta.url),`// Configuração pública dos clientes Firebase. O acesso aos dados depende das regras.\nimport 'package:firebase_core/firebase_core.dart';\nimport 'package:flutter/foundation.dart';\n\nclass DefaultFirebaseOptions {\n  static FirebaseOptions? get currentPlatform {\n    if (kIsWeb) return web;\n    if (defaultTargetPlatform == TargetPlatform.android) return android;\n    return null;\n  }\n  static const web = FirebaseOptions(\n${opcoes({apiKey:configWeb.apiKey,appId:configWeb.appId,messagingSenderId:configWeb.messagingSenderId,projectId:configWeb.projectId,authDomain:configWeb.authDomain,storageBucket:configWeb.storageBucket})}\n  );\n  static const android = FirebaseOptions(\n${opcoes({apiKey:cliente.api_key[0].current_key,appId:cliente.client_info.mobilesdk_app_id,messagingSenderId:info.project_number,projectId:info.project_id,storageBucket:info.storage_bucket})}\n  );\n}\n`);
  console.log('Configuração pública Android/web gravada no projeto.');

  await ensure(projectId,'identitytoolkit.googleapis.com','firebase',true);
  await ensure(projectId,'firestore.googleapis.com','firebase',true);
  const identidade = new Client({urlPrefix:'https://identitytoolkit.googleapis.com',apiVersion:'admin/v2',auth:true});
  let authPronto = true;
  try {
    await identidade.request({method:'GET',path:`/projects/${projectId}/config`});
  } catch (e) {
    if (!e.message.includes('CONFIGURATION_NOT_FOUND')) throw e;
    authPronto = false;
  }
  if (authPronto) {
    await identidade.request({method:'PATCH',path:`/projects/${projectId}/config`,queryParams:{updateMask:'signIn.anonymous.enabled'},body:{signIn:{anonymous:{enabled:true}}}});
    console.log('Autenticação anônima habilitada.');
  } else {
    console.log('Authentication aguarda a ativação inicial gratuita no Console. Nenhum faturamento foi vinculado.');
  }
  const databases = executar(['firestore:databases:list']);
  const lista = Array.isArray(databases) ? databases : databases?.databases ?? [];
  if (!lista.some(d=>d.name?.endsWith('/databases/(default)'))) {
    executar(['firestore:databases:create','(default)','--location','southamerica-east1','--edition','standard']);
  }
  console.log('Firestore Standard em São Paulo preparado.');
  executar(['deploy','--only','firestore:rules']);
  console.log('Regras privadas publicadas.');
  console.log(JSON.stringify({projectId,webAppId:web.appId,androidAppId:android.appId,firestoreConfigured:true,authConfigured:authPronto}));
} catch (e) {
  console.error('Configuração interrompida:',e.message);
  process.exitCode=1;
}
