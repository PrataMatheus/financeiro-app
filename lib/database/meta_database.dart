import 'package:sqflite/sqflite.dart';
import '../models/meta.dart';

class MetaDatabase {
  static final MetaDatabase instance = MetaDatabase._init();

  MetaDatabase._init();

  // Recebe o database do AppDatabase e opera nele
  Future<void> criarTabelas(Database db) async {
    await db.execute('''
      CREATE TABLE metas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        icone TEXT NOT NULL,
        valorAlvo REAL NOT NULL,
        valorAtual REAL NOT NULL DEFAULT 0,
        dataAlvo TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE depositos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        metaId INTEGER NOT NULL,
        valor REAL NOT NULL,
        data TEXT NOT NULL,
        saida INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (metaId) REFERENCES metas(id) ON DELETE CASCADE
      )
    ''');
  }

  // CRUD Metas
  Future<Meta> inserir(Database db, Meta meta) async {
    final id = await db.insert('metas', meta.toMap());
    return meta.copyWith(id: id);
  }

  Future<List<Meta>> buscarTodos(Database db) async {
    final maps = await db.query('metas', orderBy: 'id ASC');
    return maps.map((m) => Meta.fromMap(m)).toList();
  }

  Future<int> atualizar(Database db, Meta meta) async {
    if (meta.id == null) return 0;
    return db.update('metas', meta.toMap(), where: 'id = ?', whereArgs: [meta.id]);
  }

  Future<int> excluir(Database db, int id) async {
    await db.delete('depositos', where: 'metaId = ?', whereArgs: [id]);
    return db.delete('metas', where: 'id = ?', whereArgs: [id]);
  }

  // Depositos
  Future<void> adicionarDeposito(Database db, Deposito deposito) async {
    await db.transaction((txn) async {
      await txn.insert('depositos', deposito.toMap());

      // Atualiza valorAtual da meta
      final metaMaps = await txn.query('metas', where: 'id = ?', whereArgs: [deposito.metaId]);
      if (metaMaps.isNotEmpty) {
        final meta = Meta.fromMap(metaMaps.first);
        final novoValor = deposito.saida
            ? meta.valorAtual - deposito.valor
            : meta.valorAtual + deposito.valor;
        await txn.update(
          'metas',
          {'valorAtual': novoValor < 0 ? 0 : novoValor},
          where: 'id = ?',
          whereArgs: [deposito.metaId],
        );
      }
    });
  }

  Future<List<Deposito>> buscarDepositos(Database db, int metaId) async {
    final maps = await db.query(
      'depositos',
      where: 'metaId = ?',
      whereArgs: [metaId],
      orderBy: 'data DESC',
    );
    return maps.map((m) => Deposito.fromMap(m)).toList();
  }

  Future<void> excluirDeposito(Database db, int id) async {
    await db.delete('depositos', where: 'id = ?', whereArgs: [id]);
  }

  // Estimativa
  Future<double?> estimativaDiasRestantes(Database db, Meta meta) async {
    final depositos = await buscarDepositos(db, meta.id!);
    final apenasDepositos = depositos.where((d) => !d.saida).toList();

    if (apenasDepositos.length < 2) return null;

    // Usa os últimos depósitos para calcular média diária
    final recentes = apenasDepositos.take(5).toList().reversed.toList();

    if (recentes.length < 2) return null;

    final dias = recentes.first.data.difference(recentes.last.data).inDays;
    if (dias <= 0) return null;

    final totalDepositado = recentes.fold<double>(0, (sum, d) => sum + d.valor);
    final mediaDiaria = totalDepositado / dias;

    if (mediaDiaria <= 0) return null;

    final restante = meta.valorAlvo - meta.valorAtual;
    if (restante <= 0) return 0;

    return restante / mediaDiaria;
  }
}
