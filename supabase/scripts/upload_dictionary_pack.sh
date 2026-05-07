#!/usr/bin/env bash
# Storage の dictionary-packs にペイロード JSON とマニフェスト JSON をアップロードする。
#
# 前提:
#   - バケット dictionary-packs が存在すること（migrations で作成）
#   - アップロードには service_role キーが必要（Dashboard → Settings → API）
#
# 使い方（リポジトリルートで）:
#   export SUPABASE_URL='https://xxxx.supabase.co'
#   export SUPABASE_SERVICE_ROLE_KEY='eyJ...'
#   bash supabase/scripts/upload_dictionary_pack.sh
#
# オプション例:
#   bash supabase/scripts/upload_dictionary_pack.sh \
#     --pack PeraTalk/Resources/dictionary_scaffold_pack.json \
#     --payload-object packs/en_lemmas/scaffold.json \
#     --manifest-object manifests/en_lemmas.json
#
# Supabase CLI がリンク済みなら（storage cp は要 --experimental）例:
#   cd /path/to/PeraTalk
#   export SUPABASE_URL='https://xxxx.supabase.co'
#   bash supabase/scripts/write_en_lemmas_manifest.sh
#   supabase storage cp --experimental ./PeraTalk/Resources/dictionary_scaffold_pack.json \
#     ss:///dictionary-packs/packs/en_lemmas/scaffold.json
#   supabase storage cp --experimental ./manifests/en_lemmas.json \
#     ss:///dictionary-packs/manifests/en_lemmas.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACK_JSON="${REPO_ROOT}/PeraTalk/Resources/dictionary_scaffold_pack.json"
PAYLOAD_OBJECT="packs/en_lemmas/scaffold.json"
MANIFEST_OBJECT="manifests/en_lemmas.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pack)
      PACK_JSON="$2"
      shift 2
      ;;
    --payload-object)
      PAYLOAD_OBJECT="$2"
      shift 2
      ;;
    --manifest-object)
      MANIFEST_OBJECT="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '1,22p' "$0"
      exit 0
      ;;
    *)
      echo "未知の引数: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "SUPABASE_URL と SUPABASE_SERVICE_ROLE_KEY を環境変数で設定してください。" >&2
  exit 1
fi

BASE="${SUPABASE_URL%/}"

if [[ ! -f "$PACK_JSON" ]]; then
  echo "パックファイルが見つかりません: $PACK_JSON" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 が必要です。" >&2
  exit 1
fi

PACK_KEY="$(
  PACK_JSON="$PACK_JSON" python3 -c "
import json, os
with open(os.environ['PACK_JSON'], encoding='utf-8') as f:
    d = json.load(f)
print(d.get('pack_key', ''))
"
)"
PACK_VERSION="$(
  PACK_JSON="$PACK_JSON" python3 -c "
import json, os
with open(os.environ['PACK_JSON'], encoding='utf-8') as f:
    d = json.load(f)
print(d.get('pack_version', ''))
"
)"

SHA_HEX="$(shasum -a 256 "$PACK_JSON" | awk '{print $1}')"
PUBLIC_PAYLOAD_URL="${BASE}/storage/v1/object/public/dictionary-packs/${PAYLOAD_OBJECT}"

upload_object() {
  local relative_path="$1"
  local local_file="$2"
  local mime="$3"
  curl -fsS -X POST \
    "${BASE}/storage/v1/object/dictionary-packs/${relative_path}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
    -H "Content-Type: ${mime}" \
    -H "x-upsert: true" \
    --data-binary @"${local_file}"
}

MANIFEST_TMP="$(mktemp)"
trap 'rm -f "$MANIFEST_TMP"' EXIT

PACK_KEY="$PACK_KEY" PACK_VERSION="$PACK_VERSION" SHA_HEX="$SHA_HEX" PUBLIC_PAYLOAD_URL="$PUBLIC_PAYLOAD_URL" MANIFEST_TMP="$MANIFEST_TMP" python3 -c "
import json, os
m = {
    'pack_key': os.environ['PACK_KEY'],
    'pack_version': os.environ['PACK_VERSION'],
    'sha256': os.environ['SHA_HEX'],
    'pack_download_url': os.environ['PUBLIC_PAYLOAD_URL'],
}
with open(os.environ['MANIFEST_TMP'], 'w', encoding='utf-8') as f:
    json.dump(m, f, ensure_ascii=False, indent=2)
    f.write('\n')
"

echo "アップロード: ペイロード → dictionary-packs/${PAYLOAD_OBJECT}"
upload_object "$PAYLOAD_OBJECT" "$PACK_JSON" "application/json"
echo ""

echo "アップロード: マニフェスト → dictionary-packs/${MANIFEST_OBJECT}"
upload_object "$MANIFEST_OBJECT" "$MANIFEST_TMP" "application/json"
echo ""

echo "完了。"
echo "  公開ペイロード URL: ${PUBLIC_PAYLOAD_URL}"
echo "  公開マニフェスト URL: ${BASE}/storage/v1/object/public/dictionary-packs/${MANIFEST_OBJECT}"
echo ""
echo "メモ: アプリの「サーバーから辞書を同期」はカタログの pack_key=en_lemmas で manifests/en_lemmas.json を開きます。"
echo "ペイロード JSON 内の pack_key は '${PACK_KEY}'（マニフェストと一致済み）。"
