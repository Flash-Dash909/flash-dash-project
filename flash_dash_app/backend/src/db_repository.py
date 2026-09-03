from supabase import create_client, Client
import hashlib
import hmac
import json
import secrets

SUPABASE_URL = "https://qookuziywrysqfzofyve.supabase.co"
# CUIDADO: É sempre bom esconder essa chave em um arquivo .env depois!
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFvb2t1eml5d3J5c3Fmem9meXZlIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3Mjc3ODkwMCwiZXhwIjoyMDg4MzU0OTAwfQ.UaFmjY5urj5GkeB8-ZZrehdxK1jCWSPuBQVFd6jMzaQ" 

supabase_db: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def _normalizar_email(email):
    return email.strip().lower()

def gerar_hash_senha(senha):
    salt = secrets.token_hex(16)
    senha_hash = hashlib.pbkdf2_hmac(
        "sha256",
        senha.encode("utf-8"),
        salt.encode("utf-8"),
        120000,
    ).hex()
    return f"{salt}${senha_hash}"

def verificar_senha(senha, senha_hash_salvo):
    try:
        salt, senha_hash = senha_hash_salvo.split("$", 1)
        novo_hash = hashlib.pbkdf2_hmac(
            "sha256",
            senha.encode("utf-8"),
            salt.encode("utf-8"),
            120000,
        ).hex()
        return hmac.compare_digest(novo_hash, senha_hash)
    except Exception:
        return False

def buscar_usuario_por_email(email):
    try:
        resposta = (
            supabase_db.table("usuarios")
            .select("*")
            .eq("email", _normalizar_email(email))
            .limit(1)
            .execute()
        )
        if resposta.data:
            return resposta.data[0]
        return None
    except Exception as e:
        print(f"--- Erro ao buscar usuario: {e}")
        return None

def buscar_usuario_por_id(usuario_id):
    try:
        resposta = (
            supabase_db.table("usuarios")
            .select("*")
            .eq("id", usuario_id)
            .limit(1)
            .execute()
        )
        if resposta.data:
            usuario = resposta.data[0]
            usuario.pop("senha_hash", None)
            return usuario
        return None
    except Exception as e:
        print(f"--- Erro ao buscar usuario por id: {e}")
        return None

def atualizar_usuario(usuario_id, dados):
    try:
        campos_permitidos = {
            "nome",
            "idade",
            "telefone",
            "cargo",
            "empresa",
            "bio",
            "foto_url",
        }
        payload = {
            chave: valor
            for chave, valor in dados.items()
            if chave in campos_permitidos
        }
        if not payload:
            return buscar_usuario_por_id(usuario_id)

        resposta = (
            supabase_db.table("usuarios")
            .update(payload)
            .eq("id", usuario_id)
            .execute()
        )
        if resposta.data:
            usuario = resposta.data[0]
            usuario.pop("senha_hash", None)
            return usuario
        return buscar_usuario_por_id(usuario_id)
    except Exception as e:
        print(f"--- Erro ao atualizar usuario: {e}")
        return None

def criar_usuario(nome, email, senha):
    try:
        novo_usuario = {
            "nome": nome.strip(),
            "email": _normalizar_email(email),
            "senha_hash": gerar_hash_senha(senha),
        }

        resposta = supabase_db.table("usuarios").insert(novo_usuario).execute()
        if resposta.data:
            usuario = resposta.data[0]
            usuario.pop("senha_hash", None)
            return usuario
        return None
    except Exception as e:
        print(f"--- Erro ao criar usuario: {e}")
        return None

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
    
def save_dashboard(titulo, graficos_config, usuario_id=None, metricas_calculadas=None):
    try:
        novo_dashboard = {
            "titulo": titulo,
            "icone": "dashboard_customize",
            "graficos_config": graficos_config,
            "metricas_calculadas": metricas_calculadas or [],
        }
        if usuario_id:
            novo_dashboard["usuario_id"] = usuario_id

        supabase_db.table("dashboards").insert(novo_dashboard).execute()
        print(f"--- Dashboard '{titulo}' salvo no Supabase com sucesso!")
        return True
    except Exception as e:
        if "novo_dashboard" in locals() and "metricas_calculadas" in novo_dashboard:
            try:
                novo_dashboard.pop("metricas_calculadas", None)
                supabase_db.table("dashboards").insert(novo_dashboard).execute()
                print(
                    "--- Dashboard salvo sem metricas_calculadas; "
                    "adicione a coluna no Supabase para persistir as metricas."
                )
                return True
            except Exception as retry_error:
                print(f"--- Erro ao salvar dashboard sem metricas: {retry_error}")
        print(f"--- Erro ao salvar dashboard no Supabase: {e}")
        return False

def get_dashboards(usuario_id=None):
    try:
        query = supabase_db.table("dashboards").select("*")
        if usuario_id:
            query = query.eq("usuario_id", usuario_id)
        resposta = query.order("created_at", desc=True).execute()
        return resposta.data
    except Exception as e:
        print(f"--- Erro ao buscar dashboards: {e}")
        return []

def delete_dashboard(dashboard_id):
    try:
        supabase_db.table("dashboards").delete().eq("id", dashboard_id).execute()
        print(f"--- Dashboard '{dashboard_id}' excluido do Supabase com sucesso!")
        return True
    except Exception as e:
        print(f"--- Erro ao excluir dashboard: {e}")
        return False

def get_logs_etl():
    try:
        # Busca apenas o nome do arquivo, a data e a coluna JSON dos logs
        resposta = supabase_db.table("fontes_dados").select("nome_arquivo, created_at, etl_logs").order("created_at", desc=True).execute()
        return resposta.data
    except Exception as e:
        print(f"--- Erro ao buscar logs: {e}")
        return []
