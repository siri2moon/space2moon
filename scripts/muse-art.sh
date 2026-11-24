#!/bin/zsh
# Paints Space2Moon's brand art with Meta Muse through MoonReel's muse2api.
# Reads MUSE2API_BASE_URL and MUSE2API_KEY from MoonReel's .env without
# printing them. Images are painted one at a time.
#
#   ./scripts/muse-art.sh               paint every missing image
#   ./scripts/muse-art.sh icon-2 mage   repaint the named images
#   ./scripts/muse-art.sh --pick icon-2 make icon-2 the app icon (any painting works, e.g. mage)
#
# Outputs land in Resources/Art. Afterwards the icon (.icns) and the logo
# lockups (Resources/Brand) are rebuilt from whatever exists.
set -euo pipefail
root="${0:A:h}/.."
art="$root/Resources/Art"
mkdir -p "$art"

if [[ "${1:-}" == "--pick" ]]; then
  cp "$art/${2:?which image?}.png" "$art/icon.png"
  # icon-* paintings carry their own tile and margin; other art is full bleed.
  inset=0.055; [[ "$2" == icon-* ]] || inset=0
  print -r -- "$inset" > "$art/icon.inset"
  python3 "$root/scripts/make-icon.py" "$art/icon.png" "$root/Resources/AppIcon.icns" "$inset"
  exit 0
fi

env_file="${MOONREEL_ENV:-$root/../moonreel/moonreel-studio/.env}"
base="$(grep -E '^MUSE2API_BASE_URL=' "$env_file" | cut -d= -f2- | tr -d '"' || true)"
key="$(grep -E '^MUSE2API_KEY=' "$env_file" | cut -d= -f2- | tr -d '"')"
base="${base:-http://localhost:18610}"
base="${base%/}"

# The siri2moon mascot, used as a reference so Muse draws the same character.
siri="${SIRI_MASCOT:-$root/../siri2moon-channel-kit/channels/siri2moon/siri-mascot.png}"

look="deep indigo night sky, violet and cyan magical glow, soft gold accents, polished 3D render, smooth glossy materials, cinematic rim light, no text, no letters, no watermark"

typeset -A prompts ratios refs
prompts[icon-1]="macOS Big Sur style app icon: a luminous white crescent moon inside a thin golden circle of glowing runes, a spiral of tiny cubes and documents dissolving into cyan stardust and flowing up into the moon, rounded square tile with a dark indigo gradient, centered, bold simple silhouette readable at small size, $look"
ratios[icon-1]="1:1"
prompts[icon-2]="macOS Big Sur style app icon: a magic broom flying like a rocket toward a big glowing full moon, leaving a sparkling comet trail that fades from cyan to violet, rounded square tile with a dark indigo gradient, centered, bold simple silhouette readable at small size, $look"
ratios[icon-2]="1:1"
prompts[icon-3]="macOS Big Sur style app icon: the cute cat-eared astronaut robot from the reference image, wearing a small starry wizard hat, flying up toward a crescent moon on a green rocket flame while waving a glowing wand, rounded square tile with a dark indigo gradient, centered, $look"
ratios[icon-3]="1:1"
refs[icon-3]="$siri"
prompts[emblem]="minimal logo emblem: a crescent moon with a sparkling comet trail curving around it in a single elegant swoosh, cyan to violet gradient, a few tiny stars, flat vector style with a soft glow, centered, isolated on a pure black background, no text"
ratios[emblem]="1:1"
prompts[sanctum]="vast wizard's observatory at night seen from inside, a huge round window onto a swirling violet and cyan nebula and a giant glowing moon, faint floating golden runes and constellations, very dark edges, large calm empty areas, $look"
ratios[sanctum]="16:9"
prompts[mage]="the cute cat-eared astronaut robot from the reference image dressed as a friendly wizard: midnight blue robe with golden stars, pointed wizard hat, holding a broom made of cyan light that sweeps sparkles away, full body, floating, isolated on a pure black background, $look"
ratios[mage]="1:1"
refs[mage]="$siri"

paint() {
  local name=$1 out="$art/$1.png"
  [[ -n "${prompts[$name]:-}" ]] || { echo "✗ unknown image: $name"; return 1; }
  if [[ -f "$out" && -z "${force:-}" ]]; then echo "✓ $name exists"; return; fi
  echo "✦ painting $name…"
  local body task_id task_json url
  body=$(python3 - "${prompts[$name]}" "${ratios[$name]}" "${refs[$name]:-}" <<'PY'
import base64, json, sys
prompt, ratio, ref = sys.argv[1:4]
payload = {"prompt": prompt, "aspect_ratio": ratio}
if ref:
    payload["reference_image"] = "data:image/png;base64," + base64.b64encode(open(ref, "rb").read()).decode()
print(json.dumps(payload))
PY
)
  task_id=$(print -r -- "$body" | curl -sf -X POST "$base/v1/images/tasks" \
      -H "Authorization: Bearer $key" -H "Content-Type: application/json" --data-binary @- \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("id") or d.get("task_id"))')
  for _ in {1..90}; do
    sleep 5
    task_json=$(curl -sf "$base/v1/images/tasks/$task_id" -H "Authorization: Bearer $key")
    case $(print -r -- "$task_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status"))') in
      completed)
        url=$(print -r -- "$task_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print((d.get("data") or [{}])[0].get("url") or d.get("url"))')
        [[ "$url" == http* ]] || url="$base$url"
        curl -sf "$url" -H "Authorization: Bearer $key" -o "$out.tmp"
        sips -s format png "$out.tmp" --out "$out" >/dev/null && rm "$out.tmp"
        echo "✓ $name → Resources/Art/$name.png"
        return ;;
      failed)
        echo "✗ $name failed: $(print -r -- "$task_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("error"))')"
        return 1 ;;
    esac
  done
  echo "✗ $name timed out"; return 1
}

failed=0
if [[ $# -gt 0 ]]; then
  force=1
  for n in "$@"; do paint "$n" || failed=1; done
else
  for n in icon-1 icon-2 icon-3 emblem sanctum mage; do paint "$n" || failed=1; done
fi

# Default the app icon to the first variant until one is picked.
if [[ ! -f "$art/icon.png" && -f "$art/icon-1.png" ]]; then cp "$art/icon-1.png" "$art/icon.png"; fi
[[ -f "$art/icon.png" ]] && python3 "$root/scripts/make-icon.py" "$art/icon.png" "$root/Resources/AppIcon.icns" "$(cat "$art/icon.inset" 2>/dev/null || echo 0.055)"
[[ -f "$art/emblem.png" ]] && python3 "$root/scripts/make-logo.py" "$art/emblem.png" "$root/Resources/Brand"
# The mascot: subject lifted out with Vision, background fully transparent.
[[ -f "$art/mage.png" ]] && swift "$root/scripts/cutout.swift" "$art/mage.png" "$root/Resources/Brand/mage.png"
exit $failed
