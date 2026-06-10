create extension if not exists "pgcrypto";

create table if not exists public.usuarios (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  email text not null unique,
  senha_hash text not null,
  created_at timestamptz not null default now()
);

create index if not exists usuarios_email_idx on public.usuarios (email);
