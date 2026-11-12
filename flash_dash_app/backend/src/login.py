from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
import os
import re
import secrets

from google.oauth2 import id_token
from google.auth.transport import requests as google_requests

from db_repository import (
    atualizar_usuario,
    buscar_usuario_por_email,
    buscar_usuario_por_id,
    criar_usuario,
    verificar_senha,
)
from auth_service import criar_token, usuario_autenticado

router = APIRouter()


class LoginPayload(BaseModel):
    email: str
    senha: str


class CadastroPayload(BaseModel):
    nome: str
    email: str
    senha: str


class GoogleLoginPayload(BaseModel):
    token: str


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
        "token": criar_token(usuario.get("id")),
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
        "token": criar_token(usuario.get("id")),
    }

@router.post("/google")
async def login_google(payload: GoogleLoginPayload):
    try:
        client_id = os.getenv(
            "GOOGLE_CLIENT_ID",
            "191150128104-28vgeh8p0pm3heti252b7e9t17c16km6.apps.googleusercontent.com",
        )
        try:
            google_data = id_token.verify_oauth2_token(
                payload.token,
                google_requests.Request(),
                client_id,
            )
        except ValueError as exc:
            raise HTTPException(
                status_code=401,
                detail="Token do Google inválido ou expirado",
            ) from exc

        email = google_data.get("email")
        nome = google_data.get("name", "Usuário Google")
        foto_url = google_data.get("picture")

        if not email:
            raise HTTPException(status_code=400, detail="E-mail não fornecido pelo Google")
        if google_data.get("email_verified") is False:
            raise HTTPException(status_code=401, detail="E-mail do Google não verificado")

        email = email.strip().lower()
        usuario = buscar_usuario_por_email(email)

        # Se o usuário ainda não tem conta no sistema, criamos uma automaticamente
        if not usuario:
            senha_aleatoria = secrets.token_urlsafe(32)
            usuario = criar_usuario(nome, email, senha_aleatoria)

            if not usuario:
                raise HTTPException(status_code=500, detail="Não foi possível criar o usuário via Google")

        if foto_url and not usuario.get("foto_url"):
            atualizar_usuario(usuario.get("id"), {"foto_url": foto_url})
            usuario["foto_url"] = foto_url

        return {
            "status": "success",
            "mensagem": "Login com Google realizado com sucesso!",
            "usuario": _usuario_publico(usuario),
            "usuario_id": usuario.get("id"),
            "usuario_nome": usuario.get("nome"),
            "token": criar_token(usuario.get("id")),
        }

    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail="Não foi possível autenticar com o Google",
        ) from exc

@router.get("/perfil/{usuario_id}")
async def obter_perfil(
    usuario_id: str,
    usuario_token: str = Depends(usuario_autenticado),
):
    if usuario_id != usuario_token:
        raise HTTPException(status_code=403, detail="Acesso negado")
    usuario = buscar_usuario_por_id(usuario_id)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado")
    return {"status": "success", "usuario": _usuario_publico(usuario)}


@router.put("/perfil/{usuario_id}")
async def salvar_perfil(
    usuario_id: str,
    payload: PerfilPayload,
    usuario_token: str = Depends(usuario_autenticado),
):
    if usuario_id != usuario_token:
        raise HTTPException(status_code=403, detail="Acesso negado")
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
