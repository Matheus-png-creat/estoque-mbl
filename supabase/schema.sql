-- =====================================================================
-- Estoque de Equipamentos · estrutura do banco no Supabase
-- Rode este arquivo inteiro uma vez em: Supabase → SQL Editor → New query
-- =====================================================================

-- ---------- Perfis de usuário (ADM / Comum / Pendente) ----------
create table if not exists public.perfis (
  id         uuid primary key references auth.users (id) on delete cascade,
  email      text,
  nome       text,
  foto       text,
  papel      text not null default 'pendente' check (papel in ('pendente', 'comum', 'adm', 'bloqueado')),
  criado_em  timestamptz not null default now()
);

-- ---------- Dados do sistema (itens, movimentações, externas, checkups, config) ----------
create table if not exists public.docs (
  colecao        text not null,
  id             text not null,
  data           jsonb not null default '{}'::jsonb,
  atualizado_em  timestamptz not null default now(),
  atualizado_por uuid default auth.uid(),
  primary key (colecao, id)
);
alter table public.docs replica identity full;

-- ---------- Funções de permissão ----------
create or replace function public.meu_papel() returns text
language sql stable security definer set search_path = public as $$
  select papel from public.perfis where id = auth.uid()
$$;

create or replace function public.is_membro() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select papel in ('comum', 'adm') from public.perfis where id = auth.uid()), false)
$$;

create or replace function public.is_adm() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select papel = 'adm' from public.perfis where id = auth.uid()), false)
$$;

-- ---------- Novo login: cria o perfil. O PRIMEIRO usuário vira ADM; os demais ficam pendentes ----------
create or replace function public.novo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform pg_advisory_xact_lock(424242);
  insert into public.perfis (id, email, nome, foto, papel)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', new.email),
    new.raw_user_meta_data ->> 'avatar_url',
    case when exists (select 1 from public.perfis where papel = 'adm') then 'pendente' else 'adm' end
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario after insert on auth.users
  for each row execute function public.novo_usuario();

-- ---------- Proteção: sempre precisa existir pelo menos um ADM ----------
create or replace function public.protege_ultimo_adm() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.papel = 'adm' and new.papel <> 'adm'
     and not exists (select 1 from public.perfis where papel = 'adm' and id <> old.id) then
    raise exception 'Precisa existir pelo menos um ADM.';
  end if;
  -- só o papel pode ser alterado pelo app
  new.id := old.id; new.email := old.email; new.criado_em := old.criado_em;
  return new;
end $$;

drop trigger if exists antes_atualizar_perfil on public.perfis;
create trigger antes_atualizar_perfil before update on public.perfis
  for each row execute function public.protege_ultimo_adm();

-- ---------- Regras de acesso (RLS) ----------
alter table public.perfis enable row level security;
alter table public.docs   enable row level security;

drop policy if exists "ver perfis" on public.perfis;
create policy "ver perfis" on public.perfis for select to authenticated
  using (id = auth.uid() or public.is_membro());

drop policy if exists "adm altera perfis" on public.perfis;
create policy "adm altera perfis" on public.perfis for update to authenticated
  using (public.is_adm()) with check (public.is_adm());

drop policy if exists "membros leem" on public.docs;
create policy "membros leem" on public.docs for select to authenticated
  using (public.is_membro());

drop policy if exists "membros criam" on public.docs;
create policy "membros criam" on public.docs for insert to authenticated
  with check (public.is_membro() and (colecao <> 'config' or public.is_adm()));

drop policy if exists "atualizar" on public.docs;
create policy "atualizar" on public.docs for update to authenticated
  using (public.is_adm() or (public.is_membro() and colecao in ('externas', 'checkups')))
  with check (public.is_adm() or (public.is_membro() and colecao in ('externas', 'checkups')));

drop policy if exists "adm apaga" on public.docs;
create policy "adm apaga" on public.docs for delete to authenticated
  using (public.is_adm());

revoke all on public.docs, public.perfis from anon;

-- ---------- Tempo real ----------
do $$ begin
  begin alter publication supabase_realtime add table public.docs;   exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.perfis; exception when duplicate_object then null; end;
end $$;

-- ---------- Fotos (Storage, bucket privado) ----------
insert into storage.buckets (id, name, public)
values ('fotos', 'fotos', false)
on conflict (id) do nothing;

drop policy if exists "membros veem fotos" on storage.objects;
create policy "membros veem fotos" on storage.objects for select to authenticated
  using (bucket_id = 'fotos' and public.is_membro());

drop policy if exists "membros enviam fotos" on storage.objects;
create policy "membros enviam fotos" on storage.objects for insert to authenticated
  with check (bucket_id = 'fotos' and public.is_membro());

drop policy if exists "adm apaga fotos" on storage.objects;
create policy "adm apaga fotos" on storage.objects for delete to authenticated
  using (bucket_id = 'fotos' and public.is_adm());
