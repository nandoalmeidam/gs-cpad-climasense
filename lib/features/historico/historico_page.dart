import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cabecalho.dart';
import '../../core/widgets/indicador.dart';
import '../../core/widgets/grafico_colunas.dart';
import '../../core/widgets/copia_nuvem.dart';
import '../../providers/dados_app.dart';
import '../../models/ocorrencia.dart';

class HistoricoPage extends StatefulWidget {
  final DadosApp dados;
  const HistoricoPage({super.key, required this.dados});
  @override
  State<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  String filtro = 'Todos';
  final excluindo = <String>{};

  void editar(Ocorrencia item) =>
      Navigator.of(context).pushNamed('/ocorrencia/editar', arguments: item);

  Future<void> excluir(Ocorrencia item) async {
    if (excluindo.contains(item.id)) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir ocorrência?'),
        content: Text(
          '${item.tipo} em ${item.bairro} será removida do histórico. Se houver uma cópia na nuvem, ela será apagada quando a sincronização estiver ativada e houver conexão. Não é possível desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => excluindo.add(item.id));
    try {
      await widget.dados.excluir(item.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ocorrência excluída.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível excluir. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => excluindo.remove(item.id));
    }
  }

  Future<void> detalhes(Ocorrencia item) async {
    final acao = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(item.tipo),
        content: SingleChildScrollView(
          child: Text(
            'Bairro: ${item.bairro}\nData: ${item.data.day}/${item.data.month}/${item.data.year}\n\n${item.descricao}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Fechar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'excluir'),
            child: const Text('Excluir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'editar'),
            child: const Text('Editar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (acao == 'editar') editar(item);
    if (acao == 'excluir') await excluir(item);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.dados,
      builder: (context, _) {
        final lista = widget.dados.ocorrencias
            .where((o) => filtro == 'Todos' || o.tipo == filtro)
            .toList();
        final bairros = widget.dados.porBairro().entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Cabecalho(
              'Histórico de ocorrências',
              'Veja o que foi registrado no seu bairro.',
            ),
            CopiaNuvem(dados: widget.dados),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Indicador(
                  'Registros',
                  '${widget.dados.ocorrencias.length}',
                  Icons.assignment_outlined,
                ),
                Indicador(
                  'Bairros',
                  '${bairros.length}',
                  Icons.location_on_outlined,
                ),
                Indicador(
                  'Alagamentos',
                  "${widget.dados.contar('Alagamento')}",
                  Icons.water,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ocorrências por bairro',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (bairros.isEmpty)
                      const Text(
                        'Quando você registrar uma ocorrência, ela aparecerá aqui.',
                      ),
                    if (bairros.isNotEmpty)
                      GraficoColunas(
                        dados: bairros
                            .map((e) => ColunaDado(e.key, e.value.toDouble()))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Registros',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/ocorrencia/nova'),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova ocorrência'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: filtro,
              decoration: const InputDecoration(
                labelText: 'Filtrar por tipo',
                border: OutlineInputBorder(),
              ),
              items:
                  [
                        'Todos',
                        'Alagamento',
                        'Deslizamento',
                        'Falta de água',
                        'Outro',
                      ]
                      .map(
                        (e) =>
                            DropdownMenuItem<String>(value: e, child: Text(e)),
                      )
                      .toList(),
              onChanged: (v) => setState(() => filtro = v ?? 'Todos'),
            ),
            const SizedBox(height: 10),
            if (lista.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Nenhuma ocorrência para este filtro.'),
                ),
              ),
            ...lista.map(
              (o) => Card(
                key: ValueKey('ocorrencia_${o.id}'),
                child: ListTile(
                  leading: const Icon(Icons.place_outlined, color: verde),
                  trailing: excluindo.contains(o.id)
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(),
                        )
                      : PopupMenuButton<String>(
                          tooltip: 'Opções da ocorrência',
                          onSelected: (acao) {
                            if (acao == 'editar') {
                              editar(o);
                            } else {
                              excluir(o);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'editar',
                              child: Text('Editar'),
                            ),
                            PopupMenuItem(
                              value: 'excluir',
                              child: Text('Excluir'),
                            ),
                          ],
                        ),
                  title: Text('${o.tipo} · ${o.bairro}'),
                  subtitle: Text(
                    '${o.data.day}/${o.data.month}/${o.data.year} — ${o.descricao}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: excluindo.contains(o.id) ? null : () => detalhes(o),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Os registros ficam no aparelho. A cópia na nuvem é opcional.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}
