import 'package:flutter/material.dart';

import '../../core/calculated_metric.dart';
import '../../core/visual_config.dart';

class ChartConfig {
  String id;
  String tipo;
  String titulo;
  String dimensao;
  String metrica;
  List<Map<String, dynamic>> dados;
  Offset posicao;
  Size tamanho;
  int pagina;

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
    this.pagina = 0,
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
  }) : configExtra = PowerBiVisualConfig.merge(tipo, configExtra);
}

class DashboardManager {
  static List<ChartConfig> graficosAtivos = [];
  static Map<String, CalculatedMetric> metricasCalculadas = {};
  static List<Map<String, dynamic>> dashboardsSalvos = [];
  static List<Map<String, String>> fontesSalvas = [];
  static List<Map<String, dynamic>> fontesDashboard = [];
  static Map<String, dynamic>? dadosFonteAtual;
  static String? dashboardAtualId;
  static List<String> paginasDashboard = <String>['Pagina 1'];
  static int paginaAtual = 0;
  static String? usuarioAtualId;
  static String? tokenAutenticacao;

  static Map<String, String> get authHeaders {
    final token = tokenAutenticacao;
    return token == null || token.isEmpty
        ? <String, String>{}
        : <String, String>{'Authorization': 'Bearer $token'};
  }

  static String? usuarioAtualNome;
  static String? usuarioAtualEmail;
  static int? usuarioAtualIdade;
  static String? usuarioAtualTelefone;
  static String? usuarioAtualCargo;
  static String? usuarioAtualEmpresa;
  static String? usuarioAtualBio;
  static String? usuarioAtualFoto;

  static String get nomePaginaAtual =>
      paginasDashboard[paginaAtual
          .clamp(0, paginasDashboard.length - 1)
          .toInt()];

  static void resetarPaginas() {
    paginasDashboard = <String>['Pagina 1'];
    paginaAtual = 0;
  }

  static String? fonteIdDe(Map<String, dynamic>? data) {
    final fonte = data?['fonte'];
    if (fonte is Map && fonte['id'] != null) return fonte['id'].toString();
    final id = data?['fonte_id'];
    return id?.toString();
  }

  static String nomeFonteDe(Map<String, dynamic> data) {
    final fonte = data['fonte'];
    if (fonte is Map) {
      final nome = fonte['nome_arquivo'] ?? fonte['nome'];
      if (nome != null && nome.toString().trim().isNotEmpty) {
        return nome.toString();
      }
    }
    return 'Fonte de dados';
  }

  static Map<String, dynamic>? fonteDashboardPorId(String? fonteId) {
    if (fonteId == null) return null;
    for (final data in fontesDashboard) {
      if (fonteIdDe(data) == fonteId) return data;
    }
    return null;
  }

  static void registrarFonteDashboard(
    Map<String, dynamic> data, {
    bool tornarAtiva = true,
  }) {
    final fonteId = fonteIdDe(data);
    if (fonteId != null) {
      fontesDashboard.removeWhere((item) => fonteIdDe(item) == fonteId);
      fontesDashboard.add(data);
    }
    if (tornarAtiva) dadosFonteAtual = data;
  }

  static void ativarFonteDashboard(String fonteId) {
    final data = fonteDashboardPorId(fonteId);
    if (data != null) dadosFonteAtual = data;
  }

  static List<String> get fonteIdsDashboard => fontesDashboard
      .map(fonteIdDe)
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  static void limparFontesDashboard() {
    fontesDashboard.clear();
    dadosFonteAtual = null;
  }

  static void restaurarPaginas(List<String> nomes, {int pagina = 0}) {
    final validos = nomes
        .map((nome) => nome.trim())
        .where((nome) => nome.isNotEmpty)
        .toList();
    paginasDashboard = validos.isEmpty ? <String>['Pagina 1'] : validos;
    paginaAtual = pagina.clamp(0, paginasDashboard.length - 1).toInt();
  }
}
