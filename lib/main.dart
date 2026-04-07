import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'models/transacao.dart';
import 'database/app_database.dart';
import 'providers/theme_provider.dart';
import 'screens/met_screen.dart';

void main() {
  runApp(MyApp(themeProvider: ThemeProvider()));
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const MyApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeProvider,
      builder: (context, mode, _) => MaterialApp(
        title: 'Controle Financeiro',
        debugShowCheckedModeBanner: false,
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: mode,
        home: MainShell(themeProvider: themeProvider),
      ),
    );
  }

  ThemeData get _lightTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      );

  ThemeData get _darkTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF388E3C),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      );
}

class MainShell extends StatefulWidget {
  final ThemeProvider themeProvider;

  const MainShell({super.key, required this.themeProvider});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _homeKey = GlobalKey<_HomePageState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(key: _homeKey, themeProvider: widget.themeProvider),
          const PoupancaPage(),
          const MetasScreen(),
          const PerfilPage(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _homeKey.currentState?._abrirDialogoTransacao(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        height: 56,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SafeArea(
          top: false,
          bottom: true,
          child: Row(
            children: [
              _barItem(Icons.home_outlined, Icons.home, 0, 'Inicio'),
              _barItem(Icons.savings_outlined, Icons.savings, 1, 'Poupanca'),
              const Expanded(child: SizedBox()),
              _barItem(Icons.flag_outlined, Icons.flag, 2, 'Metas'),
              _barItem(Icons.person_outline, Icons.person, 3, 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barItem(IconData icon, IconData selected, int page, String label) {
    final ativo = _index == page;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = page),
        child: Icon(
          ativo ? selected : icon,
          color: ativo ? Theme.of(context).colorScheme.primary : Colors.grey,
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final ThemeProvider themeProvider;

  const HomePage({super.key, required this.themeProvider});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _db = AppDatabase.instance;
  List<Transacao> _transacoes = [];
  Map<String, double> _resumo = {'entradas': 0, 'saidas': 0, 'saldo': 0};
  Map<String, double> _gastosCategoria = {};


  @override
  void initState() {
    super.initState();
    _carregarDados();
  }


  Future<void> _carregarDados() async {
    final now = DateTime.now();
    final mes = DateTime(now.year, now.month);
    final transacoes = await _db.buscarTodos(
      dataInicio: DateTime(mes.year, mes.month, 1),
      dataFim: DateTime(mes.year, mes.month + 1, 0, 23, 59, 59),
    );
    final resumo = await _db.resumMes(mes);
    final gastosCategoria = await _db.gastosPorCategoria(mes);
    setState(() {
      _transacoes = transacoes;
      _resumo = resumo;
      _gastosCategoria = gastosCategoria;
    });
  }

  String _formatarMoeda(double valor) {
    final partes = valor.toStringAsFixed(2).split('.');
    final inteiros = int.parse(partes[0]);
    final decimais = partes[1];
    final inteirosFormatados = inteiros.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'R\$ $inteirosFormatados,$decimais';
  }

  Color _corCategoria(String categoria) {
    const cores = {
      'Alimentacao': Colors.orange,
      'Transporte': Colors.blue,
      'Moradia': Colors.purple,
      'Lazer': Colors.teal,
      'Saude': Colors.red,
      'Salario': Colors.green,
      'Outros': Colors.grey,
    };
    return cores[categoria] ?? Colors.grey;
  }

  Future<void> _abrirDialogoTransacao({Transacao? transacaoExistente}) async {
    _descricaoCtrl.clear();
    _valorCtrl.clear();
    _tipoSelecionado = 'entrada';
    _categoriaSelecionada = 'Alimentacao';

    if (transacaoExistente != null) {
      _descricaoCtrl.text = transacaoExistente.descricao;
      _valorCtrl.text = transacaoExistente.valor.toString().replaceAll('.', ',');
      _tipoSelecionado = transacaoExistente.tipo.name;
      _categoriaSelecionada = transacaoExistente.categoria;
    }

    if (!mounted) return;
    final result = await showDialog<TransacaoData>(
      context: context,
      builder: (ctx) => TransacaoDialog(
        transacao: transacaoExistente,
        categorias: _categorias,
        descricaoInicial: _descricaoCtrl.text,
        valorInicial: _valorCtrl.text,
        tipoInicial: _tipoSelecionado,
        categoriaInicial: _categoriaSelecionada,
      ),
    );

    if (result != null) {
      if (transacaoExistente != null) {
        await _db.atualizar(transacaoExistente.copyWith(
          descricao: result.descricao,
          valor: result.valor,
          tipo: result.tipo,
          categoria: result.categoria,
        ));
      } else {
        await _db.inserir(Transacao(
          descricao: result.descricao,
          valor: result.valor,
          tipo: result.tipo,
          categoria: result.categoria,
          data: DateTime.now(),
        ));
      }
      await _carregarDados();
    }
  }

  final _descricaoCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  String _tipoSelecionado = 'entrada';
  String _categoriaSelecionada = 'Alimentacao';
  final _categorias = [
    'Alimentacao', 'Transporte', 'Moradia', 'Lazer', 'Saude', 'Salario', 'Outros'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    const meses = [
      'Janeiro', 'Fevereiro', 'Marco', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final mesAtual = '${meses[now.month - 1]} ${now.year}';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Controle Financeiro',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              mesAtual.toUpperCase(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: widget.themeProvider,
            builder: (_, mode, __) {
              final isDark = mode == ThemeMode.dark;
              return IconButton(
                icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                tooltip: isDark ? 'Modo claro' : 'Modo escuro',
                onPressed: () => widget.themeProvider.toggle(),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20).copyWith(
          top: 0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: PageView(
                children: [
                  _buildOrcamentoCard(theme.colorScheme),
                  _buildGraficoPizzaCard(theme.colorScheme),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildResumoRapido(theme.colorScheme),
            const SizedBox(height: 24),
            Text(
              'Transacoes Recentes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_transacoes.isEmpty)
              _buildTransacaoVazia(theme.colorScheme,
                  'Nenhuma transacao ainda', 'Toque no + para adicionar')
            else
              ..._transacoes.map((t) => _buildTransacaoItem(t, theme.colorScheme)).toList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirDialogoTransacao(),
        backgroundColor: theme.colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nova', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildOrcamentoCard(ColorScheme cm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Orcamento do Mes',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatarMoeda(_resumo['saldo'] ?? 0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniInfo(Icons.arrow_downward, 'Receitas',
                  _formatarMoeda(_resumo['entradas'] ?? 0)),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withOpacity(0.3),
              ),
              _buildMiniInfo(Icons.arrow_upward, 'Despesas',
                  _formatarMoeda(_resumo['saidas'] ?? 0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfo(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildResumoRapido(ColorScheme theme) {
    return Row(
      children: [
        Expanded(
          child: _buildCardRapido(
            theme,
            Icons.trending_up,
            'Entradas',
            _formatarMoeda(_resumo['entradas'] ?? 0),
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCardRapido(
            theme,
            Icons.trending_down,
            'Saidas',
            _formatarMoeda(_resumo['saidas'] ?? 0),
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildCardRapido(
      ColorScheme theme, IconData icon, String label, String value, Color cor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cor, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransacaoItem(Transacao t, ColorScheme cm) {
    final cor = t.tipo == TipoTransacao.entrada ? Colors.green : Colors.red;
    final sinal = t.tipo == TipoTransacao.entrada ? '+' : '-';
    const dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab'];

    return Dismissible(
      key: Key('transacao_${t.id}'),
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return _confirmarExclusao();
      },
      child: GestureDetector(
        onTap: () => _abrirDialogoTransacao(transacaoExistente: t),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: _corCategoria(t.categoria),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.descricao,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${dias[t.data.weekday % 7]}, ${t.data.day}/${t.data.month}',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _corCategoria(t.categoria).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            t.categoria,
                            style: TextStyle(
                              color: _corCategoria(t.categoria),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '$sinal ${_formatarMoeda(t.valor)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: cor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmarExclusao() async {
    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir transacao'),
        content: const Text('Tem certeza que deseja excluir esta transacao?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildTransacaoVazia(
      ColorScheme theme, String titulo, String subtitulo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGraficoPizzaCard(ColorScheme cm) {
    final itens = _gastosCategoria.entries.toList();
    final total = _resumo['saidas'] ?? 0;

    if (itens.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'Sem gastos para exibir',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              'Adicione transacoes de saida',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      );
    }

    final sections = itens.map((e) {
      final percent = total > 0 ? (e.value / total * 100) : 0.0;
      return PieChartSectionData(
        value: e.value,
        color: _corCategoria(e.key),
        title: '${percent.toStringAsFixed(0)}%',
        radius: 55,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Gastos por Categoria',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 25,
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: itens.map((e) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _corCategoria(e.key),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    e.key,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// --- Dialog para criar/editar transacao ---

class TransacaoData {
  final String descricao;
  final double valor;
  final TipoTransacao tipo;
  final String categoria;

  TransacaoData({
    required this.descricao,
    required this.valor,
    required this.tipo,
    required this.categoria,
  });
}

class TransacaoDialog extends StatefulWidget {
  final Transacao? transacao;
  final List<String> categorias;
  final String descricaoInicial;
  final String valorInicial;
  final String tipoInicial;
  final String categoriaInicial;

  const TransacaoDialog({
    super.key,
    this.transacao,
    required this.categorias,
    this.descricaoInicial = '',
    this.valorInicial = '',
    this.tipoInicial = 'entrada',
    this.categoriaInicial = 'Alimentacao',
  });

  bool get isEdit => transacao != null;

  @override
  State<TransacaoDialog> createState() => _TransacaoDialogState();
}

class _TransacaoDialogState extends State<TransacaoDialog> {
  late final TextEditingController _descricaoCtrl;
  late final TextEditingController _valorCtrl;
  late String _tipoSelecionado;
  late String _categoriaSelecionada;

  @override
  void initState() {
    super.initState();
    _descricaoCtrl = TextEditingController(text: widget.descricaoInicial);
    _valorCtrl = TextEditingController(text: widget.valorInicial);
    _tipoSelecionado = widget.tipoInicial;
    _categoriaSelecionada = widget.categoriaInicial;
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  void _salvar() {
    final desc = _descricaoCtrl.text.trim();
    final valorStr = _valorCtrl.text.trim();
    if (desc.isEmpty || valorStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha descricao e valor')),
      );
      return;
    }
    final valor = double.tryParse(valorStr.replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor invalido')),
      );
      return;
    }

    Navigator.pop(
      context,
      TransacaoData(
        descricao: desc,
        valor: valor,
        tipo: _tipoSelecionado == 'entrada'
            ? TipoTransacao.entrada
            : TipoTransacao.saida,
        categoria: _categoriaSelecionada,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isEdit ? 'Editar Transacao' : 'Nova Transacao',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _descricaoCtrl,
              decoration: const InputDecoration(
                labelText: 'Descricao',
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valorCtrl,
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'entrada',
                    label: Text('Entrada'),
                    icon: Icon(Icons.arrow_downward, color: Colors.green)),
                ButtonSegment(
                    value: 'saida',
                    label: Text('Saida'),
                    icon: Icon(Icons.arrow_upward, color: Colors.red)),
              ],
              selected: {_tipoSelecionado},
              onSelectionChanged: (s) {
                setState(() => _tipoSelecionado = s.first);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _categoriaSelecionada,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: widget.categorias
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _categoriaSelecionada = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _salvar,
          child: Text(widget.isEdit ? 'Atualizar' : 'Salvar'),
        ),
      ],
    );
  }
}

// --- Pagina Poucanca ---

class PoupancaPage extends StatelessWidget {
  const PoupancaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.savings, size: 64, color: Colors.green[700]),
              const SizedBox(height: 16),
              const Text(
                'Poupanca',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Aqui voce vai ver o dinheiro reservado\nmeses anteriores',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Placeholder ---

class PlaceholderPage extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;

  const PlaceholderPage({
    super.key,
    required this.icone,
    required this.titulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              descricao,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Pagina Perfil ---

class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: const Text('Usuario'),
            subtitle: Text(dark ? 'Modo escuro ativo' : 'Modo claro ativo'),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Modo escuro'),
            subtitle: const Text('Desliga o tema padrao do sistema'),
            value: dark,
            onChanged: (_) {
              final provider = context.findAncestorWidgetOfExactType<MainShell>()
                  ?.themeProvider;
              provider?.toggle();
            },
          ),
        ],
      ),
    );
  }
}
