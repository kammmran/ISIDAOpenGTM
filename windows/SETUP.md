# ISIDA/GTM on Windows: setup and usage

This guide covers getting the Windows programs (64-bit `.exe`), installing the
licence file and running them. The programs and their options are the same as
on macOS and Linux; the complete description of every tool is in
[macos/SETUP.md](../macos/SETUP.md), sections 6 to 8.

- [1. Get the programs](#1-get-the-programs)
- [2. Install the licence file](#2-install-the-licence-file)
- [3. Run the command-line tools](#3-run-the-command-line-tools)
- [4. Run the graphical tools](#4-run-the-graphical-tools)
- [5. Build the programs yourself](#5-build-the-programs-yourself)
- [6. Troubleshooting](#6-troubleshooting)

---

## 1. Get the programs

Download `ISIDAGTM-windows-x64.zip` from the
[releases page](https://github.com/kammmran/ISIDAOpenGTM/releases) and extract
it to a folder of your choice, for example `C:\ISIDAGTM`. Nothing needs to be
installed. The folder contains:

| Program | What it does |
|---|---|
| `GTMapTool.exe` | build maps, project data (command line) |
| `GTMClass.exe` | classification landscapes (command line) |
| `GTMReg.exe` | regression landscapes (command line) |
| `GTMReSample.exe` | change the number of nodes of a map (command line) |
| `GTMNodeSelect.exe` | zoom on / sample from selected nodes (command line) |
| `SGTM.exe` | Stargate GTM, a map linking two descriptor spaces (command line) |
| `xGTMapTool.exe`, `xGTMClass.exe`, `xGTMReg.exe`, `xGTMReSample.exe`, `xGTMNodeSelect.exe` | graphical front ends of the tools above |
| `GTMmanifold.exe` | 3D view of the manifold and the data |

The programs are not signed. The first time you start one, Windows may show
"Windows protected your PC": click **More info**, then **Run anyway**.

## 2. Install the licence file

Most programs check a licence file, `licence.dat`, provided by the
Laboratoire de Chémoinformatique (University of Strasbourg).

**Put it here:**

```
%LOCALAPPDATA%\ISIDAGTM\licence.dat
```

which is `C:\Users\<your name>\AppData\Local\ISIDAGTM\licence.dat`. In a
Command Prompt:

```bat
mkdir "%LOCALAPPDATA%\ISIDAGTM"
copy C:\path\to\licence.dat "%LOCALAPPDATA%\ISIDAGTM\licence.dat"
```

Notes:

- The file name must be exactly `licence.dat` (British spelling).
- `GTMapTool` and `SGTM` also accept another location:
  `--licence=C:\path\to\licence.dat` (with `=`, not a space).
- When the licence is valid, the programs print or show
  `+++ Licence ending the: <date> +++` at start-up. The graphical programs show
  this in a pop-up: click **OK** to continue.
- Needs the licence: GTMapTool, SGTM, xGTMapTool, xGTMClass, xGTMReg,
  xGTMReSample, GTMmanifold. Does not need it: GTMClass, GTMReg, GTMReSample,
  GTMNodeSelect, xGTMNodeSelect.

Without the file you get `Impossible to locate licence file. Licence file should be: …`
with the exact path the program expects.

## 3. Run the command-line tools

Open a Command Prompt or PowerShell in the folder with your data and call the
programs with their full path, or add the program folder to your `PATH` once:

```bat
set PATH=C:\ISIDAGTM;%PATH%
GTMapTool -h
```

Every tool prints its options with `-h`. Input data are descriptor files in
LibSVM format (`.svm`): one compound per line, `<label> <index>:<value> …`.
A complete example, from a folder containing `train.svm` and `test.svm`:

```bat
:: 1. Train a map with 9 RBF centres, standardised descriptors
GTMapTool -i train.svm -o map -m 9 -p 1

:: 2. Project the training and test sets (--3D also writes the files for GTMmanifold)
GTMapTool -x map.xml -o train -j -y train.svm --3D
GTMapTool -x map.xml -o test -j -y test.svm

:: 3. Classification landscape, evaluated on the test set
::    (train.prp and test.prp: one comment line, then one class label per compound)
GTMClass -m map.xml -r trainR.svm -p train.prp -R testR.svm -P test.prp -o cls

:: 4. Look at the map in 3D
GTMmanifold trainZ3D.mat trainWPhi3D.mat map.xml
```

When the class labels are the first column of the `.svm` files, PowerShell can
write the property files:

```powershell
"# class" | Set-Content train.prp
Get-Content train.svm | ForEach-Object { ($_ -split ' ')[0] } | Add-Content train.prp
```

Numbers always use a point as decimal separator, in the input and in the
output files, whatever the regional settings of Windows.

## 4. Run the graphical tools

Double-click the `.exe`. The licence pop-up appears first (click **OK**), then
the main window. What each window does is described in section 7 of
[macos/SETUP.md](../macos/SETUP.md); the windows are the same on Windows.

In GTMmanifold: drag to rotate, Shift+drag to move, mouse wheel to zoom.

## 5. Build the programs yourself

### On macOS or Linux (cross-compilation)

```sh
windows/build.sh --fetch-deps     # first time: also clones the dependencies
windows/build.sh                  # later builds
windows/build.sh --zip            # also creates dist/ISIDAGTM-windows-x64.zip
```

It needs Lazarus (`lazbuild`), the Free Pascal compiler for x86_64 (`ppcx64`;
on Apple Silicon it runs under Rosetta) and the Free Pascal sources of the same
version. No Windows tools are required: Free Pascal links Windows programs
itself. The first run compiles the Free Pascal units for Windows into
`~/.cache/isidagtm/fpc-cross` (about a minute), and Lazarus compiles its LCL
for Windows into its own folder; later runs reuse both.

If something is not found automatically, set it explicitly:

```sh
LAZBUILD=/path/to/lazbuild PPCX64=/path/to/ppcx64 FPCSRC=/path/to/fpc/sources windows/build.sh
```

The results are in `dist/windows/`, with one build log per program in
`dist/windows/logs/`.

### On Windows

Install [Lazarus](https://www.lazarus-ide.org) (it includes Free Pascal) and
put the four source folders side by side, as described in section 2 of
[macos/SETUP.md](../macos/SETUP.md). Then open a project file (`.lpi`) in
Lazarus and choose *Run > Build*, or build it from a Command Prompt:

```bat
C:\lazarus\lazbuild.exe GTMapTool\GTMapTool.lpi
C:\lazarus\lazbuild.exe GTMapTool\xgtmaptool\xGTMapTool.lpi
```

GTMmanifold needs the package LazOpenGLContext, which ships with Lazarus.

## 6. Troubleshooting

| Message | Cause and fix |
|---|---|
| `Windows protected your PC` | The programs are not signed: **More info**, then **Run anyway**. |
| `Impossible to locate licence file. Licence file should be: …` | Copy `licence.dat` to the path shown (normally `%LOCALAPPDATA%\ISIDAGTM\licence.dat`). |
| `Invalid licence` | The licence has expired; ask the laboratory for a new one. |
| `Error reading licence file` / `Error inconsistent licence file` | The file was edited or damaged; copy the original again. |
| `ERROR: nothing to do. Give a training file (-i) or a model file (-x).` | GTMapTool was started without data. |
| `ERROR: a model file (-x) was given without data.` | Add `-j -y data.svm` to project, or `-i data.svm` to continue training. |
| A graphical program shows only the licence pop-up | Click **OK**; the main window opens after it. |
| `ppcx64 ... not found` or `Free Pascal ... sources not found` while building | Set `PPCX64` or `FPCSRC` as in section 5. |
