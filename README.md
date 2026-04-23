# ⚡📊 Flash-Dash

O **Flash-Dash** é um projeto universitário focado na democratização do Business Intelligence (BI). O sistema automatiza processos de dados para oferecer dashboards ágeis e de baixo custo, ideal para **Pequenas e Médias Empresas (PMEs)** e **Analistas de Dados**. 

Com a recente integração de Inteligência Artificial Generativa, a plataforma não apenas exibe gráficos, mas atua como um consultor interativo de dados.

---

## ✨ Funcionalidades Principais (Novidades)

* **🧹 Processamento Inteligente:** Motor de limpeza automatizado (Pandas) que trata dados brutos de planilhas (Excel/CSV) em segundos.
* **🎨 Dashboard Canvas (Drag & Drop):** Área de trabalho livre no Flutter onde o usuário pode adicionar, mover, redimensionar e personalizar múltiplos gráficos (Barras, Colunas, Pizza e Rosca).
* **🤖 Analista IA Interativo:** Chat integrado ao dashboard alimentado pelo **Google Gemini**. A IA lê o contexto dos gráficos visíveis na tela e responde a perguntas analíticas de negócios em tempo real.

---

## 🛠️ Stack Tecnológica

* **Front-End:** [Flutter](https://flutter.dev/) com FL Chart (UI/UX Responsivo e Dashboards Interativos)
* **Back-End:** [Python](https://www.python.org/) com [FastAPI](https://fastapi.tiangolo.com/) e Pandas (Motor de BI)
* **Inteligência Artificial:** Google Generative AI (Gemini SDK)
* **Banco de Dados:** [Supabase](https://supabase.com/) (Backend-as-a-Service)

---

## 📂 Estrutura do Repositório (Monorepo)

* `core/backend/`: Motor de processamento em Python, IA e API REST.
* `core/frontend/`: Interface mobile/web/desktop em Flutter.
* `docs/`: Requisitos, cronogramas e documentação acadêmica.

---

## 🚀 Como Executar o Projeto

### Pré-requisitos
* Python 3.12+
* Flutter SDK
* Git

### 🐍 Configurando o Back-End (Motor de BI e IA)
1. Acesse a pasta: `cd core/backend`
2. Crie o ambiente virtual: `python -m venv .venv`
3. Ative o ambiente: 
   * Windows: `.\.venv\Scripts\activate`
   * Mac/Linux: `source .venv/bin/activate`
4. Instale as dependências: `pip install -r requirements.txt` *(certifique-se de ter fastapi, uvicorn, pandas, google-genai, python-dotenv)*
5. Configure as variáveis de ambiente: Crie um arquivo `.env` na raiz do backend e adicione sua chave de IA: `GEMINI_API_KEY=sua_chave_aqui`
6. Inicie o servidor: `uvicorn src.main:app --reload`
   * Acompanhe a documentação automática em: `http://127.0.0.1:8000/docs`

### 💙 Configurando o Front-End (Flutter)
1. Acesse a pasta: `cd core/frontend`
2. Obtenha os pacotes: `flutter pub get`
3. Execute o app (Web ou Desktop recomendado para testes de UI): `flutter run -d chrome`

---

## 🔌 Documentação da API (Endpoints Principais)

O motor utiliza o padrão **OpenAPI (Swagger)**.
* `GET /`: Status geral do sistema.
* `GET /api/v1/health`: Verificação de saúde para QA.
* `POST /analisar-planilha`: Recebe o arquivo (CSV/Excel), executa a limpeza dos dados com Pandas e retorna as colunas mapeadas e agregações.
* `POST /chat-ia`: Recebe a pergunta do usuário e o contexto atual do dashboard (JSON), retornando a análise do Gemini AI.

---

## 👥 Equipe e Stakeholders

| Nome | Função | Responsabilidades |
| :--- | :--- | :--- |
| **Rogério Bruno** | Gerente de Projeto / Líder Técnico | Arquitetura, Motor de BI, Integração de IA e Gerenciamento. |
| **Amanda Evellin** | Desenvolvedora Fullstack | UI/UX e Componentes Visuais do Dashboard. |
| **Pedro Enrique** | Desenvolvedor Fullstack | Qualidade, Tratamento de Dados e Testes Automatizados. |
| **Ronnison Reges** | Professor Orientador | Acompanhamento Metodológico e Avaliação do TCC. |

---
*Status: 🟡 Fase de Desenvolvimento: Processamento Pandas, UI do Dashboard e Analista IA Integrados.*