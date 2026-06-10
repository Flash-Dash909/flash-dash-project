from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from db_repository import register_user, authenticate_user

router = APIRouter()

# Payload apenas para Login
class LoginPayload(BaseModel):
    email: str
    senha: str

# Payload para Cadastro
class CadastroPayload(BaseModel):
    nome: str
    email: str
    senha: str

@router.post("/login")
async def fazer_login(payload: LoginPayload):
    usuario_db = authenticate_user(payload.email, payload.senha)
    
    if isinstance(usuario_db, dict):
        return {
            "status": "success",
            "mensagem": f"Bem-vindo(a), {usuario_db.get('nome')}!",
            "token": f"token_demo_{usuario_db.get('id')}", 
            "usuario_id": usuario_db.get('id'),
            "usuario_nome": usuario_db.get('nome') # <- ADICIONE ESSA LINHA AQUI
        }
    else:
        raise HTTPException(status_code=401, detail="E-mail ou senha incorretos")

@router.post("/cadastro")
async def fazer_cadastro(payload: CadastroPayload):
    resultado = register_user(payload.nome, payload.email, payload.senha)
    
    if resultado["status"] == "success":
        return {"status": "success", "mensagem": "Conta criada com sucesso! Faça login."}
    else:
        raise HTTPException(status_code=400, detail=resultado["message"])