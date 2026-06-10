import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../upload/screens/upload_screen.dart'; 
import '../../dashboard/dashboard_manager.dart'; 
import '../../dashboard/screens/dashboard_canvas_screen.dart';
import '../../auth/screens/login_screen.dart'; // Ajuste a pasta se necessário

class HomeScreen extends StatefulWidget {
  final String usuarioNome; // <- Cria a variável que vai receber o nome
  final String usuarioId;

  // Atualiza o construtor para exigir o nome
  const HomeScreen({super.key, required this.usuarioNome, required this.usuarioId}); 

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceSelecionado = 0;

  // ==========================================
  // BUSCA OS DASHBOARDS DO BACKEND (SUPABASE)
  // ==========================================
  Future<List<dynamic>> _buscarDashboards() async {
    try {
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/listar-dashboards?usuario_id=${widget.usuarioId}'));
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }else {
        debugPrint("Erro do servidor ao buscar dashboards: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Erro ao buscar dashboards: $e");
    }
    return [];
  }

  // BUSCA OS LOGS DO BACKEND
  Future<List<dynamic>> _buscarLogsETL() async {
    try {
      var response = await http.get(Uri.parse('http://127.0.0.1:8000/listar-dashboards?usuario_id=${widget.usuarioId}'));
      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      debugPrint("Erro ao buscar logs ETL: $e");
    }
    return [];
  }

  void _iniciarNovoDashboard() {
    DashboardManager.graficosAtivos.clear();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UploadScreen(usuarioNome: widget.usuarioNome, usuarioId: widget.usuarioId)),
    );
  }

  void _fazerLogout() {
    // No futuro, se você salvar o ID do usuário no SharedPreferences, 
    // é aqui que você deve limpar os dados salvos antes de sair.
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  // Lógica para pegar o primeiro e o último nome
  String get _nomeExibicao {
    String nomeCompleto = widget.usuarioNome.trim();
    if (nomeCompleto.isEmpty) return "Usuário";
    
    List<String> partes = nomeCompleto.split(RegExp(r'\s+')); // Divide o nome pelos espaços
    if (partes.length <= 1) {
      return partes.first; // Se só tiver um nome, retorna ele mesmo
    }
    
    return "${partes.first} ${partes.last}"; // Retorna o Primeiro + Último
  }

  // ==========================================
  // MENU LATERAL (SIDEBAR) RESPONSIVO
  // ==========================================
  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.flash_on, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text("FLASH-DASH", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildMenuItem(Icons.dashboard_rounded, "Dashboards", 0),
          _buildMenuItem(Icons.source_rounded, "Fontes de Dados", 1),
          _buildMenuItem(Icons.receipt_long_rounded, "Logs ETL", 2),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text("SISTEMA", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ),
          _buildMenuItem(Icons.settings_suggest_rounded, "Configurações", 3),
          _buildMenuItem(Icons.person_outline_rounded, "Perfil", 4),
          const Spacer(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50, 
                  child: const Icon(Icons.person, color: Color(0xFF2563EB))
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // === TEXTO DINÂMICO AQUI ===
                      Text(
                        _nomeExibicao, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text("TCC - Apresentação", style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    ],
                  ),
                ),
                
                // === NOVO BOTÃO DE LOGOUT ===
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  tooltip: "Sair do sistema",
                  onPressed: () {
                    // Modal de confirmação para evitar cliques acidentais
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Sair do Flash Dash", style: TextStyle(fontWeight: FontWeight.bold)),
                        content: const Text("Tem certeza que deseja desconectar?"),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context), 
                            child: const Text("Cancelar", style: TextStyle(color: Colors.blueGrey))
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () {
                              Navigator.pop(context); // Fecha o modal
                              _fazerLogout();         // Chama a função que volta pro Login
                            },
                            child: const Text("Sair", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, int index) {
    bool isSelected = _indiceSelecionado == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
        title: Text(title, style: TextStyle(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B), fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
        onTap: () {
          setState(() => _indiceSelecionado = index);
          // Se estiver no celular, fecha a gaveta ao clicar
          if (MediaQuery.of(context).size.width < 800) {
            Navigator.pop(context);
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ==========================================
  // CONSTRUÇÃO DA TELA PRINCIPAL
  // ==========================================
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth >= 800;
    double paddingGlobal = isDesktop ? 40.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: !isDesktop 
        ? AppBar(title: const Text("FLASH-DASH", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white) 
        : null,
      drawer: !isDesktop ? Drawer(child: _buildSidebar()) : null,
      
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),

          Expanded(
            child: _indiceSelecionado == 0 
                ? _buildTelaDashboards(isDesktop, paddingGlobal)
                : _indiceSelecionado == 1
                    ? _buildTelaFontesDeDados(isDesktop, paddingGlobal)
                    : _indiceSelecionado == 2
                        ? _buildTelaLogsETL(isDesktop, paddingGlobal) // <--- CHAMA A TELA NOVA
                        : const Center(child: Text("Tela em construção...", style: TextStyle(color: Colors.blueGrey, fontSize: 18))),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ABA 0: TELA DOS DASHBOARDS (INTEGRADA AO SUPABASE)
  // ==========================================
  Widget _buildTelaDashboards(bool isDesktop, double paddingGlobal) {
    int crossAxisCount = isDesktop ? 3 : (MediaQuery.of(context).size.width >= 600 ? 2 : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: paddingGlobal, vertical: isDesktop ? 24 : 16),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Meus Dashboards", style: TextStyle(fontSize: isDesktop ? 28 : 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              ElevatedButton.icon(
                onPressed: _iniciarNovoDashboard,
                icon: const Icon(Icons.add),
                label: Text(isDesktop ? "Novo Dashboard" : "Novo"),
              )
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _buscarDashboards(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final dashboards = snapshot.data ?? [];
              
              if (dashboards.isEmpty) {
                return Center(
                  child: Text("Nenhum dashboard salvo na nuvem ainda.\nClique em Novo Dashboard para começar!", 
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 16))
                );
              }

              return GridView.builder(
                padding: EdgeInsets.all(paddingGlobal),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount, 
                  crossAxisSpacing: 16, 
                  mainAxisSpacing: 16, 
                  childAspectRatio: isDesktop ? 1.4 : 2.0,
                ),
                itemCount: dashboards.length,
                itemBuilder: (context, index) {
                  return _buildDashboardCard(dashboards[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ABA 1: TELA DAS FONTES DE DADOS (PLANILHAS)
  // ==========================================
  Widget _buildTelaFontesDeDados(bool isDesktop, double paddingGlobal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: paddingGlobal, vertical: isDesktop ? 24 : 16),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Fontes de Dados", style: TextStyle(fontSize: isDesktop ? 28 : 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              ElevatedButton.icon(
                onPressed: _iniciarNovoDashboard, 
                icon: const Icon(Icons.link),
                label: Text(isDesktop ? "Conectar Nova Fonte" : "Conectar"),
              )
            ],
          ),
        ),
        Expanded(
          child: DashboardManager.fontesSalvas.isEmpty
              ? Center(child: Text("Nenhuma planilha importada ainda nesta sessão.", style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 16)))
              : ListView.builder(
                  padding: EdgeInsets.all(paddingGlobal),
                  itemCount: DashboardManager.fontesSalvas.length,
                  itemBuilder: (context, index) {
                    final fonte = DashboardManager.fontesSalvas[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.table_view_rounded, color: Colors.green.shade600),
                        ),
                        title: Text(fonte['nome']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: Colors.blueGrey.shade400),
                              const SizedBox(width: 4),
                              Text(fonte['data']!, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12)),
                              const SizedBox(width: 16),
                              Icon(Icons.folder_open, size: 14, color: Colors.blueGrey.shade400),
                              const SizedBox(width: 4),
                              Text(fonte['tamanho']!, style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12)),
                            ],
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
                          child: Text(fonte['status']!, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // CARD DO DASHBOARD (COM LÓGICA DE ABRIR)
  // ==========================================
  Widget _buildDashboardCard(Map<String, dynamic> dash) {
    IconData getIcon(String iconeStr) {
      if (iconeStr == 'bar_chart') return Icons.bar_chart_rounded;
      if (iconeStr == 'pie_chart') return Icons.pie_chart_rounded;
      return Icons.dashboard_customize_rounded;
    }

    // O Supabase retorna a data como "2026-05-15T...", vamos formatar rápido:
    String dataFormatada = "Atualizado recentemente";
    if (dash['created_at'] != null) {
      try {
        DateTime dt = DateTime.parse(dash['created_at']);
        dataFormatada = "${dt.day}/${dt.month}/${dt.year}";
      } catch (e) {
        // Ignora e usa o padrão se der erro
      }
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // 1. Limpa o canvas atual
          DashboardManager.graficosAtivos.clear();
          
          // 2. Transforma o JSON do Supabase de volta em objetos ChartConfig
          List<dynamic> configDoBanco = dash['graficos_config'] ?? [];
          for (var item in configDoBanco) {
            DashboardManager.graficosAtivos.add(
              ChartConfig(
                id: item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                tipo: item['tipo'],
                titulo: item['titulo'],
                dimensao: item['dimensao'] ?? '',
                metrica: item['metrica'] ?? '',
                dados: List<Map<String, dynamic>>.from(item['dados']),
                posicao: Offset((item['posicao_x'] ?? 50).toDouble(), (item['posicao_y'] ?? 50).toDouble()),
                tamanho: Size((item['largura'] ?? 350).toDouble(), (item['altura'] ?? 280).toDouble()),
                corFundo: item['cor_fundo'] != null ? Color(int.parse(item['cor_fundo'])) : Colors.white,
                mostrarLegenda: item['mostrar_legenda'] ?? true,
                posicaoLegenda: item['posicao_legenda'] ?? 'bottom',
                configExtra: item['config_extra'] != null ? Map<String, dynamic>.from(item['config_extra']) : {},
                fontSizeTitulo: (item['font_size_titulo'] ?? 14.0).toDouble(),
                alinhamentoTitulo: item['alinhamento_titulo'] ?? 'left',
                corTextoTitulo: item['cor_texto_titulo'] != null ? Color(int.parse(item['cor_texto_titulo'])) : const Color(0xFF0F172A),
                raioBorda: (item['raio_borda'] ?? 12.0).toDouble(),
                mostrarSombra: item['mostrar_sombra'] ?? true,
                mostrarEixos: item['mostrar_eixos'] ?? true,
                mostrarValores: item['mostrar_valores'] ?? true,
                mostrarRotulos: item['mostrar_rotulos'] ?? true,
              ),
            );
          }

          // 3. Abre a tela do Dashboard já com os gráficos renderizados!
          Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardCanvasScreen(usuarioNome: widget.usuarioNome, usuarioId: widget.usuarioId)));
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                child: Icon(getIcon(dash['icone'] ?? 'dashboard_customize'), color: const Color(0xFF2563EB), size: 24),
              ),
              const Spacer(),
              Text(dash['titulo'] ?? 'Sem Título', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(dataFormatada, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }
  // ==========================================
  // ABA 2: TELA DE LOGS DE AUDITORIA (ETL)
  // ==========================================
  Widget _buildTelaLogsETL(bool isDesktop, double paddingGlobal) {
    IconData getIconParaFase(String? fase) {
      if (fase == null) return Icons.info_outline;
      if (fase.contains('Extração')) return Icons.cloud_download_rounded;
      if (fase.contains('Limpeza')) return Icons.cleaning_services_rounded;
      if (fase.contains('Filtragem')) return Icons.filter_alt_rounded;
      if (fase.contains('Padronização')) return Icons.spellcheck_rounded;
      if (fase.contains('Modelagem')) return Icons.account_tree_rounded;
      if (fase.contains('Carga') || fase.contains('Load')) return Icons.check_circle_rounded;
      return Icons.info_outline;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: paddingGlobal, vertical: isDesktop ? 24 : 16),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1))),
          child: Row(
            children: [
              Text("Auditoria de Dados (ETL)", style: TextStyle(fontSize: isDesktop ? 28 : 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _buscarLogsETL(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final fontes = snapshot.data ?? [];
              
              if (fontes.isEmpty) {
                return Center(
                  child: Text("Nenhum log de ETL encontrado.\nFaça o upload de uma planilha para gerar auditorias.", 
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 16))
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(paddingGlobal),
                itemCount: fontes.length,
                itemBuilder: (context, index) {
                  final fonte = fontes[index];
                  final List<dynamic> logs = fonte['etl_logs'] ?? [];
                  
                  // Formata a data de envio
                  String dataFormatada = "";
                  if (fonte['created_at'] != null) {
                    try {
                      DateTime dt = DateTime.parse(fonte['created_at']).toLocal();
                      dataFormatada = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                    } catch (e) {}
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                    elevation: 0,
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.receipt_long_rounded, color: Colors.indigo.shade600),
                        ),
                        title: Text(fonte['nome_arquivo'] ?? 'Arquivo Desconhecido', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text("Processado em: $dataFormatada", style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 13)),
                        children: [
                          Container(
                            color: const Color(0xFFF8FAFC),
                            padding: const EdgeInsets.all(24),
                            child: logs.isEmpty 
                              ? const Text("Sem logs detalhados para este arquivo.")
                              : Column(
                                  children: logs.map((log) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(getIconParaFase(log['fase']), color: const Color(0xFF2563EB), size: 20),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(log['fase'] ?? 'Etapa', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                                const SizedBox(height: 4),
                                                Text(log['descricao'] ?? '', style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13)),
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}