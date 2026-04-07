import 'package:flutter/material.dart';
import '../models/meta.dart';
import '../database/app_database.dart';
import '../database/meta_database.dart';

class MetasScreen extends StatefulWidget {
  const MetasScreen({super.key});

  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  final _db = AppDatabase.instance;
  final _metaDb = MetaDatabase.instance;
  List<Meta> _metas = [];

  @override
  void initState() {
    super.initState();
    _carregarMetas();
  }

  Future<void> _carregarMetas() async {
    final db = await _db.database;
    final metas = await _metaDb.buscarTodos(db);
    setState(() => _metas = metas);
  }

  String _formatarMoeda(double valor) {
    final partes = valor.toStringAsFixed(2).split('.');
    final inteiros = int.parse(partes[0]);
    final decimais = partes[1];
    final formatado = inteiros.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'R\$ $formatado,$decimais';
  }

  IconData _iconeDaMeta(String chave) {
    final info = iconeMetas[chave];
    if (info == null) return Icons.star;
    switch (info['icone']) {
      case 'flight': return Icons.flight;
      case 'directions_car': return Icons.directions_car;
      case 'house': return Icons.house;
      case 'school': return Icons.school;
      case 'phone_android': return Icons.phone_android;
      case 'favorite': return Icons.favorite;
      case 'pets': return Icons.pets;
      default: return Icons.star;
    }
  }

  Future<void> _abrirDialogoCriacao() async {
    final db = await _db.database;
    final result = await showDialog<Meta>(
      context: context,
      builder: (_) => CriarMetaDialog(iconeMetas: iconeMetas),
    );
    if (result != null) {
      await _metaDb.inserir(db, result);
      await _carregarMetas();
    }
  }

  Future<void> _abrirDialogoDeposito(Meta meta, bool saida) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => DialogValor(
        titulo: saida ? 'Retirar da Meta' : 'Depositar na Meta',
        subtitle: '${saida ? 'Quanto quer retirar de' : 'Quanto quer colocar em'} ${meta.nome}?',
      ),
    );
    if (result != null && result > 0) {
      if (saida && result > meta.valorAtual) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Valor maior que o saldo da meta')),
          );
        }
        return;
      }
      final db = await _db.database;
      await _metaDb.adicionarDeposito(db, Deposito(
        metaId: meta.id!,
        valor: result,
        data: DateTime.now(),
        saida: saida,
      ));
      await _carregarMetas();
    }
  }

  Future<void> _excluirMeta(Meta meta) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir meta'),
        content: Text('Excluir "${meta.nome}" e todo o historico?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final db = await _db.database;
      await _metaDb.excluir(db, meta.id!);
      await _carregarMetas();
    }
  }

  Future<String?> _estimativa(Meta meta) async {
    final db = await _db.database;
    final dias = await _metaDb.estimativaDiasRestantes(db, meta);
    if (dias == null) return null;
    if (dias <= 0) return 'Concluida!';
    final diasInt = dias.ceil();
    if (diasInt == 1) return '1 dia';
    if (diasInt < 30) return '$diasInt dias';
    final meses = (diasInt / 30).ceil();
    if (meses == 1) return '~1 mes';
    return '~$meses meses';
  }

  Future<void> _abrirHistoricoDepositos(Meta meta) async {
    final db = await _db.database;
    final depositos = await _metaDb.buscarDepositos(db, meta.id!);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        builder: (_, controller) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(_iconeDaMeta(meta.icone),
                      color: meta.completa
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                      size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Historico - ${meta.nome}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: depositos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhum deposito ainda',
                            style: TextStyle(color: Colors.grey[500], fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: depositos.length,
                      itemBuilder: (ctx, i) {
                        final d = depositos[i];
                        final cor = d.saida ? Colors.red : Colors.green;
                        final sinal = d.saida ? '-' : '+';
                        final dias = [
                          'Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab'
                        ];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: cor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.saida ? 'Retirada' : 'Deposito',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
                                    ),
                                    Text(
                                      '${dias[d.data.weekday % 7]}, ${d.data.day}/${d.data.month}/${d.data.year}',
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '$sinal ${_formatarMoeda(d.valor)}',
                                style: TextStyle(
                                    color: cor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Minhas Metas'),
            Text(
              'Toque em uma meta para ver o historico',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ),
      body: _metas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma meta ainda',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque no + para criar sua primeira meta',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _metas.length,
              itemBuilder: (ctx, index) {
                final meta = _metas[index];
                return GestureDetector(
                  onTap: () => _abrirHistoricoDepositos(meta),
                  child: _buildMetaCard(meta, theme),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirDialogoCriacao,
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMetaCard(Meta meta, ThemeData theme) {
    final cor = meta.completa ? Colors.green : theme.colorScheme.primary;
    final progresso = meta.percentual.clamp(0, 100) / 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconeDaMeta(meta.icone), color: cor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.nome,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${meta.percentual.toStringAsFixed(0)}% de ${_formatarMoeda(meta.valorAlvo)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                meta.completa ? Icons.check_circle : Icons.more_horiz,
                color: meta.completa ? Colors.green : Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 8,
              backgroundColor: cor.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(cor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                _formatarMoeda(meta.valorAtual),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cor,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _abrirDialogoDeposito(meta, false),
                icon: const Icon(Icons.add_circle, size: 18, color: Colors.green),
                label: const Text('Depositar', style: TextStyle(color: Colors.green)),
              ),
              TextButton.icon(
                onPressed: () => _abrirDialogoDeposito(meta, true),
                icon: const Icon(Icons.remove_circle, size: 18, color: Colors.red),
                label: const Text('Retirar', style: TextStyle(color: Colors.red)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Colors.grey,
                onPressed: () => _excluirMeta(meta),
              ),
            ],
          ),
          FutureBuilder<String?>(
            future: _estimativa(meta),
            builder: (ctx, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  snap.data == 'Concluida!'
                      ? 'Meta atingida!'
                      : 'Estimativa: ${snap.data}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- Dialog criar meta ---

class CriarMetaDialog extends StatefulWidget {
  final Map<String, dynamic> iconeMetas;

  const CriarMetaDialog({super.key, required this.iconeMetas});

  @override
  State<CriarMetaDialog> createState() => _CriarMetaDialogState();
}

class _CriarMetaDialogState extends State<CriarMetaDialog> {
  final _nomeCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  String _iconeSelecionado = 'viagem';
  DateTime? _dataSelecionada;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _valorCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (data != null) setState(() => _dataSelecionada = data);
  }

  void _salvar() {
    final nome = _nomeCtrl.text.trim();
    final valorStr = _valorCtrl.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome da meta')),
      );
      return;
    }
    final valor = double.tryParse(valorStr.replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor valido')),
      );
      return;
    }

    Navigator.pop(
      context,
      Meta(
        nome: nome,
        icone: _iconeSelecionado,
        valorAlvo: valor,
        valorAtual: 0,
        dataAlvo: _dataSelecionada,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconeKeys = widget.iconeMetas.keys.toList();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: constraints.maxHeight * 0.85,
              maxWidth: 420,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: theme.colorScheme.primary, size: 22),
                      const SizedBox(width: 8),
                      const Text('Nova Meta', style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Content scrollable
                Flexible(
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _nomeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome da meta',
                            prefixIcon: Icon(Icons.flag),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _valorCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Valor alvo (R\$)',
                            prefixIcon: Icon(Icons.attach_money),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _selecionarData,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_dataSelecionada != null
                              ? '${_dataSelecionada!.day}/${_dataSelecionada!.month}/${_dataSelecionada!.year}'
                              : 'Data limite (opcional)'),
                        ),
                        const SizedBox(height: 16),
                        const Text('Escolha um icone:',
                            style: TextStyle(
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: iconeKeys.length,
                          itemBuilder: (ctx, idx) {
                            final key = iconeKeys[idx];
                            final selecionado = key == _iconeSelecionado;
                            return _GridItemIcones(
                              icone: widget.iconeMetas[key]['icone'],
                              label: widget.iconeMetas[key]['label'],
                              selecionado: selecionado,
                              onTap: () =>
                                  setState(() => _iconeSelecionado = key),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _salvar,
                          child: const Text('Criar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GridItemIcones extends StatelessWidget {
  final String icone;
  final String label;
  final bool selecionado;
  final VoidCallback onTap;

  const _GridItemIcones({
    required this.icone,
    required this.label,
    required this.selecionado,
    required this.onTap,
  });

  IconData _parseIcon(String name) {
    switch (name) {
      case 'flight': return Icons.flight;
      case 'directions_car': return Icons.directions_car;
      case 'house': return Icons.house;
      case 'school': return Icons.school;
      case 'phone_android': return Icons.phone_android;
      case 'favorite': return Icons.favorite;
      case 'pets': return Icons.pets;
      case 'star': default: return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selecionado
              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selecionado
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withOpacity(0.3),
            width: selecionado ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_parseIcon(icone), size: 22, color:
                selecionado ? Theme.of(context).colorScheme.primary : Colors.grey),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: selecionado
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Dialog valor deposito/retirada ---

class DialogValor extends StatefulWidget {
  final String titulo;
  final String subtitle;

  const DialogValor({
    super.key,
    required this.titulo,
    required this.subtitle,
  });

  @override
  State<DialogValor> createState() => _DialogValorState();
}

class _DialogValorState extends State<DialogValor> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.subtitle, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Valor (R\$)',
              prefixIcon: Icon(Icons.attach_money),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final valor = double.tryParse(_ctrl.text.trim().replaceAll(',', '.'));
            if (valor == null || valor <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Informe um valor valido')),
              );
              return;
            }
            Navigator.pop(context, valor);
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
