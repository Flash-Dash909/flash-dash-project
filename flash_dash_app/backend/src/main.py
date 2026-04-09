from fastapi import FastAPI, File, UploadFile
from flash_dash_app.backend.src.tratamento_dados import limparPlanilha
from flash_dash_app.backend.src.ia_service import analisar_dados_com_ia
from flash_dash_app.backend.src.db_repository import save 
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/analisar-planilha")
async def analisar_rota(arquivo: UploadFile = File(...)):
    
    conteudo = await arquivo.read()
    
    dados_limpos = limparPlanilha(conteudo, arquivo.filename)
    
    if dados_limpos["status"] == "error":
        return dados_limpos
    
    texto_resultado = analisar_dados_com_ia(dados_limpos)

    save(dados_limpos, texto_resultado)
    
    return {
        "status": "sucesso",
        "insight_da_ia": texto_resultado,
        "dados_planilha": dados_limpos 
    }

