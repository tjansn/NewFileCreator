#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEDIA_DIR="$ROOT_DIR/media"
FRAME_DIR="$MEDIA_DIR/frames"
FPS=24
FRAMES=144
WIDTH=1280
HEIGHT=720

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "rsvg-convert is required. Install it with: brew install librsvg"
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required. Install it with: brew install ffmpeg"
  exit 1
fi

mkdir -p "$FRAME_DIR"

progress() {
  local frame="$1"
  local start="$2"
  local end="$3"

  if (( frame <= start )); then
    echo 0
  elif (( frame >= end )); then
    echo 100
  else
    echo $(( (frame - start) * 100 / (end - start) ))
  fi
}

opacity() {
  awk "BEGIN { printf \"%.2f\", $1 / 100 }"
}

for ((frame = 0; frame < FRAMES; frame++)); do
  context_opacity=0
  new_file_opacity=0

  if (( frame >= 24 && frame < 80 )); then
    context_opacity=$(opacity "$(progress "$frame" 24 36)")
  fi

  if (( frame >= 84 )); then
    new_file_opacity=$(opacity "$(progress "$frame" 84 104)")
  fi

  cursor_x=790
  cursor_y=354

  if (( frame < 24 )); then
    cursor_x=$(( 560 + frame * 9 ))
    cursor_y=$(( 468 - frame * 5 ))
  elif (( frame < 62 )); then
    cursor_x=780
    cursor_y=344
  elif (( frame < 80 )); then
    cursor_x=798
    cursor_y=386
  else
    cursor_x=840
    cursor_y=392
  fi

  frame_svg="$FRAME_DIR/frame-$(printf "%04d" "$frame").svg"
  frame_png="$FRAME_DIR/frame-$(printf "%04d" "$frame").png"

  cat > "$frame_svg" << SVG
<svg xmlns="http://www.w3.org/2000/svg" width="$WIDTH" height="$HEIGHT" viewBox="0 0 $WIDTH $HEIGHT">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1280" y2="720" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#edf3f7"/>
      <stop offset="1" stop-color="#d8e3ea"/>
    </linearGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="18" stdDeviation="22" flood-color="#263446" flood-opacity="0.22"/>
    </filter>
  </defs>

  <rect width="1280" height="720" fill="url(#bg)"/>

  <rect x="130" y="86" width="1020" height="548" rx="18" fill="#f8fbfd" filter="url(#shadow)"/>
  <rect x="130" y="86" width="1020" height="56" rx="18" fill="#edf3f7"/>
  <circle cx="162" cy="114" r="7" fill="#ff5f57"/>
  <circle cx="186" cy="114" r="7" fill="#ffbd2e"/>
  <circle cx="210" cy="114" r="7" fill="#28c840"/>
  <text x="640" y="121" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="16" font-weight="600" fill="#455468">Projects</text>

  <rect x="130" y="142" width="210" height="492" fill="#eef4f7"/>
  <text x="168" y="194" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="16" font-weight="600" fill="#506176">Favorites</text>
  <text x="168" y="235" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="15" fill="#506176">Desktop</text>
  <text x="168" y="274" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="15" fill="#506176">Documents</text>
  <rect x="150" y="300" width="166" height="34" rx="8" fill="#d8e8f4"/>
  <text x="168" y="322" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="15" font-weight="600" fill="#20516b">Projects</text>

  <rect x="386" y="192" width="150" height="128" rx="14" fill="#e8eef4"/>
  <path d="M410 226h104v72H410z" fill="#d0dbe7"/>
  <path d="M410 226h46l16 18h42v20H410z" fill="#4e8db4"/>
  <text x="461" y="352" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="15" fill="#425466">Assets</text>

  <rect x="592" y="192" width="150" height="128" rx="14" fill="#e8eef4"/>
  <path d="M616 226h104v72H616z" fill="#d0dbe7"/>
  <path d="M616 226h46l16 18h42v20H616z" fill="#4e8db4"/>
  <text x="667" y="352" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="15" fill="#425466">Docs</text>

  <rect x="798" y="192" width="150" height="128" rx="14" fill="#e8eef4"/>
  <path d="M822 226h104v72H822z" fill="#d0dbe7"/>
  <path d="M822 226h46l16 18h42v20H822z" fill="#4e8db4"/>
  <text x="873" y="352" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="15" fill="#425466">Notes</text>

  <g opacity="$new_file_opacity">
    <rect x="386" y="420" width="150" height="128" rx="14" fill="#dff3fb" stroke="#2087a6" stroke-width="3"/>
    <path d="M426 444h64l38 38v66H426z" fill="#ffffff" stroke="#a6bdd1" stroke-width="2"/>
    <path d="M490 444v38h38" fill="#dce9f3"/>
    <rect x="444" y="496" width="58" height="7" rx="3.5" fill="#9aafbf"/>
    <rect x="444" y="518" width="72" height="7" rx="3.5" fill="#9aafbf"/>
    <rect x="404" y="578" width="114" height="28" rx="8" fill="#197fa0"/>
    <text x="461" y="597" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="14" font-weight="600" fill="#ffffff">Untitled.txt</text>
  </g>

  <g opacity="$context_opacity">
    <rect x="776" y="334" width="244" height="138" rx="12" fill="#ffffff" stroke="#c8d4df" filter="url(#shadow)"/>
    <rect x="786" y="374" width="224" height="34" rx="8" fill="#197fa0" opacity="0.95"/>
    <text x="806" y="360" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="15" fill="#2c3a48">Open</text>
    <text x="806" y="396" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="15" font-weight="600" fill="#ffffff">New File</text>
    <text x="806" y="432" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="15" fill="#2c3a48">New Markdown File</text>
    <line x1="792" y1="444" x2="1004" y2="444" stroke="#d8e1e8"/>
    <text x="806" y="464" font-family="-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif" font-size="15" fill="#2c3a48">Get Info</text>
  </g>

  <path d="M$cursor_x $cursor_y l0 42 l12 -12 l10 22 l12 -6 l-10 -22 l17 0 z" fill="#111827" stroke="#ffffff" stroke-width="3"/>
</svg>
SVG

  rsvg-convert --width "$WIDTH" --height "$HEIGHT" --output "$frame_png" "$frame_svg"
done

ffmpeg -y -hide_banner -loglevel error \
  -framerate "$FPS" \
  -i "$FRAME_DIR/frame-%04d.png" \
  -vf "format=yuv420p" \
  -movflags +faststart \
  "$MEDIA_DIR/demo.mp4"

ffmpeg -y -hide_banner -loglevel error \
  -i "$MEDIA_DIR/demo.mp4" \
  -vf "fps=12,scale=960:-1:flags=lanczos" \
  "$MEDIA_DIR/demo.gif"

echo "Generated $MEDIA_DIR/demo.mp4"
echo "Generated $MEDIA_DIR/demo.gif"
