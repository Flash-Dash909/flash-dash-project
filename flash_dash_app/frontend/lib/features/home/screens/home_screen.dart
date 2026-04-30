import 'package:flutter/material.dart';
import '../../upload/screens/upload_screen.dart'; // Ajuste se o caminho for diferente

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceSelecionado = 0;

  // Nossa "Base de Dados" temporária na memória
  final List<Map<String, String>> _meusDashboards = [
    {"titulo": "Análise de Vendas Q1", "data": "Atualizado ontem", "icone": "bar_chart"},
    {"titulo": "Desempenho Regional", "data": "Atualizado há 3 dias", "icone": "pie_chart"},
    {"titulo": "Campanha de Marketing", "data": "Atualizado na semana passada", "icone": "show_chart"},
  ];

  void _simularCriacaoDashboard() {
    // Adiciona um mock na lista para o usuário ver funcionando
    setState(() {
      _meusDashboards.insert(0, {
        "titulo": "Novo Dashboard ${DateTime.now().second}",
        "data": "Criado agora mesmo",
        "icone": "dashboard_customize"
      });
    });

    // Navega para a tela de subir a planilha
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UploadScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Fundo principal cinza/azul clarinho
      body: Row(
        children: [
          // ==========================================
          // 1. MENU LATERAL (SIDEBAR) BEM CLEAN E PROFISSIONAL
          // ==========================================
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo / Título
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.flash_on, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "FLASH-DASH",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Opções do Menu
                _buildMenuItem(Icons.dashboard_rounded, "Dashboards", 0),
                _buildMenuItem(Icons.source_rounded, "Fontes de Dados", 1),
                _buildMenuItem(Icons.receipt_long_rounded, "Logs ETL", 2),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text("SISTEMA", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                ),
                
                _buildMenuItem(Icons.settings_suggest_rounded, "Configurações", 3),
                _buildMenuItem(Icons.person_outline_rounded, "Perfil", 4),
                _buildMenuItem(Icons.account_balance_wallet_outlined, "Conta", 5),
                
                const Spacer(),
                // Perfil do Usuário no rodapé
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: const Icon(Icons.person, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Rogério Bruno", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text("Plano Premium", style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          ),

          // ==========================================
          // 2. ÁREA PRINCIPAL (CABEÇALHO + GRID)
          // ==========================================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CABEÇALHO SUPERIOR
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Meus Dashboards",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      ElevatedButton.icon(
                        onPressed: _simularCriacaoDashboard,
                        icon: const Icon(Icons.add),
                        label: const Text("Novo Dashboard"),
                      )
                    ],
                  ),
                ),

                // GRID DOS DASHBOARDS
                Expanded(
                  child: _indiceSelecionado == 0 
                    ? GridView.builder(
                        padding: const EdgeInsets.all(40),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, // Quantos cartões por linha
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          childAspectRatio: 1.4, // Proporção do cartão (mais largo que alto)
                        ),
                        itemCount: _meusDashboards.length,
                        itemBuilder: (context, index) {
                          return _buildDashboardCard(_meusDashboards[index]);
                        },
                      )
                    : const Center(
                        child: Text(
                          "Tela em construção...",
                          style: TextStyle(color: Colors.blueGrey, fontSize: 18),
                        ),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget para os itens do Menu Lateral
  Widget _buildMenuItem(IconData icon, String title, int index) {
    bool isSelected = _indiceSelecionado == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent, // Fundo azul se selecionado
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon, 
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B)
        ),
        title: Text(
          title, 
          style: TextStyle(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B), 
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        onTap: () => setState(() => _indiceSelecionado = index),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Widget para os quadrados dos Dashboards criados
  Widget _buildDashboardCard(Map<String, String> dash) {
    IconData getIcon(String iconeStr) {
      if (iconeStr == 'bar_chart') return Icons.bar_chart_rounded;
      if (iconeStr == 'pie_chart') return Icons.pie_chart_rounded;
      if (iconeStr == 'show_chart') return Icons.show_chart_rounded;
      return Icons.dashboard_customize_rounded;
    }

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      child: InkWell( // Efeito de clique no cartão
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Aqui no futuro você abriria o dashboard salvo do banco de dados
        },
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF), // Fundo azul claro pro ícone
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(getIcon(dash['icone']!), color: const Color(0xFF2563EB), size: 28),
              ),
              const Spacer(),
              Text(
                dash['titulo']!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                dash['data']!,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}