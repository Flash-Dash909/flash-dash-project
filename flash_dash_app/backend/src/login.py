from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import re
import secrets

from db_repository import (
    atualizar_usuario,
    buscar_usuario_por_email,
    buscar_usuario_por_id,
    criar_usuario,
    verificar_senha,
)

router = APIRouter()


class LoginPayload(BaseModel):
    email: str
    senha: str


class CadastroPayload(BaseModel):
    nome: str
    email: str
    senha: str


class PerfilPayload(BaseModel):
    nome: str | None = None
    idade: int | None = None
    telefone: str | None = None
    cargo: str | None = None
    empresa: str | None = None
    bio: str | None = None
    foto_url: str | None = None


def _validar_email(email):
    return re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", email.strip()) is not None


def _usuario_publico(usuario):
    return {
        "id": usuario.get("id"),
        "nome": usuario.get("nome"),
        "email": usuario.get("email"),
        "idade": usuario.get("idade"),
        "telefone": usuario.get("telefone"),
        "cargo": usuario.get("cargo"),
        "empresa": usuario.get("empresa"),
        "bio": usuario.get("bio"),
        "foto_url": usuario.get("foto_url"),
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
        "usuario_id": usuario.get("id"),
        "usuario_nome": usuario.get("nome"),
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
        "usuario_id": usuario.get("id"),
        "usuario_nome": usuario.get("nome"),
        "token": secrets.token_urlsafe(32),
    }


@router.get("/perfil/{usuario_id}")
async def obter_perfil(usuario_id: str):
    usuario = buscar_usuario_por_id(usuario_id)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado")
    return {"status": "success", "usuario": _usuario_publico(usuario)}


@router.put("/perfil/{usuario_id}")
async def salvar_perfil(usuario_id: str, payload: PerfilPayload):
    dados = payload.model_dump(exclude_unset=True)
    if "nome" in dados and dados["nome"] is not None and len(dados["nome"].strip()) < 2:
        raise HTTPException(status_code=400, detail="Informe um nome valido")
    if "idade" in dados and dados["idade"] is not None and (dados["idade"] < 0 or dados["idade"] > 130):
        raise HTTPException(status_code=400, detail="Informe uma idade valida")

    usuario = atualizar_usuario(usuario_id, dados)
    if not usuario:
        raise HTTPException(status_code=500, detail="Nao foi possivel atualizar o perfil")
    return {
        "status": "success",
        "mensagem": "Perfil atualizado com sucesso",
        "usuario": _usuario_publico(usuario),
    }
