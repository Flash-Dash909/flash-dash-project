# Flash-Dash

O Flash-Dash e uma plataforma de Business Intelligence voltada a transformar
fontes de dados brutas em tabelas tratadas, modelos estrela e dashboards
interativos. O projeto combina um frontend Flutter, uma API FastAPI, tratamento
de dados com Pandas, persistencia no Supabase e analises com Google Gemini.

## Recursos principais

- Importacao de CSV, TSV, TXT, XLSX, XLS, JSON, NDJSON e Parquet.
- Importacao por URL publica para planilhas e APIs compativeis.
- Limpeza automatica, normalizacao de tipos, remocao de duplicatas,
  anonimizacao e registro detalhado de ETL.
- Combinacao de duas ou mais fontes com inferencia de chaves, cardinalidades e
  geracao automatica de modelo estrela.
- Catalogo com 42 tipos de visuais, medidas calculadas e personalizacao por
  visual.
- Canvas responsivo com movimentacao, redimensionamento, snap-to-grid e modo de
  apresentacao.
- Exportacao de fontes tratadas em CSV, XLSX, JSON, Parquet e PDF.
- Exportacao de dashboards em XLSX e JSON, alem de captura visual em PNG e PDF
  pelo frontend.
- Autenticacao, perfis, fontes, dashboards e logs isolados por usuario.
- Recomendacao de visuais e chat analitico usando Gemini.

## Tecnologias

- Frontend: Flutter e Dart, Material 3, FL Chart e CustomPainter.
- Backend: Python, FastAPI, Pandas, NumPy e Uvicorn.
- Banco e autenticacao: Supabase/PostgreSQL.
- Inteligencia artificial: Google Gemini.
- Qualidade: pytest, flutter_test e flutter analyze.

## Estrutura

- `flash_dash_app/backend/`: API, tratamento, modelagem e testes Python.
- `flash_dash_app/frontend/`: aplicativo Flutter e testes de interface.
- `flash_dash_app/backend/sql/`: migracoes para o Supabase.
- `flash_dash_app/validation/`: cenarios e artefatos de validacao academica.

## Executar o backend

Requisitos: Python 3.12 ou superior.

```powershell
cd flash_dash_app/backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
cd src
uvicorn main:app --reload
```

O comando acima e destinado ao desenvolvimento. Para carga, demonstracao ou
producao local, inicie sem recarga automatica e com processos de trabalho:

```powershell
cd flash_dash_app/backend
python run_production.py
```

Preencha o `.env` com as credenciais do Supabase, a chave do Gemini e as
origens CORS permitidas. Nunca envie esse arquivo ao Git.

- API: `http://127.0.0.1:8000`
- Swagger: `http://127.0.0.1:8000/docs`
- Saude: `http://127.0.0.1:8000/health`

## Executar o frontend

Requisito: Flutter compativel com Dart 3.11 ou superior.

```powershell
cd flash_dash_app/frontend
flutter pub get
flutter run -d chrome
```

O frontend usa `http://127.0.0.1:8000` por padrao em ambiente local. Para
outro endereco, use `--dart-define=API_BASE_URL=https://seu-backend`.

## Banco de dados

Execute as migracoes de `flash_dash_app/backend/sql/` no SQL Editor do
Supabase, em ordem numerica. A migracao `003_dashboard_fontes_e_perfil.sql`
adiciona fontes vinculadas ao dashboard e os campos estendidos de perfil.

## Validacao

```powershell
cd flash_dash_app/backend
python -m pytest -q
```

```powershell
cd flash_dash_app/frontend
flutter analyze
flutter test
```

Os testes cobrem limpeza, formatos de entrada, modelagem, isolamento por
usuario, exportacoes, medidas calculadas, renderizacao dos visuais e a matriz
responsiva de celulares, tablets e desktops.

As avaliacoes reproduziveis de H2 e H5 ficam em `flash_dash_app/validation/`.
Consulte o README dessa pasta para executar o conjunto rotulado de modelagem e
o estresse com k6.
