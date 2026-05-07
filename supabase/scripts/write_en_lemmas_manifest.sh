#!/usr/bin/env bash
# カタログの manifest_path（既定: manifests/en_lemmas.json）と整合するマニフェストを
# リポジトリ直下 manifests/en_lemmas.json に書き出す。
# ペイロードは Storage 上 packs/en_lemmas/scaffold.json を指す（既に cp 済み想定）。
#
#   export SUPABASE_URL='https://xxxx.supabase.co'
#   bash supabase/scripts/write_en_lemmas_manifest.sh
#
# 続けて:
#   supabase storage cp --experimental ./manifests/en_lemmas.json \
#     ss:///dictionary-packs/manifests/en_lemmas.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACK_JSON="${REPO_ROOT}/PeraTalk/Resources/dictionary_scaffold_pack.json"
PAYLOAD_OBJECT="packs/en_lemmas/scaffold.json"
OUT_FILE="${REPO_ROOT}/manifests/en_lemmas.json"

if [[ -z "${SUPABASE_URL:-}" ]]; then
  echo "SUPABASE_URL を設定してください（例: https://xxxx.supabase.co）" >&2
  exit 1
fi

if [[ ! -f "$PACK_JSON" ]]; then
  echo "ペイロード元 JSON が見つかりません: $PACK_JSON" >&2
  exit 1
fi

BASE="${SUPABASE_URL%/}"
PUBLIC_PAYLOAD_URL="${BASE}/storage/v1/object/public/dictionary-packs/${PAYLOAD_OBJECT}"
SHA_HEX="$(shasum -a 256 "$PACK_JSON" | awk '{print $1}')"

mkdir -p "$(dirname "$OUT_FILE")"

PACK_KEY="$(PACK_JSON="$PACK_JSON" python3 -c "
import json, os
with open(os.environ['PACK_JSON'], encoding='utf-8') as f:
    print(json.load(f)['pack_key'])
")"
PACK_VERSION="$(PACK_JSON="$PACK_JSON" python3 -c "
import json, os
with open(os.environ['PACK_JSON'], encoding='utf-8') as f:
    print(json.load(f)['pack_version'])
")"

PACK_KEY="$PACK_KEY" PACK_VERSION="$PACK_VERSION" SHA_HEX="$SHA_HEX" PUBLIC_PAYLOAD_URL="$PUBLIC_PAYLOAD_URL" OUT_FILE="$OUT_FILE" python3 -c "
import json, os
m = {
    'pack_key': os.environ['PACK_KEY'],
    'pack_version': os.environ['PACK_VERSION'],
    'sha256': os.environ['SHA_HEX'],
    'pack_download_url': os.environ['PUBLIC_PAYLOAD_URL'],
}
with open(os.environ['OUT_FILE'], 'w', encoding='utf-8') as f:
    json.dump(m, f, ensure_ascii=False, indent=2)
    f.write('\n')
"

echo "書き出し: $OUT_FILE"
echo "  pack_download_url → $PUBLIC_PAYLOAD_URL"
