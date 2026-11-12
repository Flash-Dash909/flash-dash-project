# Plano de Validacao Experimental do Flash Dash

## 1. Objetivo

Validar se o Flash Dash reduz o atraso analitico ao converter fontes brutas em
dashboards de forma correta, segura, responsiva e suficientemente rapida. A
avaliacao separa requisitos funcionais, verificados de forma deterministica,
de requisitos nao funcionais, medidos por experimentos repetiveis.

## 2. Hipoteses

- H1: o Auto-Cleaning trata formatos suportados, remove duplicatas, normaliza
  tipos e pseudonimiza campos sensiveis sem corromper os dados uteis.
- H2: a modelagem produz uma tabela fato, dimensoes e relacionamentos validos.
- H3: a Intelligence Layer recomenda um visual adequado entre os tres primeiros
  resultados em pelo menos 80% dos cenarios de referencia.
- H4: as telas criticas nao apresentam overflow nas resolucoes testadas.
- H5: a API permanece estavel com o aumento de concorrencia dentro dos limites
  definidos para o ambiente experimental.
- H6: dados, dashboards e logs de ETL sao isolados pelo usuario autenticado.
- H7: usuarios concluem o fluxo principal com boa satisfacao e baixo retrabalho.

## 3. Criterios de aceite propostos

| Area | Metrica | Criterio sugerido |
|---|---|---|
| Auto-Cleaning | testes funcionais | 100% dos casos automatizados aprovados |
| Privacidade | campos sensiveis identificados | 100% nos casos de referencia |
| Modelo estrela | relacionamentos corretos | >= 90% no conjunto rotulado |
| LLM | Top-1 | >= 65% |
| LLM | Top-3 | >= 80% |
| LLM | saidas validas | 100% dos resultados produzidos |
| Responsividade | overflow/excecao Flutter | zero nas matrizes de viewport |
| Usabilidade | conclusao do fluxo | >= 90% |
| Usabilidade | SUS | >= 68/100 |
| Usabilidade | CSAT | >= 4/5 |
| API | erro com 25 clientes concorrentes | < 1% |
| API | latencia p95 do `/health` | < 500 ms no ambiente local |
| API | estresse com 500 requisicoes simultaneas | erro < 1% e p95 < 1 s |
| ETL | p95 para 50 mil linhas | < 5 s no ambiente de referencia |
| Seguranca | achados criticos/altos abertos | zero |
| Isolamento | acesso cruzado entre contas | zero ocorrencias |

Os valores devem ser congelados antes do experimento final. Alterar um criterio
depois de observar os resultados invalida a comparacao principal.

## 4. Metodos

### 4.1 Requisitos funcionais

Executar testes unitarios e de integracao sobre importacao, limpeza, inferencia
de tipos, deduplicacao, anonimização, esquema estrela, autenticacao, isolamento,
exportacao e recomendacao. Cada falha deve guardar entrada, saida observada,
saida esperada, versao do codigo e data da correcao.

A modelagem dimensional usa ainda o conjunto rotulado em
`datasets/modeling_cases.json`. A avaliacao compara relacionamentos esperados e
inferidos, cardinalidade, tabela fato, dimensoes e validade estrutural. Casos
negativos verificam se colunas genericas ou sem valores em comum nao criam
relacionamentos falsos.

### 4.2 Responsividade

Executar os widget tests em 360x640, 390x844, 412x915, 768x1024, 1024x768,
1366x768 e 1920x1080. Cobrir login, home, fontes, biblioteca de graficos,
metricas, logs ETL e modelo estrela. Repetir ao menos em Chrome e Edge na Web e
em um aparelho Android real. Registrar overflow, excecao, elemento inacessivel
e tempo de conclusao.

### 4.3 Desempenho e escalabilidade

O benchmark ETL usa dados sinteticos deterministas de 1 mil, 10 mil e 50 mil
linhas, com datas, moedas, percentuais, nulos, duplicatas e identificadores
pessoais. Registrar mediana e p95 de tempo, CPU, pico de memoria e linhas por
segundo. O teste de carga aumenta a concorrencia em 1, 5, 10, 25 e 50 clientes.
O ensaio de estresse usa 100, 250, 500 e 1000 requisicoes HTTP simultaneas,
com cinco mil requisicoes em cada nivel, para localizar degradacao e limite
operacional. Ambos medem p50/p95/p99, RPS, taxa de erro, CPU e memoria da API.

O ensaio ampliado deve usar k6 com o executor `per-vu-iterations`, distribuindo
as cinco mil requisicoes igualmente entre todos os usuarios virtuais. O backend
e iniciado sem recarga automatica e com quatro processos de trabalho. Cada
rodada recebe cinco requisicoes de aquecimento, verificacao de prontidao e
intervalo de estabilizacao. O criterio considera o pior p95 e a pior taxa de
erro entre tres repeticoes, e nao apenas a mediana.

Executar cinco aquecimentos antes da coleta, tres repeticoes por tamanho e no
mesmo computador. O pico de memoria e amostrado pelo RSS do processo a cada
10 ms, fora do caminho principal do ETL. Fechar programas pesados e registrar CPU, RAM, SO, navegador,
commit e configuracao do backend.

### 4.4 Precisao da LLM

Usar o conjunto rotulado em `datasets/llm_recommendation_cases.json`. Para cada
caso, a resposta e correta quando o primeiro visual (Top-1) ou algum dos tres
primeiros (Top-3) pertence ao conjunto aceito. Medir tambem latencia, taxa de
resposta, nome de visual valido e referencia apenas a colunas existentes.

Como a LLM e estocastica, executar no minimo tres repeticoes por caso e informar
modelo, data, temperatura quando configuravel e intervalo de confianca de 95%.
Nao ajustar os rotulos esperados depois de ler as respostas.

### 4.5 Usabilidade e UX

Recrutar de 8 a 12 participantes representativos, preferencialmente sem treino
previo em Power BI. Alternar desktop e celular. Aplicar as tarefas de
`templates/usability_tasks.csv`, gravar sucesso, tempo, erros e pedidos de ajuda,
e aplicar SUS e CSAT ao final. Cliques normalizados podem ser registrados em
`templates/heatmap_events.csv` para gerar o mapa de calor.

### 4.6 Seguranca

Combinar testes de autorizacao com analise estatica e auditoria de dependencias.
Classificar achados por severidade e registrar descoberta, correcao e validacao.
O MTTR e a media de `corrigido_em - descoberto_em`; ele so deve ser calculado
com historico real, nunca estimado retroativamente.

## 5. Analise e apresentacao

- Mostrar mediana e p95, nao apenas media, para latencia e tempo por tarefa.
- Exibir curva de carga (concorrencia x p95/RPS) e curva de ETL (linhas x tempo).
- Exibir Top-1 e Top-3 da LLM com intervalo de confianca.
- Exibir conclusao, SUS, CSAT e tempo por tarefa; usar heatmap apenas com coleta.
- Exibir vulnerabilidades por severidade e MTTR por ciclo de correcao.
- Informar resultados ausentes como `pendente`, sem preencher numeros simulados.

## 6. Ameacas a validade

Hardware local, rede, cota e versao do Gemini podem alterar os resultados. Uma
base sintetica nao representa toda planilha real. Participantes conhecidos pela
equipe podem introduzir vies. O endpoint `/health` mede a capacidade basal da
API; upload concorrente deve ser executado separadamente em ambiente de teste,
pois envolve Supabase e possivel custo de IA.
