import pandas as pd
import io

def limparPlanilha(conteudo_arquivo, nome_arquivo):
    try:
        logs_etl = [] # 1. Inicia o Log de ETL

        # Leitura do arquivo vindo da memória
        if nome_arquivo.endswith('.csv'):
            df_raw = pd.read_csv(io.BytesIO(conteudo_arquivo), sep=None, engine='python', header=None)
        else:
            df_raw = pd.read_excel(io.BytesIO(conteudo_arquivo), header=None)

        linhas_brutas = len(df_raw)
        logs_etl.append({
            "fase": "Extração", 
            "icone": "upload",
            "descricao": f"Arquivo '{nome_arquivo}' carregado em memória. Total de linhas brutas: {linhas_brutas}."
        })

        # 2. Auto-Cleaning (A lógica excelente do seu colega)
        primeira_linha_valida_idx = df_raw.dropna(how='all').index[0]
        novos_nomes_colunas = df_raw.iloc[primeira_linha_valida_idx]
        df = df_raw.iloc[primeira_linha_valida_idx + 1:].copy()
        df.columns = novos_nomes_colunas
        
        tamanho_antes_limpeza = len(df)
        df = df.dropna(how='all').reset_index(drop=True)
        linhas_removidas_nulas = tamanho_antes_limpeza - len(df)
        
        if linhas_removidas_nulas > 0:
            logs_etl.append({
                "fase": "Transformação: Limpeza", 
                "icone": "cleaning",
                "descricao": f"{linhas_removidas_nulas} linhas completamente vazias foram removidas."
            })

        tamanho_antes_total = len(df)
        df = df[~df.iloc[:, 0].astype(str).str.lower().str.contains('total')]
        linhas_removidas_total = tamanho_antes_total - len(df)
        
        if linhas_removidas_total > 0:
            logs_etl.append({
                "fase": "Transformação: Filtragem", 
                "icone": "cleaning",
                "descricao": f"{linhas_removidas_total} linhas de subtotal/total foram ignoradas para evitar duplicação."
            })

        df = df.map(lambda x: x.strip() if isinstance(x, str) else x)
        logs_etl.append({
            "fase": "Transformação: Padronização", 
            "icone": "text_format",
            "descricao": "Espaços em branco extras removidos de todas as células de texto."
        })

        def tratar_moeda_br(valor):
            if isinstance(valor, str) and 'R$' in valor:
                return float(valor.replace('R$', '').replace('.', '').replace(',', '.').strip())
            return valor

        for col in df.columns:
            df[col] = df[col].apply(tratar_moeda_br)

        # 3. Preparando os dados para o Frontend (Automatizando o Gráfico)
        colunas_categoricas = df.select_dtypes(include=['object', 'string']).columns.tolist()
        colunas_numericas = df.select_dtypes(include=['float64', 'int64']).columns.tolist()

        logs_etl.append({
            "fase": "Modelagem (Schema)", 
            "icone": "schema",
            "descricao": f"Motor detectou {len(colunas_categoricas)} Dimensões e {len(colunas_numericas)} Métricas."
        })

        chart_data = []
        if colunas_categoricas and colunas_numericas:
            dimensao = colunas_categoricas[0] # Ex: Pega a coluna "Vendedor"
            metrica = colunas_numericas[0]    # Ex: Pega a coluna "Valor"

            # Agrupa, soma e pega os 5 maiores para não quebrar o gráfico do Flutter
            df_grouped = df.groupby(dimensao)[metrica].sum().reset_index()
            df_grouped = df_grouped.sort_values(by=metrica, ascending=False).head(5)

            cores = ["#1E293B", "#748AA1", "#3B82F6", "#10B981", "#F59E0B"] # Cores combinando com seu app

            for i, row in df_grouped.iterrows():
                chart_data.append({
                    "label": str(row[dimensao]),
                    "value": float(row[metrica]),
                    "color": cores[i % len(cores)] # type: ignore
                })

        logs_etl.append({
            "fase": "Load (Carga)", 
            "icone": "check_circle",
            "descricao": f"Tabela final pronta para consumo. Linhas válidas retidas: {len(df)}."
        })

        # 4. Retornando no formato JSON exato que o Flutter precisa agora
        return {
            "status": "success",
            "summary": {
                "total_rows": len(df),
                "cleaned_columns": list(df.columns),
                "dimensoes": colunas_categoricas,  # Aqui vão só os textos (Eixo X)
                "metricas": colunas_numericas      # Aqui vão só os números (Eixo Y)
            },
            "etl_logs": logs_etl, # <--- ENVIANDO OS LOGS PARA O FRONTEND
            "chart_data": chart_data,
            # Exportamos os dados completos (preenchendo vazios para não dar erro de JSON)
            "dados_brutos": df.fillna("").to_dict(orient='records') 
        }

    except Exception as e:
        return {"status": "error", "message": str(e)}