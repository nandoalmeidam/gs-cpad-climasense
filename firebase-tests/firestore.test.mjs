import { readFileSync } from 'node:fs';
import { before, beforeEach, after, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, collection, setDoc, getDoc, getDocs, deleteDoc, serverTimestamp } from 'firebase/firestore';

let ambiente;
before(async () => {
  ambiente = await initializeTestEnvironment({projectId:'demo-climasense', firestore:{
    host:'127.0.0.1',port:8080,rules:readFileSync(new URL('../firestore.rules',import.meta.url),'utf8'),
  }});
});
beforeEach(async () => ambiente.clearFirestore());
after(async () => ambiente?.cleanup());
const registro = (id='1') => ({id,bairro:'Centro',tipo:'Alagamento',descricao:'Alagamento observado na via.',data:'2026-11-15T12:00:00.000',sincronizadoEm:serverTimestamp()});
const banco = uid => ambiente.authenticatedContext(uid).firestore();
const referencia = (db,uid='usuario1',id='1') => doc(db,`usuarios/${uid}/ocorrencias/${id}`);

test('dono cria, lê e lista a própria ocorrência',async () => {
  const db = banco('usuario1');
  await assertSucceeds(setDoc(referencia(db),registro()));
  await assertSucceeds(getDoc(referencia(db)));
  await assertSucceeds(getDocs(collection(db,'usuarios/usuario1/ocorrencias')));
});
test('outro usuário não lê nem grava na área do dono',async () => {
  await assertSucceeds(setDoc(referencia(banco('usuario1')),registro()));
  const db = banco('usuario2');
  await assertFails(getDoc(referencia(db)));
  await assertFails(setDoc(referencia(db,'usuario1','2'),registro('2')));
  await assertFails(getDocs(collection(db,'usuarios/usuario1/ocorrencias')));
  await assertFails(setDoc(referencia(db),{...registro(),bairro:'Outro bairro'}));
  await assertFails(deleteDoc(referencia(db)));
});
test('acesso sem autenticação é negado',async () => {
  const db = ambiente.unauthenticatedContext().firestore();
  await assertFails(setDoc(referencia(db),registro()));
  await assertFails(getDoc(referencia(db)));
});
test('dono pode editar e excluir sem trocar ID ou data original',async () => {
  const db = banco('usuario1');
  await assertSucceeds(setDoc(referencia(db),registro()));
  await assertSucceeds(setDoc(referencia(db),registro()));
  await assertSucceeds(setDoc(referencia(db),{...registro(),bairro:'Outro bairro',descricao:'Descrição corrigida pelo dono.'}));
  await assertFails(setDoc(referencia(db),{...registro(),data:'2026-11-16T12:00:00.000'}));
  await assertSucceeds(deleteDoc(referencia(db)));
});
test('valida tamanho, tipo, identificador e campos extras',async () => {
  const db = banco('usuario1');
  await assertFails(setDoc(referencia(db),{...registro(),id:'outro'}));
  await assertFails(setDoc(referencia(db),{...registro(),descricao:'Curta'}));
  await assertFails(setDoc(referencia(db),{...registro(),bairro:'x'.repeat(101)}));
  await assertFails(setDoc(referencia(db),{...registro(),tipo:'Inexistente'}));
  await assertFails(setDoc(referencia(db),{...registro(),telefone:'123'}));
});

