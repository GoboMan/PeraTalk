-- PeraTalk: profiles に INSERT 用 RLS ポリシーを追加し、クライアント側から
-- Sign in with Apple 直後に profiles 行を upsert（保険）できるようにする。
-- 既存の on_auth_user_created トリガが効いていればクライアント側 upsert は no-op だが、
-- トリガ未適用環境でも初回ログイン時に行が確実に作成されるようにする。

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);
