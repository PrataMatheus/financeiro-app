import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transacao.dart';
import 'meta_database.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initializarDB();
    return _database!;
  }

  Future<Database> _initializarDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'financeiro.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transacoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT NOT NULL,
        valor REAL NOT NULL,
        tipo TEXT NOT NULL,
        categoria TEXT NOT NULL,
        data TEXT NOT NULL,
        observacao TEXT
      )
    ''');

    await MetaDatabase.instance.criarTabelas(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await MetaDatabase.instance.criarTabelas(db);
    }
  }

  // CRUD Transacoes
  Future<Transacao> inserir(Transacao transacao) async {
    final db = await database;
    final id = await db.insert('transacoes', transacao.toMap());
    return transacao.copyWith(id: id);
  }

  Future<Transacao> buscarPorId(int id) async {
    final db = await database;
    final maps = await db.query(
      'transacoes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) throw Exception('Transacao nao encontrada');
    return Transacao.fromMap(maps.first);
  }

  Future<List<Transacao>> buscarTodos({DateTime? dataInicio, DateTime? dataFim}) async {
    final db = await database;
    var query = db.query(
      'transacoes',
      orderBy: 'data DESC',
    );

    if (dataInicio != null || dataFim != null) {
      String where = '';
      List<dynamic> args = [];
      if (dataInicio != null) {
        where = 'data >= ?';
        args.add(dataInicio.toIso8601String());
      }
      if (dataFim != null) {
        if (where.isNotEmpty) where += ' AND ';
        where += 'data <= ?';
        args.add(dataFim.toIso8601String());
      }
      query = db.query(
        'transacoes',
        where: where,
        whereArgs: args,
        orderBy: 'data DESC',
      );
    }

    return (await query).map((map) => Transacao.fromMap(map)).toList();
  }

  Future<int> atualizar(Transacao transacao) async {
    final db = await database;
    return db.update(
      'transacoes',
      transacao.toMap(),
      where: 'id = ?',
      whereArgs: [transacao.id],
    );
  }

  Future<int> excluir(int id) async {
    final db = await database;
    return db.delete(
      'transacoes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, double>> resumMes(DateTime mes) async {
    final inicioMes = DateTime(mes.year, mes.month, 1);
    final fimMes = DateTime(mes.year, mes.month + 1, 0, 23, 59, 59);
    final transacoes = await buscarTodos(dataInicio: inicioMes, dataFim: fimMes);

    double entradas = 0;
    double saidas = 0;

    for (final t in transacoes) {
      if (t.tipo == TipoTransacao.entrada) {
        entradas += t.valor;
      } else {
        saidas += t.valor;
      }
    }

    return {
      'entradas': entradas,
      'saidas': saidas,
      'saldo': entradas - saidas,
    };
  }

  Future<Map<String, double>> gastosPorCategoria(DateTime mes) async {
    final inicioMes = DateTime(mes.year, mes.month, 1);
    final fimMes = DateTime(mes.year, mes.month + 1, 0, 23, 59, 59);
    final transacoes = await buscarTodos(dataInicio: inicioMes, dataFim: fimMes);

    Map<String, double> categorias = {};
    for (final t in transacoes) {
      if (t.tipo == TipoTransacao.saida) {
        categorias[t.categoria] = (categorias[t.categoria] ?? 0) + t.valor;
      }
    }

    // Ordena por valor descendente
    final itensOrdenados = categorias.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(itensOrdenados);
  }

  Future<void> fechar() async {
    final db = await database;
    await db.close();
  }
}
