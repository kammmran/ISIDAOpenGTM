#!/bin/sh
# Cross-compile ISIDA/GTM for Windows (64-bit .exe) on macOS or Linux.
#
#   windows/build.sh               build everything that can be built
#   windows/build.sh --fetch-deps  also clone the missing dependency repositories
#   windows/build.sh --cli-only    build only the command-line tools
#   windows/build.sh --zip         also pack the result into dist/ISIDAGTM-windows-x64.zip
#
# Requirements:
#   - Lazarus (lazbuild)
#   - the Free Pascal compiler for x86_64 (ppcx64); on Apple Silicon it runs
#     under Rosetta. It can produce Windows programs without extra tools.
#   - the Free Pascal sources of the same version, to compile its run-time
#     library for Windows. Set FPCSRC if they are not found automatically.
#   - The ISIDAKernel, ISIDAModelAnalyzerR and ISIDAModelAnalyzerC sources next
#     to this repository (see macos/build.sh; --fetch-deps clones them).
#
# The first run compiles the Free Pascal units for Windows into
# ~/.cache/isidagtm/fpc-cross (set GTM_CROSS_DIR to change it), and Lazarus
# compiles its LCL for Windows into its own folder. Later runs reuse both.
#
# Results are collected in dist/windows/ (all the .exe files in one folder).
#
# On Windows itself this script is not needed: open the .lpi files in Lazarus,
# or run "lazbuild <project>.lpi". See windows/SETUP.md.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PARENT=$(dirname "$ROOT")
DIST="$ROOT/dist/windows"
ZIPFILE="$ROOT/dist/ISIDAGTM-windows-x64.zip"
CROSS=${GTM_CROSS_DIR:-$HOME/.cache/isidagtm/fpc-cross}
TARGET=x86_64-win64
GH=https://github.com/Laboratoire-de-Chemoinformatique

FETCH=0
CLI_ONLY=0
ZIP=0
for a in "$@"; do
  case "$a" in
    --fetch-deps) FETCH=1 ;;
    --cli-only) CLI_ONLY=1 ;;
    --zip) ZIP=1 ;;
    -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
LAZDIR=$(cd "$(dirname "$LAZBUILD")" && pwd)
say "lazbuild: $LAZBUILD"

find_ppcx64() {
  if [ -n "${PPCX64:-}" ]; then echo "$PPCX64"; return; fi
  for c in ppcx64 /usr/local/lib/fpc/*/ppcx64 /usr/lib/fpc/*/ppcx64 /usr/lib/x86_64-linux-gnu/fpc/*/ppcx64 \
           "$HOME"/fpcupdeluxe/fpc/bin/*/ppcx64; do
    p=$(command -v "$c" 2>/dev/null) && { echo "$p"; return; }
  done
}
PPCX64=$(find_ppcx64)
[ -n "$PPCX64" ] || die "ppcx64 (Free Pascal compiler for x86_64) not found. Install it or set PPCX64=/path/to/ppcx64."
FPCVER=$("$PPCX64" -iV 2>/dev/null)
[ -n "$FPCVER" ] || die "$PPCX64 does not run (on Apple Silicon it needs Rosetta: softwareupdate --install-rosetta)."
say "ppcx64:   $PPCX64 ($FPCVER)"

UNITS="$CROSS/lib/fpc/$FPCVER/units/$TARGET"
FPCWIN="$CROSS/bin/fpc-win64"

# --- Free Pascal units for Windows -----------------------------------------
find_fpcsrc() {
  for d in "${FPCSRC:-}" "$LAZDIR/fpc/$FPCVER/sources" "$LAZDIR/../fpcsrc" "$HOME/fpcupdeluxe/fpcsrc" \
           "/usr/local/share/fpcsrc/$FPCVER" /usr/local/share/fpcsrc "/usr/share/fpcsrc/$FPCVER" /usr/share/fpcsrc; do
    [ -n "$d" ] && [ -d "$d/rtl/win64" ] && [ -d "$d/packages/fpmkunit" ] || continue
    # the compiled units must match the compiler, so the versions must agree
    grep -q "^version=$FPCVER" "$d/Makefile.fpc" 2>/dev/null && { echo "$d"; return; }
  done
}

# A compiler that produces programs for this computer, to build FPC's "fpmake".
find_native_fpc() {
  if [ -n "${FPCFPMAKE:-}" ]; then echo "$FPCFPMAKE"; return; fi
  case "$(uname -m)" in
    arm64|aarch64)
      for c in "$(dirname "$PPCX64")/ppca64" "/usr/local/lib/fpc/$FPCVER/ppca64" ppca64; do
        p=$(command -v "$c" 2>/dev/null) && [ "$("$p" -iV 2>/dev/null)" = "$FPCVER" ] && { echo "$p"; return; }
      done ;;
  esac
  echo "$PPCX64"
}

build_units() {
  src=$(find_fpcsrc)
  [ -n "$src" ] || die "Free Pascal $FPCVER sources not found. Set FPCSRC=/path/to/fpc/sources (the folder with rtl/ and packages/)."
  native=$(find_native_fpc)
  say "Compiling the Free Pascal $FPCVER units for Windows (about a minute)"
  say "  sources: $src"
  say "  into:    $CROSS"
  work="$CROSS/build"
  rm -rf "$work"
  mkdir -p "$work" || die "cannot create $work"
  # Work on a copy: the build writes its output next to the sources.
  cp -R "$src/rtl" "$src/packages" "$src/Makefile" "$src/Makefile.fpc" "$src"/fpmake* "$work/" \
    || die "cannot copy the Free Pascal sources"
  # FPC's text-mode IDE needs the compiler sources and is of no use here.
  grep -v 'add_ide(' "$work/packages/fpmake_add.inc" > "$work/fpmake_add.tmp" \
    && mv "$work/fpmake_add.tmp" "$work/packages/fpmake_add.inc"
  for step in "rtl all" "packages all" "rtl install" "packages install"; do
    set -- $step
    if ! make -C "$work/$1" "$2" OS_TARGET=win64 CPU_TARGET=x86_64 "FPC=$PPCX64" "FPCFPMAKE=$native" \
         "FPCDIR=$work" "INSTALL_PREFIX=$CROSS" CROSSINSTALL=1 >"$CROSS/units-$1-$2.log" 2>&1; then
      rm -rf "$CROSS/lib/fpc/$FPCVER"
      die "compiling the Free Pascal units failed, see $CROSS/units-$1-$2.log"
    fi
  done
  rm -rf "$work"
}
[ -f "$UNITS/rtl/system.ppu" ] || build_units

# lazbuild is given this script as the compiler. -n: do not read fpc.cfg (it
# describes the native compiler). The unit paths come last because the first
# -Fu on the command line wins, and the FPC packages contain units named like
# LCL units (fv/menus, fv/dialogs).
mkdir -p "$CROSS/bin"
cat > "$FPCWIN.new" <<EOF
#!/bin/sh
exec "$PPCX64" -n "\$@" "-Fu$UNITS/rtl" "-Fu$UNITS/*"
EOF
# Keep an unchanged file: Lazarus recompiles the LCL when its compiler changes.
if cmp -s "$FPCWIN.new" "$FPCWIN"; then rm -f "$FPCWIN.new"; else mv "$FPCWIN.new" "$FPCWIN"; fi
chmod +x "$FPCWIN"

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
rm -f "$DIST"/*.exe
mkdir -p "$LOGDIR"
OK=""
FAILED=""

build() { # <lpi> <cli|gui>
  lpi=$1; kind=$2
  name=$(basename "$lpi" .lpi)
  log="$LOGDIR/$name.log"
  # Some command-line projects list the LCL as a dependency; "nogui" keeps the
  # Windows widgetset out of them.
  if [ "$kind" = gui ]; then ws=win32; else ws=nogui; fi
  printf '  %-16s ' "$name"
  # -B: rebuild every unit. The command-line and GUI variants of a tool share
  # the same unit output folder but are compiled with different defines.
  if "$LAZBUILD" -B --os=win64 --cpu=x86_64 --ws=$ws "--compiler=$FPCWIN" "$ROOT/$lpi" >"$log" 2>&1 \
     && mv "$ROOT/$(dirname "$lpi")/$name.exe" "$DIST/"; then
    say "ok"
    OK="$OK $name"
  else
    say "FAILED (see $log)"
    grep -E 'Error:|Fatal:' "$log" | head -3 | sed 's/^/      /'
    FAILED="$FAILED $name"
  fi
}

say ""
say "Command-line tools:"
for p in GTMapTool/GTMapTool.lpi GTMClass/GTMClass.lpi GTMReg/GTMReg.lpi \
         GTMReSample/GTMReSample.lpi GTMNodeSelect/GTMNodeSelect.lpi SGTM/SGTM.lpi; do
  build "$p" cli
done

if [ $CLI_ONLY -eq 0 ]; then
  say ""
  say "Graphical tools:"
  for p in GTMapTool/xgtmaptool/xGTMapTool.lpi GTMClass/xGTMClass.lpi GTMReg/xGTMReg.lpi \
           GTMReSample/xGTMReSample.lpi GTMNodeSelect/xGTMNodeSelect.lpi GTMmanifold/GTMmanifold.lpi; do
    build "$p" gui
  done
fi

if [ $ZIP -eq 1 ] && [ -z "$FAILED" ]; then
  cp "$ROOT/windows/SETUP.md" "$DIST/README.md"
  cp "$ROOT/LICENSE" "$DIST/LICENSE.txt"
  rm -f "$ZIPFILE"
  (cd "$DIST" && zip -q -9 "$ZIPFILE" *.exe README.md LICENSE.txt) || die "could not create $ZIPFILE"
  rm -f "$DIST/README.md" "$DIST/LICENSE.txt"
fi

say ""
say "Not built: xGTMView, xGTMLandscape, KGTM and GTMGui (see the README)."
say ""
say "Built:${OK:- nothing}"
[ -z "$FAILED" ] || say "Failed:$FAILED"
say "Output: $DIST"
[ $ZIP -eq 0 ] || [ -n "$FAILED" ] || say "Archive: $ZIPFILE"
say ""
say "On Windows the programs look for the licence file at"
say "%LOCALAPPDATA%\\ISIDAGTM\\licence.dat. See windows/SETUP.md."
[ -z "$FAILED" ]
