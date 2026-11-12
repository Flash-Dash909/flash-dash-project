import base64
import hashlib
import hmac
import json
import os
import time
from pathlib import Path

from fastapi import Header, HTTPException
from dotenv import load_dotenv


load_dotenv(Path(__file__).resolve().parents[1] / ".env")


def _secret() -> bytes:
    value = os.getenv("APP_SECRET") or os.getenv("SUPABASE_KEY")
    if not value:
        raise RuntimeError("Configure APP_SECRET no backend/.env")
    return value.encode("utf-8")


def _b64encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


def _b64decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


def criar_token(usuario_id: str) -> str:
    payload = json.dumps(
        {"sub": str(usuario_id), "exp": int(time.time()) + 60 * 60 * 24 * 7},
        separators=(",", ":"),
    ).encode("utf-8")
    body = _b64encode(payload)
    signature = _b64encode(hmac.new(_secret(), body.encode("ascii"), hashlib.sha256).digest())
    return f"{body}.{signature}"


def verificar_token(token: str) -> str:
    try:
        body, signature = token.split(".", 1)
        expected = _b64encode(hmac.new(_secret(), body.encode("ascii"), hashlib.sha256).digest())
        if not hmac.compare_digest(signature, expected):
            raise ValueError("assinatura invalida")
        payload = json.loads(_b64decode(body))
        if int(payload["exp"]) < int(time.time()):
            raise ValueError("token expirado")
        return str(payload["sub"])
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Sessao invalida ou expirada") from exc


def usuario_autenticado(authorization: str | None = Header(None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Autenticacao obrigatoria")
    return verificar_token(authorization.removeprefix("Bearer ").strip())
