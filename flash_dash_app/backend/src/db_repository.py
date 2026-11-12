from pathlib import Path
import os

from dotenv import load_dotenv
from supabase import create_client, Client
import hashlib
import hmac
import json
import secrets

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
if not SUPABASE_URL or not SUPABASE_KEY:
    raise RuntimeError("Configure SUPABASE_URL e SUPABASE_KEY em backend/.env")

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

def save(dados_json, insight_texto, nome_arquivo="Upload_Manual.csv", usuario_id=None):
    try:
        summary = dict(dados_json.get("summary", {}))
        if dados_json.get("modelo_estrela"):
            summary["modelo_estrela"] = dados_json["modelo_estrela"]
        dados_limpos = dados_json.get("dados_limpos") or dados_json.get("dados_brutos", [])
        novo_registro = {
            "nome_arquivo": nome_arquivo,
            "tamanho_kb": (
                f"{len(json.dumps(dados_limpos, ensure_ascii=False, default=str).encode('utf-8')) / 1024:.1f} KB"
            ),
            "dados_brutos": dados_limpos,
            "summary": summary,
            "etl_logs": dados_json.get("etl_logs", []),
            "ia_response": insight_texto,
            "status": "Concluido",
        }
        if usuario_id:
            novo_registro["usuario_id"] = usuario_id
        
        resposta = supabase_db.table("fontes_dados").insert(novo_registro).execute()
        print("--- Planilha salva no Supabase (Fontes de Dados) com sucesso!")
        salvo = resposta.data[0] if resposta.data else dict(novo_registro)
        salvo.setdefault("dados_limpos", dados_limpos)
        salvo.setdefault("modelo_estrela", dados_json.get("modelo_estrela"))
        return salvo
        
    except Exception as e:
        print(f"--- Erro ao salvar no banco Supabase: {e}")
        return False
    
def save_dashboard(
    titulo,
    graficos_config,
    usuario_id=None,
    metricas_calculadas=None,
    dashboard_id=None,
    fonte_ids=None,
):
    try:
        novo_dashboard = {
            "titulo": titulo,
            "icone": "dashboard_customize",
            "graficos_config": graficos_config,
            "metricas_calculadas": metricas_calculadas or [],
            "fonte_ids": fonte_ids or [],
        }
        if usuario_id:
            novo_dashboard["usuario_id"] = usuario_id

        if dashboard_id:
            query = (
                supabase_db.table("dashboards")
                .update(novo_dashboard)
                .eq("id", dashboard_id)
            )
            if usuario_id:
                query = query.eq("usuario_id", usuario_id)
            resposta = query.execute()
        else:
            resposta = supabase_db.table("dashboards").insert(novo_dashboard).execute()
        print(f"--- Dashboard '{titulo}' salvo no Supabase com sucesso!")
        return resposta.data[0] if resposta.data else novo_dashboard
    except Exception as e:
        print(f"--- Erro ao salvar dashboard no Supabase: {e}")
        return None

def get_fontes(usuario_id=None):
    try:
        query = supabase_db.table("fontes_dados").select(
            "id, usuario_id, nome_arquivo, tamanho_kb, status, summary, created_at"
        )
        if usuario_id:
            query = query.eq("usuario_id", usuario_id)
        return query.order("created_at", desc=True).execute().data
    except Exception as e:
        print(f"--- Erro ao buscar fontes: {e}")
        return []

def get_fonte(fonte_id, usuario_id=None):
    try:
        query = supabase_db.table("fontes_dados").select("*").eq("id", fonte_id)
        if usuario_id:
            query = query.eq("usuario_id", usuario_id)
        resposta = query.limit(1).execute()
        if not resposta.data:
            return None
        fonte = resposta.data[0]
        fonte.setdefault("dados_limpos", fonte.get("dados_brutos") or [])
        summary = fonte.get("summary") or {}
        if isinstance(summary, dict) and summary.get("modelo_estrela"):
            fonte.setdefault("modelo_estrela", summary["modelo_estrela"])
        return fonte
    except Exception as e:
        print(f"--- Erro ao buscar fonte: {e}")
        return None

def update_source_model(fonte_id, modelo_estrela, usuario_id=None):
    try:
        fonte = get_fonte(fonte_id, usuario_id)
        if not fonte:
            return None

        summary = fonte.get("summary") or {}
        if not isinstance(summary, dict):
            summary = {}
        summary = dict(summary)
        summary.setdefault("modelo_estrela_automatico", summary.get("modelo_estrela", {}))
        summary["modelo_estrela"] = modelo_estrela

        query = (
            supabase_db.table("fontes_dados")
            .update({"summary": summary})
            .eq("id", fonte_id)
        )
        if usuario_id:
            query = query.eq("usuario_id", usuario_id)
        resposta = query.execute()
        if not resposta.data:
            return None

        atualizado = resposta.data[0]
        atualizado.setdefault("dados_limpos", fonte.get("dados_limpos") or [])
        atualizado["modelo_estrela"] = modelo_estrela
        return atualizado
    except Exception as e:
        print(f"--- Erro ao atualizar modelo da fonte: {e}")
        return None

def delete_fonte(fonte_id, usuario_id=None):
    try:
        query = supabase_db.table("fontes_dados").delete().eq("id", fonte_id)
        if usuario_id:
            query = query.eq("usuario_id", usuario_id)
        query.execute()
        return True
    except Exception as e:
        print(f"--- Erro ao excluir fonte: {e}")
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

def get_dashboard(dashboard_id, usuario_id=None):
    try:
        query = supabase_db.table("dashboards").select("*").eq("id", dashboard_id)
        if usuario_id:
            query = query.eq("usuario_id", usuario_id)
        resposta = query.limit(1).execute()
        return resposta.data[0] if resposta.data else None
    except Exception as e:
        print(f"--- Erro ao buscar dashboard: {e}")
        return None

def delete_dashboard(dashboard_id, usuario_id=None):
    try:
        query = supabase_db.table("dashboards").delete().eq("id", dashboard_id)
        if usuario_id:
            query = query.eq("usuario_id", usuario_id)
        query.execute()
        print(f"--- Dashboard '{dashboard_id}' excluido do Supabase com sucesso!")
        return True
    except Exception as e:
        print(f"--- Erro ao excluir dashboard: {e}")
        return False

def get_logs_etl(usuario_id=None):
    try:
        # Busca apenas o nome do arquivo, a data e a coluna JSON dos logs
        query = supabase_db.table("fontes_dados").select(
            "id, nome_arquivo, created_at, summary, etl_logs"
        )
        if usuario_id:
            query = query.eq("usuario_id", usuario_id)
        resposta = query.order("created_at", desc=True).execute()
        return resposta.data
    except Exception as e:
        print(f"--- Erro ao buscar logs: {e}")
        return []
