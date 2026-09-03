alter table public.dashboards
add column if not exists metricas_calculadas jsonb not null default '[]'::jsonb;

comment on column public.dashboards.metricas_calculadas is
  'Metricas calculadas reutilizaveis dentro de um dashboard. Cada item possui name e formula.';
