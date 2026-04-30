from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

# Cria um roteador para agrupar as rotas de autenticação
router = APIRouter()

# Define o formato que o Flutter vai enviar no corpo da requisição
class LoginPayload(BaseModel):
    usuario: str
    senha: str

@router.post("/login")
async def fazer_login(payload: LoginPayload):
    # Validação super básica apenas para demonstração do app
    if payload.usuario == "admin" and payload.senha == "1234":
        return {
            "status": "success",
            "mensagem": "Bem-vindo ao Flash Dash!",
            "token": "token_demo_12345" # Você pode salvar isso no Flutter usando shared_preferences
        }
    else:
        # Retorna um erro 401 (Não autorizado) se errar a senha
        raise HTTPException(status_code=401, detail="Usuário ou senha incorretos")