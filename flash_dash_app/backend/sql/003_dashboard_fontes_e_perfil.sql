alter table public.dashboards
add column if not exists fonte_ids jsonb not null default '[]'::jsonb;

comment on column public.dashboards.fonte_ids is
  'IDs das fontes tratadas usadas pelo dashboard, incluindo modelos combinados.';

alter table public.usuarios
add column if not exists idade integer,
add column if not exists telefone text,
add column if not exists cargo text,
add column if not exists empresa text,
add column if not exists bio text,
add column if not exists foto_url text;

create index if not exists fontes_dados_usuario_created_idx
on public.fontes_dados (usuario_id, created_at desc);

create index if not exists dashboards_usuario_created_idx
on public.dashboards (usuario_id, created_at desc);
