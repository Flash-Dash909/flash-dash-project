# Roteiro de apresentação — Validação do Flash Dash

Tempo sugerido: 10 a 12 minutos, mais perguntas.

## Slide 1 — Abertura

“Bom dia. Nesta apresentação vamos mostrar como validamos o Flash Dash, uma plataforma criada para reduzir o atraso entre receber uma planilha bruta e obter um dashboard utilizável. O foco não é apenas demonstrar que a aplicação funciona, mas apresentar evidências de desempenho, responsividade, segurança, escalabilidade e qualidade das recomendações por inteligência artificial. Também vamos deixar claras as limitações encontradas e o que ainda falta para a validação científica final.”

## Slide 2 — Problema e objetivo

“O problema central é o atraso analítico. Normalmente, antes de enxergar uma informação, o usuário precisa limpar a planilha, entender as colunas, modelar os dados, escolher gráficos e montar o painel. O objetivo do Flash Dash é automatizar o máximo possível desse fluxo. A meta é transformar um arquivo bruto em um dashboard dinâmico e responsivo, mantendo a possibilidade de revisão manual quando a automação não for suficiente.”

## Slide 3 — Funcionamento da solução

“O fluxo começa na importação. Em seguida, o Auto-Cleaning aplica heurísticas determinísticas para tipos, valores ausentes, duplicatas e anonimização. Depois, o sistema propõe um esquema estrela com fatos, dimensões e relações. A camada de inteligência usa o Gemini para sugerir visuais e métricas. Por fim, o usuário recebe um dashboard editável. Flutter cuida da interface, FastAPI e Python concentram o processamento, Supabase persiste dados e autenticação, e Gemini participa da recomendação.”

## Slide 4 — Estratégia de validação

“A validação foi dividida em duas frentes. Os requisitos funcionais foram verificados de forma determinística, com resultado de passa ou falha. Os requisitos não funcionais precisaram de métricas objetivas, porque afirmações como ‘é rápido’ ou ‘é responsivo’ seriam subjetivas. Por isso, definimos critérios antes da execução, registramos o ambiente e salvamos CSV, JSON, logs e gráficos. Essa separação aumenta o rigor científico e evita ajustar o critério depois de conhecer o resultado.”

## Slide 5 — Funcionalidade e responsividade

“O backend passou em 12 de 12 casos. No Flutter, foram 15 de 15 testes, cobrindo sete tamanhos de tela e uma condição com texto ampliado. O ponto mais importante é que o teste não serviu apenas para confirmar: ele encontrou um overflow real de 270 pixels em tablet horizontal. O problema foi corrigido e o teste passou depois da correção. Isso demonstra utilidade prática da matriz de responsividade.”

## Slide 6 — Auto-Cleaning

“O Auto-Cleaning teve sucesso em todas as execuções e manteve a vazão próxima de seis mil linhas por segundo nos volumes maiores. Para mil linhas, a mediana foi de 195 milissegundos; para dez mil, 1,65 segundo; e para cinquenta mil, 8,20 segundos. O p95 em cinquenta mil linhas chegou a 8,47 segundos, acima do critério provisório de cinco segundos. Portanto, o motor é estável, mas ainda precisa de otimização para arquivos maiores. P95 significa que 95% das execuções terminaram até aquele tempo.”

## Slide 7 — Carga basal

“No ensaio basal, avaliamos de uma a cinquenta requisições simultâneas, totalizando quinhentas requisições. Em vinte e cinco simultâneas, a latência p95 foi de 85,6 milissegundos, a vazão foi de 635,7 requisições por segundo e não houve erros. O critério provisório foi atendido. RPS significa requisições processadas por segundo. Esse teste mostra que a API responde bem em uma carga inicial, mas ainda não representa sessões completas de usuários.”

## Slide 8 — Estresse

“No estresse ampliado, executamos três repetições com cinco mil requisições em cada nível de concorrência, chegando a sessenta mil requisições no total. A API permaneceu praticamente disponível, com erro máximo de 0,02%. Porém, a latência aumentou de 394 milissegundos em cem simultâneas para 9,33 segundos em mil. O critério de um segundo já foi ultrapassado em duzentas e cinquenta. Portanto, não devemos afirmar que o sistema suporta mil usuários. O correto é dizer que o endpoint local permaneceu disponível sob mil requisições HTTP simultâneas, mas com degradação severa de latência.”

## Slide 9 — Recomendação por LLM

“Para a recomendação de gráficos, usamos quatorze casos rotulados com o Gemini 2.5 Flash. Entre as respostas recebidas, o visual esperado apareceu entre as três primeiras sugestões em 88,9% dos casos, superando o critério de 80%. Porém, a taxa de resposta ponta a ponta foi de apenas 64,3%, porque 35,7% das chamadas foram bloqueadas pela cota. Assim, a qualidade condicional é promissora, mas a disponibilidade ainda não está validada. Precisamos repetir a avaliação três vezes com uma cota estável.”

## Slide 10 — Segurança

“Os testes de autenticação e isolamento passaram. O Bandit não encontrou problemas de severidade baixa, média ou alta, e a auditoria de dependências não reportou vulnerabilidades. Esses resultados são positivos, mas precisam ser interpretados corretamente: uma varredura estática sem achados não prova ausência total de vulnerabilidades. Ainda faltam revisar as políticas RLS em produção, executar testes dinâmicos, validar o fluxo completo em staging e medir MTTR quando existirem incidentes reais encerrados.”

## Slide 11 — Síntese

“A tabela resume a leitura correta dos resultados. Backend, responsividade, carga basal e Top-3 condicional da LLM atenderam aos critérios definidos. O ETL com cinquenta mil linhas e o estresse em quinhentas simultâneas não atenderam ao limite de latência, embora não tenham apresentado falhas relevantes. A disponibilidade da LLM precisa ser repetida sem a restrição de cota. A usabilidade permanece pendente, porque não vamos inventar dados de participantes. A base funcional está validada; capacidade e evidência externa ainda precisam amadurecer.”

## Slide 12 — Conclusão

“Como conclusão, os testes mostram que a base do Flash Dash funciona: os fluxos principais, a responsividade e os controles iniciais de segurança estão consistentes. Os gargalos encontrados são mensuráveis e orientam a próxima etapa: otimizar ETL e API, repetir a avaliação da LLM com cota estável e concluir a validação externa com participantes e dispositivos reais. A principal contribuição do projeto é integrar automação de BI, inteligência artificial, persistência auditável e edição visual em uma única experiência. Obrigado. Estamos à disposição para perguntas.”

## Respostas curtas para perguntas prováveis

**O teste comprova suporte a mil usuários?**  
Não. Ele comprova que o endpoint local `/health` permaneceu quase sempre disponível sob mil requisições simultâneas. A latência p95 chegou a 9,33 segundos e o ensaio não simulou sessões completas, uploads, Supabase e IA.

**A inteligência artificial foi aprovada?**  
Parcialmente. A qualidade entre as respostas recebidas foi boa, com Top-3 de 88,9%, mas a disponibilidade ponta a ponta foi prejudicada pela cota. A rodada final exige três repetições completas com uma chave estável.

**Por que não usar curva ROC ou matriz de confusão?**  
O módulo recomenda uma lista ordenada de visuais, não executa classificação binária por limiar. Por isso, Top-1, Top-3, validade dos campos, taxa de resposta e latência medem melhor o objetivo do sistema.

**O sistema está seguro?**  
Os controles testados passaram e as análises estáticas não encontraram achados. Isso é uma linha de base positiva, não uma garantia absoluta. Ainda faltam testes dinâmicos e revisão da configuração de produção.

**O que falta para fechar a validação?**  
Otimizar os gargalos, repetir a LLM, testar o fluxo completo em staging e coletar usabilidade com 8 a 12 participantes reais.
