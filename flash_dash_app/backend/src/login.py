from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import re
import secrets

from db_repository import buscar_usuario_por_email, criar_usuario, verificar_senha

router = APIRouter()


class LoginPayload(BaseModel):
    email: str
    senha: str


class CadastroPayload(BaseModel):
    nome: str
    email: str
    senha: str


def _validar_email(email):
    return re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", email.strip()) is not None


def _usuario_publico(usuario):
    return {
        "id": usuario.get("id"),
        "nome": usuario.get("nome"),
        "email": usuario.get("email"),
    }


@router.post("/cadastro")
async def cadastrar_usuario(payload: CadastroPayload):
    nome = payload.nome.strip()
    email = payload.email.strip().lower()
    senha = payload.senha

    if len(nome) < 2:
        raise HTTPException(status_code=400, detail="Informe um nome valido")
    if not _validar_email(email):
        raise HTTPException(status_code=400, detail="Informe um e-mail valido")
    if len(senha) < 6:
        raise HTTPException(status_code=400, detail="A senha deve ter pelo menos 6 caracteres")

    usuario_existente = buscar_usuario_por_email(email)
    if usuario_existente:
        raise HTTPException(status_code=409, detail="Ja existe uma conta com este e-mail")

    usuario = criar_usuario(nome, email, senha)
    if not usuario:
        raise HTTPException(status_code=500, detail="Nao foi possivel criar o usuario")

    return {
        "status": "success",
        "mensagem": "Usuario cadastrado com sucesso!",
        "usuario": _usuario_publico(usuario),
        "token": secrets.token_urlsafe(32),
    }


@router.post("/login")
async def fazer_login(payload: LoginPayload):
    email = payload.email.strip().lower()
    usuario = buscar_usuario_por_email(email)

    if not usuario or not verificar_senha(payload.senha, usuario.get("senha_hash", "")):
        raise HTTPException(status_code=401, detail="E-mail ou senha incorretos")

    return {
        "status": "success",
        "mensagem": "Bem-vindo ao Flash Dash!",
        "usuario": _usuario_publico(usuario),
        "token": secrets.token_urlsafe(32),
    }
