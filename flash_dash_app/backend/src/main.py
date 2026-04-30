from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI, File, UploadFile
from db_repository import save
from ia_service import analisar_dados_com_ia, conversar_com_ia
from tratamento_dados import limparPlanilha
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

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

    save(dados_limpos, texto_resultado)
    
    return {
        "status": "sucesso",
        "insight_da_ia": texto_resultado,
        "dados_planilha": dados_limpos 
    }


