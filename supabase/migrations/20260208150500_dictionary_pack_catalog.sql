-- Catalog of remote dictionary packs (manifest path inside dictionary-packs bucket).

create table if not exists public.dictionary_pack_catalog (
  pack_key text primary key,
  pack_version text not null default '0.0.0',
  sha256 text,
  manifest_path text not null,
  updated_at timestamptz not null default now()
);

comment on table public.dictionary_pack_catalog is 'Points to manifest JSON in Storage bucket dictionary-packs; client resolves public URL and uses DictionaryPackImportService.';

alter table public.dictionary_pack_catalog enable row level security;

drop policy if exists "dictionary_pack_catalog_public_read" on public.dictionary_pack_catalog;
create policy "dictionary_pack_catalog_public_read"
  on public.dictionary_pack_catalog
  for select
  to anon, authenticated
  using (true);

-- No insert/update for anon: maintain rows via Dashboard SQL or service_role.

insert into public.dictionary_pack_catalog (pack_key, pack_version, sha256, manifest_path)
values ('en_lemmas', '1.0.0', null, 'manifests/en_lemmas.json')
on conflict (pack_key) do update set
  pack_version = excluded.pack_version,
  sha256 = excluded.sha256,
  manifest_path = excluded.manifest_path,
  updated_at = now();
