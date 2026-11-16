import 'package:flutter/material.dart';
import '../../models/ocorrencia.dart';
import '../../providers/dados_app.dart';

class CadastroPage extends StatefulWidget {
  final DadosApp dados;
  final bool embutido;
  final Ocorrencia? ocorrencia;
  const CadastroPage({
    super.key,
    required this.dados,
    this.embutido = false,
    this.ocorrencia,
  });
  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final chave = GlobalKey<FormState>();
  final bairro = TextEditingController(), descricao = TextEditingController();
  String tipo = 'Alagamento';
  bool salvando = false;
  @override
  void initState() {
    super.initState();
    final item = widget.ocorrencia;
    if (item != null) {
      bairro.text = item.bairro;
      descricao.text = item.descricao;
      tipo = item.tipo;
    }
  }

  @override
  void dispose() {
    bairro.dispose();
    descricao.dispose();
    super.dispose();
  }

  Future<void> salvar() async {
    if (!chave.currentState!.validate()) return;
    setState(() => salvando = true);
    try {
      final original = widget.ocorrencia;
      final item = Ocorrencia(
        original?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        bairro.text.trim(),
        tipo,
        descricao.text.trim(),
        original?.data ?? DateTime.now(),
      );
      if (original == null) {
        await widget.dados.adicionar(item);
      } else {
        await widget.dados.editar(item);
      }
      if (mounted) {
        if (widget.embutido) {
          bairro.clear();
          descricao.clear();
          setState(() => salvando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ocorrência salva. Consulte Histórico e Alertas.'),
            ),
          );
        } else {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                original == null ? 'Ocorrência salva.' : 'Alterações salvas.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar. Tente novamente.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embutido
        ? null
        : AppBar(
            title: Text(
              widget.ocorrencia == null
                  ? 'Nova ocorrência'
                  : 'Editar ocorrência',
            ),
          ),
    body: Form(
      key: chave,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Relate uma situação observada no seu território. Não inclua dados pessoais.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: bairro,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Bairro',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v?.trim().length ?? 0) < 2
                ? 'Informe um bairro válido.'
                : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: tipo,
            decoration: const InputDecoration(
              labelText: 'Tipo',
              border: OutlineInputBorder(),
            ),
            items: [
              'Alagamento',
              'Deslizamento',
              'Falta de água',
              'Outro',
            ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => tipo = v ?? tipo),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: descricao,
            maxLines: 4,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v?.trim().length ?? 0) < 10
                ? 'Descreva a ocorrência com pelo menos 10 caracteres.'
                : null,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: salvando ? null : salvar,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              salvando
                  ? 'Salvando...'
                  : widget.ocorrencia == null
                  ? 'Salvar ocorrência'
                  : 'Salvar alterações',
            ),
          ),
        ],
      ),
    ),
  );
}
