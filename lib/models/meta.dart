class Meta {
  final int? id;
  final String nome;
  final String icone; // chave do icone (ex: 'plane', 'car', 'house')
  final double valorAlvo;
  final double valorAtual;
  final DateTime? dataAlvo;

  Meta({
    this.id,
    required this.nome,
    required this.icone,
    required this.valorAlvo,
    required this.valorAtual,
    this.dataAlvo,
  });

  double get percentual => valorAlvo > 0 ? (valorAtual / valorAlvo * 100) : 0;
  bool get completa => valorAtual >= valorAlvo;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'icone': icone,
      'valorAlvo': valorAlvo,
      'valorAtual': valorAtual,
      'dataAlvo': dataAlvo?.toIso8601String(),
    };
  }

  factory Meta.fromMap(Map<String, dynamic> map) {
    return Meta(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      icone: map['icone'] as String,
      valorAlvo: map['valorAlvo'] as double,
      valorAtual: map['valorAtual'] as double,
      dataAlvo: map['dataAlvo'] != null
          ? DateTime.parse(map['dataAlvo'] as String)
          : null,
    );
  }

  Meta copyWith({
    int? id,
    String? nome,
    String? icone,
    double? valorAlvo,
    double? valorAtual,
    DateTime? dataAlvo,
  }) {
    return Meta(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      icone: icone ?? this.icone,
      valorAlvo: valorAlvo ?? this.valorAlvo,
      valorAtual: valorAtual ?? this.valorAtual,
      dataAlvo: dataAlvo ?? this.dataAlvo,
    );
  }
}

class Deposito {
  final int? id;
  final int metaId;
  final double valor;
  final DateTime data;
  final bool saida; // true = retirou dinheiro da meta

  Deposito({
    this.id,
    required this.metaId,
    required this.valor,
    required this.data,
    this.saida = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'metaId': metaId,
      'valor': valor,
      'data': data.toIso8601String(),
      'saida': saida ? 1 : 0,
    };
  }

  factory Deposito.fromMap(Map<String, dynamic> map) {
    return Deposito(
      id: map['id'] as int?,
      metaId: map['metaId'] as int,
      valor: map['valor'] as double,
      data: DateTime.parse(map['data'] as String),
      saida: map['saida'] == 1,
    );
  }
}

const iconeMetas = {
  'viagem': {'icone': 'flight', 'label': 'Viagem'},
  'carro': {'icone': 'directions_car', 'label': 'Carro'},
  'casa': {'icone': 'house', 'label': 'Casa'},
  'estudos': {'icone': 'school', 'label': 'Estudos'},
  'tech': {'icone': 'phone_android', 'label': 'Tech'},
  'saude': {'icone': 'favorite', 'label': 'Saude'},
  'reserva': {'icone': 'pets', 'label': 'Reserva'},
  'outro': {'icone': 'star', 'label': 'Outro'},
};
