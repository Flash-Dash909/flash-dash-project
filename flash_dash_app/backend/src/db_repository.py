from supabase import create_client, Client
import json

SUPABASE_URL = "https://qookuziywrysqfzofyve.supabase.co"
# CUIDADO: É sempre bom esconder essa chave em um arquivo .env depois!
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFvb2t1eml5d3J5c3Fmem9meXZlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3Mjc3ODkwMCwiZXhwIjoyMDg4MzU0OTAwfQ.UaFmjY5urj5GkeB8-ZZrehdxK1jCWSPuBQVFd6jMzaQ" 

supabase_db: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def save(dados_json, insight_texto, nome_arquivo="Upload_Manual.csv"):
    try:
        # Prepara o registro batendo exatamente com as colunas novas do Supabase
        novo_registro = {
            "nome_arquivo": nome_arquivo,
            "tamanho_kb": str(round(len(str(dados_json.get("dados_brutos", []))) / 1024, 1)) + " KB",
            "dados_brutos": dados_json.get("dados_brutos", []),
            "summary": dados_json.get("summary", {}),
            "etl_logs": dados_json.get("etl_logs", []),
            "ia_response": insight_texto
        }
        
        # Insere na nova tabela fontes_dados
        resposta = supabase_db.table("fontes_dados").insert(novo_registro).execute()
        
        print("--- Planilha salva no Supabase (Fontes de Dados) com sucesso!")
        return True
        
    except Exception as e:
        print(f"--- Erro ao salvar no banco Supabase: {e}")
        return False
    
def save_dashboard(titulo, graficos_config):
    try:
        novo_dashboard = {
            "titulo": titulo,
            "icone": "dashboard_customize",
            "graficos_config": graficos_config, # O JSON que o Flutter vai mandar
            # Se você já tiver o ID do usuário logado, adicione aqui:
            # "usuario_id": "id_do_usuario" 
        }
        
        resposta = supabase_db.table("dashboards").insert(novo_dashboard).execute()
        print(f"--- Dashboard '{titulo}' salvo no Supabase com sucesso!")
        return True
    except Exception as e:
        print(f"--- Erro ao salvar dashboard no Supabase: {e}")
        return False
    
def get_dashboards():
    try:
        # Busca todos os registros da tabela 'dashboards' ordenando pelos mais recentes
        resposta = supabase_db.table("dashboards").select("*").order("created_at", desc=True).execute()
        return resposta.data # Retorna a lista de dicionários (JSON)
    except Exception as e:
        print(f"--- Erro ao buscar dashboards: {e}")
        return []

def get_logs_etl():
    try:
        # Busca apenas o nome do arquivo, a data e a coluna JSON dos logs
        resposta = supabase_db.table("fontes_dados").select("nome_arquivo, created_at, etl_logs").order("created_at", desc=True).execute()
        return resposta.data
    except Exception as e:
        print(f"--- Erro ao buscar logs: {e}")
        return []