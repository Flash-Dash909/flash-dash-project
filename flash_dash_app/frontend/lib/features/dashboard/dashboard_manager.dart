import 'package:flutter/material.dart';

class ChartConfig {
  String id;
  String tipo;
  String titulo;
  String dimensao;
  String metrica;
  List<Map<String, dynamic>> dados;
  Offset posicao;
  Size tamanho;

  // --- NOVAS CONFIGURAÇÕES GERAIS (Estilo Power BI) ---
  Color corFundo;
  double fontSizeTitulo;
  String alinhamentoTitulo; // 'left', 'center', 'right'
  Color corTextoTitulo;
  double raioBorda;
  bool mostrarSombra;
  bool mostrarEixos; // Para esconder Eixo X e Y (deixar mais clean)
  bool mostrarLegenda;
  String posicaoLegenda;
  bool mostrarValores;
  bool mostrarRotulos;

  // Configurações Específicas
  Map<String, dynamic> configExtra;

  ChartConfig({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.dimensao,
    required this.metrica,
    required this.dados,
    required this.posicao,
    this.tamanho = const Size(350, 280),
    this.corFundo = Colors.white,
    this.fontSizeTitulo = 14.0,
    this.alinhamentoTitulo = 'left',
    this.corTextoTitulo = const Color(0xFF0F172A), // Slate escuro
    this.raioBorda = 12.0,
    this.mostrarSombra = true,
    this.mostrarEixos = true,
    this.mostrarLegenda = true,
    this.posicaoLegenda = 'bottom',
    this.mostrarValores = true,
    this.mostrarRotulos = true,
    Map<String, dynamic>? configExtra,
  }) : configExtra = configExtra ?? {} {
    if (this.configExtra.isEmpty) {
      if (tipo.contains('Pizza') || tipo.contains('Rosca')) {
        this.configExtra = {
          'raioFuro': tipo.contains('Rosca') ? 0.6 : 0.0,
          'mostrarPorcentagem': false,
          'espessuraFatia': 1.0,
        };
      }
    }
  }
}

class DashboardManager {
  static List<ChartConfig> graficosAtivos = [];
  static List<Map<String, dynamic>> dashboardsSalvos = [];
  static List<Map<String, String>> fontesSalvas = [];
  static Map<String, dynamic>? dadosFonteAtual;
  static String? dashboardAtualId;
}
