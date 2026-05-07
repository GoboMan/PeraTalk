-- Public dictionary pack files (lemma JSON). See docs/アーキテクチャ/データベース設計-サーバー.md §辞書パック
-- Upload payloads under packs/… and manifests under manifests/… from Dashboard → Storage.

insert into storage.buckets (id, name, public)
values ('dictionary-packs', 'dictionary-packs', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "dictionary_packs_public_read" on storage.objects;
create policy "dictionary_packs_public_read"
  on storage.objects
  for select
  to public
  using (bucket_id = 'dictionary-packs');
