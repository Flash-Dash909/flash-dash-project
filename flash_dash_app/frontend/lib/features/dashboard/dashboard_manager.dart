import 'package:flutter/material.dart';

class ChartConfig {
  final String id;
  final String tipo;
  final String dimensao;
  final String metrica;
  final List<Map<String, dynamic>> dados;
  Offset posicao;
  Size tamanho;
  String titulo;
  Color corFundo;

  ChartConfig({
    required this.id,
    required this.tipo,
    required this.dimensao,
    required this.metrica,
    required this.dados,
    this.posicao = const Offset(50, 50),
    this.tamanho = const Size(350, 300),
    String? titulo,
    this.corFundo = Colors.white,
  }) : titulo = titulo ?? "$tipo: $dimensao vs $metrica";
}

class DashboardManager {
  static List<ChartConfig> graficosAtivos = [];
}