from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI, File, UploadFile
from db_repository import save
from db_repository import save_dashboard
from db_repository import get_dashboards

from ia_service import analisar_dados_com_ia, conversar_com_ia
from tratamento_dados import limparPlanilha
from pydantic import BaseModel

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

@app.post("/analisar-planilha")
async def analisar_rota(file: UploadFile = File(...)):
    
    conteudo = await file.read()
    dados_limpos = limparPlanilha(conteudo, file.filename)
    
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

# Adicione este modelo junto com os outros (como o ChatPayload)
class DashboardPayload(BaseModel):
    titulo: str
    graficos_config: list
    usuario_id: str

# E crie a nova rota no final do arquivo:
@app.post("/salvar-dashboard")
async def salvar_dashboard_api(payload: DashboardPayload):
    # Passe o usuario_id para a função do banco
    sucesso = save_dashboard(payload.titulo, payload.graficos_config, payload.usuario_id)
    if sucesso:
        return {"status": "success", "message": "Dashboard guardado na nuvem!"}
    else:
        return {"status": "error", "message": "Falha ao comunicar com o banco."}

# 2. Adicione usuario_id como parâmetro na rota de listar
@app.get("/listar-dashboards")
async def listar_dashboards_api(usuario_id: str): # <- O FastAPI transforma isso num Query Parameter automático
    dados = get_dashboards(usuario_id)
    return dados

@app.get("/listar-logs-etl")
async def listar_logs_etl_api():
    dados = get_logs_etl()
    return dados