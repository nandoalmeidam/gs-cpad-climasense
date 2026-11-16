import 'package:flutter/material.dart';
import '../../providers/dados_app.dart';
import '../../features/conta/conta_page.dart';

class CopiaNuvem extends StatelessWidget {
  final DadosApp dados;
  const CopiaNuvem({super.key, required this.dados});

  String get status {
    if (!dados.nuvemConfigurada || !dados.nuvemAtiva) {
      return 'Salvos neste aparelho';
    }
    if (dados.sincronizando) return 'Sincronizando…';
    if (dados.erroNuvem != null) return 'Não foi possível atualizar a cópia';
    if (dados.pendentes > 0) {
      return '${dados.pendentes} ${dados.pendentes == 1 ? 'alteração aguardando' : 'alterações aguardando'} envio';
    }
    if (dados.ultimaSincronizacao == null) {
      return 'Aguardando a primeira sincronização';
    }
    return 'Cópia na nuvem atualizada';
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                dados.nuvemAtiva && dados.nuvemConfigurada
                    ? Icons.cloud_outlined
                    : Icons.phone_android_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (dados.sincronizando)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(
                semanticsLabel: 'Sincronizando registros',
              ),
            ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Salvar também na nuvem'),
            value: dados.nuvemAtiva,
            subtitle: Text(
              dados.nuvemConfigurada
                  ? 'Envia uma cópia das ocorrências para sua área privada. Os registros continuam disponíveis neste aparelho sem internet.'
                  : 'A cópia na nuvem ainda não está disponível neste aplicativo.',
            ),
            onChanged: !dados.nuvemConfigurada
                ? null
                : (valor) async {
                    try {
                      await dados.configurarNuvem(valor);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Não foi possível salvar essa preferência. Tente novamente.',
                            ),
                          ),
                        );
                      }
                    }
                  },
          ),
          if (dados.nuvemConfigurada && dados.conta != null)
            TextButton.icon(
              onPressed: dados.alterandoConta
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ContaPage(dados: dados),
                      ),
                    ),
              icon: const Icon(Icons.account_circle_outlined),
              label: Text(
                dados.conta!.contaPermanente
                    ? 'Minha conta'
                    : 'Criar conta ou entrar',
              ),
            ),
          if (dados.nuvemAtiva && dados.nuvemConfigurada) ...[
            if (dados.erroNuvem != null)
              Text(
                dados.erroNuvem!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            TextButton.icon(
              onPressed: dados.sincronizando ? null : dados.sincronizar,
              icon: const Icon(Icons.sync),
              label: const Text('Sincronizar agora'),
            ),
            if (dados.ultimaSincronizacao != null)
              Text(
                'Última atualização: ${dados.ultimaSincronizacao!.day}/${dados.ultimaSincronizacao!.month} às ${dados.ultimaSincronizacao!.hour.toString().padLeft(2, '0')}:${dados.ultimaSincronizacao!.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Text(
              dados.conta?.contaPermanente == true
                  ? 'Conta conectada: ${dados.conta!.email}. Use a mesma conta em outro aparelho para recuperar as cópias sincronizadas.'
                  : 'Sem conta por e-mail, a cópia está associada apenas a esta instalação. Crie uma conta para recuperar o histórico em outro aparelho.',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
}
