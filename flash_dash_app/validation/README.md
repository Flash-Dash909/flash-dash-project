# Validacao do Flash Dash

Esta pasta concentra o protocolo e os executores usados para validar o projeto.
Os resultados gerados ficam em `results/` e podem ser reproduzidos em outra maquina.

## Execucao rapida

No diretorio `flash_dash_app/validation`:

```powershell
python run_all.py
```

Para incluir um servidor local ja iniciado:

```powershell
python run_all.py --load-url http://127.0.0.1:8000/health
```

Para repetir a avaliacao estocastica da IA tres vezes por caso:

```powershell
python evaluate_llm.py --repetitions 3 --concurrency 2
```

Para avaliar a modelagem dimensional com o conjunto rotulado:

```powershell
python evaluate_data_modeling.py
```

Inicie o backend sem `--reload`, com quatro processos de trabalho:

```powershell
cd ..\backend
python run_production.py --workers 4
```

Para executar o teste de estresse ampliado com k6 e cinco mil requisicoes por
nivel, em tres repeticoes:

```powershell
python run_k6_stress.py --url http://127.0.0.1:8000/health --concurrency 100,250,500,1000 --iterations 5000 --repetitions 3 --server-workers 4 --output-prefix stress_test
```

O executor `per-vu-iterations` garante que cada usuario virtual participe. Os
niveis representam usuarios virtuais fazendo chamadas HTTP, nao sessoes
completas no navegador. Em producao, repita a partir de outra maquina para que
cliente e servidor nao disputem os mesmos recursos.

## Artefatos

- `PLANO_VALIDACAO.md`: protocolo cientifico, hipoteses e criterios sugeridos.
- `requirements_matrix.csv`: rastreabilidade requisito-teste-evidencia.
- `datasets/llm_recommendation_cases.json`: conjunto de referencia da IA.
- `templates/`: tarefas, questionario SUS/CSAT e planilhas de coleta.
- `run_etl_benchmark.py`: tempo, CPU, memoria e vazao do Auto-Cleaning.
- `run_load_test.py`: latencia, RPS e taxa de erro sob concorrencia.
- `run_k6_stress.py`: estresse repetido com 100 a 1000 usuarios virtuais.
- `evaluate_data_modeling.py`: precisao e validade estrutural do modelo estrela.
- `evaluate_llm.py`: Top-1, Top-3, validade e latencia da recomendacao.
- `run_security_scan.py`: testes de isolamento, SAST e dependencias.
- `analyze_usability.py`: conclusao, tempo, erros, SUS, CSAT e heatmap.
- `generate_report.py`: consolida evidencias e graficos em Markdown.

Os limites em `PLANO_VALIDACAO.md` sao criterios propostos. Devem ser aprovados
pelo orientador antes da coleta definitiva.
