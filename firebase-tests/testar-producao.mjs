import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { randomUUID } from 'node:crypto';
import { initializeApp, deleteApp } from 'firebase/app';
import { initializeAuth, inMemoryPersistence, signInAnonymously, deleteUser, linkWithCredential, EmailAuthProvider, signInWithEmailAndPassword } from 'firebase/auth';
import { getFirestore, doc, collection, runTransaction, serverTimestamp, getDocFromServer, getDocsFromServer, terminate, setLogLevel } from 'firebase/firestore';

const require = createRequire(import.meta.url);
const projectId = 'climasense-gs26-b27e91';
const config = JSON.parse(readFileSync(new URL('../web/firebase-config.json',import.meta.url),'utf8'));
if (config.projectId !== projectId) throw Error('Projeto inesperado. Validação cancelada.');
setLogLevel('silent');
const id = `validacao-${randomUUID()}`;
const descricao = 'Registro técnico de validação da integração. Não representa uma ocorrência real.';
const descricaoEditada = 'Registro técnico corrigido. Não representa uma ocorrência real.';
const instancias = [];
let caminho, principal, aprovado = false, limpeza = true;

async function criarCliente(nome) {
  const app = initializeApp(config,nome);
  const auth = initializeAuth(app,{persistence:inMemoryPersistence});
  const cliente = {app,auth,db:getFirestore(app),uid:null};
  instancias.push(cliente);
  const credencial = await signInAnonymously(auth);
  if (!credencial.user.isAnonymous) throw Error('Identidade de teste inesperada.');
  cliente.uid = credencial.user.uid;
  return cliente;
}

try {
  principal = await criarCliente('climasense-validacao-gravacao');
  caminho = `usuarios/${principal.uid}/ocorrencias/${id}`;
  const ref = doc(principal.db,caminho);
  const dados = {id,bairro:'Teste de integração',tipo:'Outro',descricao,data:new Date().toISOString()};
  async function enviar() {
    await runTransaction(principal.db,async tx => {
      const existente = await tx.get(ref);
      if (existente.exists()) return;
      tx.set(ref,{...dados,sincronizadoEm:serverTimestamp()});
    },{maxAttempts:2});
  }
  await enviar();
  const remoto = await getDocFromServer(ref);
  if (!remoto.exists() || remoto.data().descricao !== descricao || !remoto.data().sincronizadoEm) throw Error('Leitura de confirmação inválida.');
  await enviar();
  const lista = await getDocsFromServer(collection(principal.db,`usuarios/${principal.uid}/ocorrencias`));
  if (lista.size !== 1 || lista.docs[0].id !== id) throw Error('A nova tentativa duplicou dados.');
  const email = `climasense-${randomUUID()}@example.com`;
  const senha = randomUUID() + 'Aa9!';
  await linkWithCredential(principal.auth.currentUser,EmailAuthProvider.credential(email,senha));
  const appRecuperado = initializeApp(config,'climasense-validacao-recuperacao');
  const authRecuperado = initializeAuth(appRecuperado,{persistence:inMemoryPersistence});
  const recuperado = {app:appRecuperado,auth:authRecuperado,db:getFirestore(appRecuperado),uid:null};
  instancias.push(recuperado);
  recuperado.uid = (await signInWithEmailAndPassword(authRecuperado,email,senha)).user.uid;
  if(recuperado.uid !== principal.uid || !(await getDocFromServer(doc(recuperado.db,caminho))).exists()) throw Error('Recuperação da conta em outro cliente falhou.');
  const outro = await criarCliente('climasense-validacao-isolamento');
  let bloqueado = false;
  try { await getDocFromServer(doc(outro.db,caminho)); }
  catch (e) { if (e.code === 'permission-denied') bloqueado = true; else throw e; }
  if (!bloqueado) throw Error('O isolamento entre usuários falhou.');
  for (const excluir of [false,true]) {
    let negado = false;
    try {
      await runTransaction(outro.db,async tx => {
        const alvo = doc(outro.db,caminho);
        if (excluir) tx.delete(alvo);
        else tx.set(alvo,{...dados,descricao:descricaoEditada,sincronizadoEm:serverTimestamp()});
      },{maxAttempts:2});
    } catch(e) { if(e.code === 'permission-denied') negado = true; else throw e; }
    if(!negado) throw Error('Alteração por outro usuário foi permitida.');
  }
  await runTransaction(principal.db,async tx => {
    await tx.get(ref);
    tx.set(ref,{...dados,descricao:descricaoEditada,sincronizadoEm:serverTimestamp()});
  },{maxAttempts:2});
  if((await getDocFromServer(ref)).data()?.descricao !== descricaoEditada) throw Error('Edição não confirmada.');
  await runTransaction(principal.db,async tx => {
    if((await tx.get(ref)).exists()) tx.delete(ref);
  },{maxAttempts:2});
  if((await getDocFromServer(ref)).exists()) throw Error('Exclusão não confirmada.');
  aprovado = true;
  console.log(JSON.stringify({projectId,anonymousAuth:true,emailLinkedSameUid:true,accountRecoveredInAnotherClient:true,writeConfirmed:true,serverReadConfirmed:true,retryWithoutDuplicates:true,updateConfirmed:true,deleteConfirmed:true,crossUserAccessDenied:true}));
} catch (e) {
  console.error('Validação real não concluída:',e.code || e.message);
  process.exitCode=1;
} finally {
  // Remove apenas o documento técnico criado nesta execução, após conferir seu conteúdo.
  if (caminho) {
    try {
      const {getGlobalDefaultAccount} = require('firebase-tools/lib/auth');
      const {requireAuth} = require('firebase-tools/lib/requireAuth');
      const {Client} = require('firebase-tools/lib/apiv2');
      const conta = getGlobalDefaultAccount();
      await requireAuth({project:projectId,projectId,user:conta.user,tokens:conta.tokens});
      const admin = new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1',auth:true});
      const alvo = `/projects/${projectId}/databases/(default)/documents/${caminho}`;
      try {
        const r = await admin.request({method:'GET',path:alvo});
        if (r.body?.fields?.id?.stringValue !== id || ![descricao,descricaoEditada].includes(r.body?.fields?.descricao?.stringValue)) throw Error('Conteúdo diferente do teste; exclusão cancelada.');
        await admin.request({method:'DELETE',path:alvo});
      } catch (e) {
        if (!(e.status === 404 || e.message?.includes('404'))) throw e;
      }
    } catch (e) { limpeza = false; console.error('Limpeza do registro técnico não concluída:',e.code || e.message); }
  }
  const removidos = new Set();
  for (const c of instancias) {
    try {
      await terminate(c.db);
      if (c.uid && c.auth.currentUser?.uid === c.uid && !removidos.has(c.uid)) {
        await deleteUser(c.auth.currentUser);
        removidos.add(c.uid);
      }
      await deleteApp(c.app);
    } catch (_) { limpeza = false; }
  }
  console.log(JSON.stringify({testPassed:aprovado,testDataCleaned:limpeza}));
  if (!limpeza) process.exitCode=1;
}
