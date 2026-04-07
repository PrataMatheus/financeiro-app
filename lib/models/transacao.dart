class Transacao {
  final int? id;
  final String descricao;
  final double valor;
  final TipoTransacao tipo; // entrada ou saida
  final String categoria;
  final DateTime data;
  final String? observacao;

  Transacao({
    this.id,
    required this.descricao,
    required this.valor,
    required this.tipo,
    required this.categoria,
    required this.data,
    this.observacao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descricao': descricao,
      'valor': valor,
      'tipo': tipo.name,
      'categoria': categoria,
      'data': data.toIso8601String(),
      'observacao': observacao,
    };
  }

  factory Transacao.fromMap(Map<String, dynamic> map) {
    return Transacao(
      id: map['id'] as int?,
      descricao: map['descricao'] as String,
      valor: map['valor'] as double,
      tipo: map['tipo'] == 'saida' ? TipoTransacao.saida : TipoTransacao.entrada,
      categoria: map['categoria'] as String,
      data: DateTime.parse(map['data'] as String),
      observacao: map['observacao'] as String?,
    );
  }

  Transacao copyWith({
    int? id,
    String? descricao,
    double? valor,
    TipoTransacao? tipo,
    String? categoria,
    DateTime? data,
    String? observacao,
  }) {
    return Transacao(
      id: id ?? this.id,
      descricao: descricao ?? this.descricao,
      valor: valor ?? this.valor,
      tipo: tipo ?? this.tipo,
      categoria: categoria ?? this.categoria,
      data: data ?? this.data,
      observacao: observacao ?? this.observacao,
    );
  }
}

enum TipoTransacao { entrada, saida }
