# 🚀 Flash-Dash: Inteligência de Negócios Automatizada

O **Flash-Dash** é uma plataforma de Business Intelligence (BI) focada em pequenas e médias empresas, projetada para transformar planilhas brutas em dashboards interativos e insights estratégicos em segundos. Utilizando o poder do **Python (FastAPI)** para o processamento de dados e **Flutter** para uma experiência de usuário fluida, o sistema integra o **Google Gemini AI** para oferecer uma análise consultiva em tempo real.

## ✨ Funcionalidades Principais

* **⚡ Processamento Inteligente:** Motor de limpeza automatizado que trata dados nulos, formata tipos e resolve inconsistências em arquivos Excel e CSV via Pandas.
* **🎨 Dashboard Canvas (Drag & Drop):** Uma área de trabalho livre onde o usuário pode adicionar múltiplos gráficos, movê-los, redimensioná-los e personalizar o visual (cores e títulos).
* **🤖 Analista IA Interativo:** Um chat integrado ao dashboard que recebe o contexto de todos os gráficos ativos. Você pode perguntar sobre tendências, causas de quedas nas vendas ou previsões baseadas nos dados reais.
* **📊 Visualização Avançada:** Suporte para gráficos de Barras, Colunas, Pizza e Rosca, com renderização reativa e cálculos de métricas em tempo real no frontend.
* **💡 Insights Automáticos:** Geração automática de um resumo executivo logo após o upload da fonte de dados.

## 🛠️ Tecnologias Utilizadas

### **Backend (Motor de Dados)**
* **Python 3.12+**: Linguagem base para manipulação de dados.
* **FastAPI**: Framework de alta performance para a API.
* **Pandas**: Biblioteca líder para limpeza e modelagem de dados.
* **Google Generative AI (Gemini SDK)**: Cérebro por trás dos insights e do chat inteligente.

### **Frontend (Interface)**
* **Flutter (Dart)**: Framework para interface multiplataforma (Web/Desktop).
* **FL Chart**: Biblioteca para renderização de gráficos complexos.
* **HTTP & File Picker**: Gestão de requisições e upload de arquivos.

## 📂 Estrutura do Projeto

```text
flash-dash-repository/
├── backend/                # API FastAPI e Lógica de Dados
│   ├── src/
│   │   ├── main.py         # Endpoints e rotas da API
│   │   ├── tratamento.py   # Motor de limpeza Pandas
│   │   └── ia_service.py   # Integração com Gemini AI
│   └── .env                # Chaves de API (não versionado)
└── frontend/               # Aplicativo Flutter
    ├── lib/
    │   ├── features/
    │   │   ├── dashboard/  # Canvas e Chat IA
    │   │   ├── upload/     # Gestão de fontes de dados
    │   │   └── resultado/  # Configuração de métricas
    │   └── main.dart       # Ponto de entrada