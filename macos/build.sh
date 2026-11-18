#!/bin/sh
# Build ISIDA/GTM on macOS (Apple Silicon or Intel).
#
#   macos/build.sh               build everything that can be built
#   macos/build.sh --fetch-deps  also clone the missing dependency repositories
#   macos/build.sh --cli-only    build only the command-line tools
#
# Requirements:
#   - Free Pascal 3.2.x and Lazarus (lazbuild) with the Cocoa widgetset
#       brew install fpc            (or fpcupdeluxe / the Lazarus installer)
#   - LLVM lld, needed to link the Cocoa GUI programs (see macos/linker/ld)
#       brew install lld
#   - The ISIDAKernel, ISIDAModelAnalyzerR and ISIDAModelAnalyzerC sources next
#     to this repository (the .lpi files refer to them with relative paths):
#       <parent>/ISIDAOpenGTM
#       <parent>/ISIDAKernel
#       <parent>/ModelAnalyzerR   (clone of ISIDAModelAnalyzerR)
#       <parent>/ModelAnalyzerC   (clone of ISIDAModelAnalyzerC)
#
# Results are collected in dist/macos/:
#   dist/macos/bin/      command-line tools (GTMapTool, GTMClass, GTMReg, ...)
#   dist/macos/*.app     graphical tools as double-clickable app bundles

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PARENT=$(dirname "$ROOT")
DIST="$ROOT/dist/macos"
LINKER_DIR="$ROOT/macos/linker"
GH=https://github.com/Laboratoire-de-Chemoinformatique

FETCH=0
CLI_ONLY=0
for a in "$@"; do
  case "$a" in
    --fetch-deps) FETCH=1 ;;
    --cli-only) CLI_ONLY=1 ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- toolchain -------------------------------------------------------------
find_lazbuild() {
  if [ -n "${LAZBUILD:-}" ]; then echo "$LAZBUILD"; return; fi
  for c in lazbuild "$HOME/Applications/lazarus/lazbuild" "$HOME/fpcupdeluxe/lazarus/lazbuild" \
           /Applications/Lazarus/lazbuild /Applications/lazarus/lazbuild /usr/local/bin/lazbuild; do
    p=$(command -v "$c" 2>/dev/null) && { echo "$p"; return; }
  done
}
LAZBUILD=$(find_lazbuild)
[ -n "$LAZBUILD" ] || die "lazbuild not found. Install Lazarus or set LAZBUILD=/path/to/lazbuild."
say "lazbuild: $LAZBUILD"

if [ $CLI_ONLY -eq 0 ]; then
  chmod +x "$LINKER_DIR/ld"
  if ! command -v ld64.lld >/dev/null 2>&1 && [ ! -x /opt/homebrew/opt/lld/bin/ld64.lld ] \
     && [ ! -x /usr/local/opt/lld/bin/ld64.lld ] && [ -z "${GTM_LLD:-}" ]; then
    die "ld64.lld not found; it is needed to link the GUI programs. Run 'brew install lld' (or use --cli-only)."
  fi
fi

# --- dependencies ----------------------------------------------------------
need_dep() { # <folder name> <repository name>
  if [ ! -d "$PARENT/$1" ]; then
    if [ $FETCH -eq 1 ]; then
      say "Cloning $2 into $PARENT/$1"
      git clone --depth 1 "$GH/$2.git" "$PARENT/$1" || die "could not clone $2"
    else
      die "missing $PARENT/$1 (clone $GH/$2 there, or rerun with --fetch-deps)"
    fi
  fi
}
need_dep ISIDAKernel ISIDAKernel
need_dep ModelAnalyzerR ISIDAModelAnalyzerR
need_dep ModelAnalyzerC ISIDAModelAnalyzerC

# --- build -----------------------------------------------------------------
# lazbuild rewrites the version information in the .res files; keep the
# working tree clean by restoring them afterwards.
RESBAK=$(mktemp -d "${TMPDIR:-/tmp}/gtmres.XXXXXX")
(cd "$ROOT" && find . -name '*.res' -not -path './dist/*' -not -path '*/lib/*' -print | while read -r f; do
  mkdir -p "$RESBAK/$(dirname "$f")"; cp -p "$f" "$RESBAK/$f"; done)
restore_res() { (cd "$RESBAK" && find . -type f | while read -r f; do cp -p "$f" "$ROOT/$f"; done); rm -rf "$RESBAK"; }
trap restore_res EXIT INT TERM

LOGDIR="$DIST/logs"
mkdir -p "$DIST/bin" "$LOGDIR"
OK=""
FAILED=""

build() { # <lpi> <cli|gui>
  lpi=$1; kind=$2
  name=$(basename "$lpi" .lpi)
  log="$LOGDIR/$name.log"
  if [ "$kind" = gui ]; then
    set -- --ws=cocoa "--opt=-FD$LINKER_DIR"
  else
    # Some command-line projects list the LCL as a dependency; without a
    # widgetset they fail to link (missing WSRegister* symbols).
    set -- --ws=nogui
  fi
  printf '  %-16s ' "$name"
  # -B: rebuild every unit. The command-line and GUI variants of a tool share
  # the same unit output folder but are compiled with different defines.
  if "$LAZBUILD" -B "$@" "$ROOT/$lpi" >"$log" 2>&1; then
    say "ok"
    OK="$OK $name"
  else
    say "FAILED (see $log)"
    grep -E 'Error:|Fatal:' "$log" | head -3 | sed 's/^/      /'
    FAILED="$FAILED $name"
    return 1
  fi
}

make_app() { # <binary path> <name>
  bin=$1; name=$2
  app="$DIST/$name.app"
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cp "$bin" "$app/Contents/MacOS/$name"
  printf 'APPL????' > "$app/Contents/PkgInfo"
  # No NSPrincipalClass key: with it, AppKit creates a plain NSApplication
  # before the LCL can create its own subclass, and Application.Run then
  # aborts with "-[NSApplication lclSetLCLMainLoop:]: unrecognized selector".
  cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>English</string>
  <key>CFBundleExecutable</key><string>$name</string>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundleIdentifier</key><string>fr.unistra.isida.$(echo "$name" | tr 'A-Z' 'a-z')</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF
  # Sign the whole bundle (ad hoc) so the signature covers Info.plist.
  codesign --force --sign - "$app" >/dev/null 2>&1 || say "      (warning: codesign failed for $name.app)"
}

say ""
say "Command-line tools:"
for p in GTMapTool/GTMapTool.lpi GTMClass/GTMClass.lpi GTMReg/GTMReg.lpi \
         GTMReSample/GTMReSample.lpi GTMNodeSelect/GTMNodeSelect.lpi SGTM/SGTM.lpi; do
  if build "$p" cli; then
    cp "$ROOT/$(dirname "$p")/$(basename "$p" .lpi)" "$DIST/bin/"
  fi
done

if [ $CLI_ONLY -eq 0 ]; then
  say ""
  say "Graphical tools:"
  for p in GTMapTool/xgtmaptool/xGTMapTool.lpi GTMClass/xGTMClass.lpi GTMReg/xGTMReg.lpi \
           GTMReSample/xGTMReSample.lpi GTMNodeSelect/xGTMNodeSelect.lpi GTMmanifold/GTMmanifold.lpi; do
    if build "$p" gui; then
      n=$(basename "$p" .lpi)
      make_app "$ROOT/$(dirname "$p")/$n" "$n"
    fi
  done
fi

say ""
say "Not built (their dependencies are not publicly available or not packaged for Lazarus 4 / Cocoa):"
say "  xGTMView, xGTMLandscape  need the private 'Molecule' sources"
say "  KGTM                     needs a newer ISIDAKernel (TKPCAStream API) than the public one"
say "  GTMGui                   needs the BGRABitmap / BGLControls packages"
say ""
say "Built:${OK:- nothing}"
[ -z "$FAILED" ] || say "Failed:$FAILED"
say "Output: $DIST"
say ""
say "The programs check for a licence file at ~/.config/ISIDAGTM/licence.dat."
say "How to install the licence and run the programs: macos/SETUP.md"
[ -z "$FAILED" ]
