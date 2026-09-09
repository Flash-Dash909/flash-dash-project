from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI, File, Form, UploadFile
from db_repository import save
from db_repository import save_dashboard
from db_repository import get_dashboards
from db_repository import get_logs_etl
from db_repository import delete_dashboard

from ia_service import analisar_dados_com_ia, conversar_com_ia
from tratamento_dados import limparPlanilha
from pydantic import BaseModel
from urllib.parse import urlparse
from urllib.request import Request, urlopen

# Importa o roteador que acabamos de criar no login.py
from login import router as login_router 

app = FastAPI()

# Registra as rotas de login no app principal
# O prefixo "/auth" significa que a rota final será /auth/login
app.include_router(login_router, prefix="/auth", tags=["Autenticação"])

# Define o formato que o Flutter vai enviar
class ChatPayload(BaseModel):
    mensagem: str
    contexto_dashboard: list

class UrlFontePayload(BaseModel):
    url: str
    nome: str | None = None
    fonte_tipo: str = "url"

@app.post("/chat-ia")
async def chat_com_ia(payload: ChatPayload):
    try:
        resposta_ia = conversar_com_ia(payload.mensagem, payload.contexto_dashboard)
        return {"status": "success", "resposta": resposta_ia}
    except Exception as e:
        return {"status": "error", "message": str(e)}

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def home():
    return {"status": "online", "message": "Flash Dash API está funcionando!"}

@app.post("/analisar-planilha")
async def analisar_rota(file: UploadFile = File(...), fonte_tipo: str = Form("arquivo")):
    
    conteudo = await file.read()
    dados_limpos = limparPlanilha(conteudo, file.filename, fonte_tipo)
    
    if dados_limpos["status"] == "error":
        return dados_limpos
    
    texto_resultado = analisar_dados_com_ia(dados_limpos)
    
    # === A CORREÇÃO DO PYLANCE ESTÁ AQUI ===
    # Se file.filename for None, ele usa a string "Planilha_Sem_Nome.csv"
    nome_seguro = file.filename or "Planilha_Sem_Nome.csv"
    
    save(dados_limpos, texto_resultado, nome_seguro)
    
    return {
        "status": "sucesso",
        "insight_da_ia": texto_resultado,
        "dados_planilha": dados_limpos 
    }

@app.post("/analisar-url")
async def analisar_url(payload: UrlFontePayload):
    try:
        request = Request(payload.url, headers={"User-Agent": "Flash-Dash/1.0"})
        with urlopen(request, timeout=20) as response:
            conteudo = response.read()
            content_type = response.headers.get("content-type", "")

        caminho = urlparse(payload.url).path
        nome_arquivo = payload.nome or caminho.split("/")[-1] or "fonte_remota.json"
        if "." not in nome_arquivo:
            nome_arquivo += ".csv" if "csv" in content_type else ".json"

        dados_limpos = limparPlanilha(conteudo, nome_arquivo, payload.fonte_tipo)
        if dados_limpos["status"] == "error":
            return dados_limpos

        texto_resultado = analisar_dados_com_ia(dados_limpos)
        save(dados_limpos, texto_resultado, nome_arquivo)

        return {
            "status": "sucesso",
            "insight_da_ia": texto_resultado,
            "dados_planilha": dados_limpos,
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

# Adicione este modelo junto com os outros (como o ChatPayload)
class DashboardPayload(BaseModel):
    titulo: str
    graficos_config: list
    metricas_calculadas: list | None = None
    usuario_id: str | None = None

# E crie a nova rota no final do arquivo:
@app.post("/salvar-dashboard")
async def salvar_dashboard_api(payload: DashboardPayload):
    # Passe o usuario_id para a função do banco
    sucesso = save_dashboard(
        payload.titulo,
        payload.graficos_config,
        payload.usuario_id,
        payload.metricas_calculadas or [],
    )
    if sucesso:
        return {"status": "success", "message": "Dashboard guardado na nuvem!"}
    else:
        return {"status": "error", "message": "Falha ao comunicar com o banco."}

# 2. Adicione usuario_id como parâmetro na rota de listar
@app.get("/listar-dashboards")
async def listar_dashboards_api(usuario_id: str | None = None): # <- O FastAPI transforma isso num Query Parameter automático
    dados = get_dashboards(usuario_id)
    return dados

@app.delete("/dashboards/{dashboard_id}")
async def excluir_dashboard_api(dashboard_id: str):
    sucesso = delete_dashboard(dashboard_id)
    if sucesso:
        return {"status": "success", "message": "Dashboard excluido com sucesso!"}
    return {"status": "error", "message": "Falha ao excluir dashboard."}

@app.get("/listar-logs-etl")
async def listar_logs_etl_api():
    dados = get_logs_etl()
    return dados

