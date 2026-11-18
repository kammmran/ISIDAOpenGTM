# ISIDA/GTM on macOS: setup and usage

This guide covers building ISIDA/GTM on a Mac, installing the licence file and
running each program. It applies to Apple Silicon and Intel Macs.

- [1. Install the tools](#1-install-the-tools)
- [2. Get the sources](#2-get-the-sources)
- [3. Build](#3-build)
- [4. Install the licence file](#4-install-the-licence-file)
- [5. Put the programs where you can run them](#5-put-the-programs-where-you-can-run-them)
- [6. Run the command-line tools](#6-run-the-command-line-tools)
- [7. Run the graphical tools](#7-run-the-graphical-tools)
- [8. A complete example](#8-a-complete-example)
- [9. Troubleshooting](#9-troubleshooting)

---

## 1. Install the tools

You need [Homebrew](https://brew.sh), Free Pascal, Lazarus and the LLVM linker.

```sh
brew install fpc lld
```

Install Lazarus in one of these ways:

- the official installer from <https://www.lazarus-ide.org>, or
- [fpcupdeluxe](https://github.com/LongDirtyAnimAlf/fpcupdeluxe) (builds Lazarus into a folder of your choice).

Lazarus must include the Cocoa widgetset, and its `lazbuild` program must be
reachable. The build script looks for `lazbuild` on your `PATH` and in
`~/Applications/lazarus`, `~/fpcupdeluxe/lazarus` and `/Applications/Lazarus`.
If it is somewhere else, set `LAZBUILD`:

```sh
export LAZBUILD=/path/to/lazarus/lazbuild
```

`lld` is required for the graphical programs. Apple's current linker rejects the
Objective-C code that Free Pascal 3.2 produces for macOS windows
(`ld: malformed method list atom`). `macos/linker/ld` makes the build use
LLVM's `ld64.lld` instead.

## 2. Get the sources

The project files expect three other repositories next to this one, with these
folder names:

```
<parent folder>/
├── ISIDAOpenGTM      this repository
├── ISIDAKernel       https://github.com/Laboratoire-de-Chemoinformatique/ISIDAKernel
├── ModelAnalyzerR    https://github.com/Laboratoire-de-Chemoinformatique/ISIDAModelAnalyzerR
└── ModelAnalyzerC    https://github.com/Laboratoire-de-Chemoinformatique/ISIDAModelAnalyzerC
```

You don't need to clone them yourself: `macos/build.sh --fetch-deps` does it.

```sh
git clone https://github.com/kammmran/ISIDAOpenGTM.git
cd ISIDAOpenGTM
git checkout macos-fixes        # until it is merged into main
```

## 3. Build

```sh
macos/build.sh --fetch-deps     # first time: also clones the dependencies
macos/build.sh                  # later builds
macos/build.sh --cli-only       # only the command-line tools (lld not needed)
```

The results are collected in `dist/macos/`:

```
dist/macos/
├── bin/                 command-line tools
│   ├── GTMapTool        build maps, project data
│   ├── GTMClass         classification landscapes
│   ├── GTMReg           regression landscapes
│   ├── GTMReSample      change the number of nodes of a map
│   ├── GTMNodeSelect    zoom on / sample from selected nodes
│   └── SGTM             Stargate GTM (map linking two descriptor spaces)
├── xGTMapTool.app       graphical front end of GTMapTool
├── xGTMClass.app        graphical front end of GTMClass
├── xGTMReg.app          graphical front end of GTMReg
├── xGTMReSample.app     graphical front end of GTMReSample
├── xGTMNodeSelect.app   graphical front end of GTMNodeSelect
├── GTMmanifold.app      3D view of the manifold and the data
└── logs/                one build log per program
```

xGTMView, xGTMLandscape, KGTM and GTMGui are not built. Their dependencies are
not public or not available for Lazarus on macOS (see the README).

## 4. Install the licence file

Most programs check a licence file, `licence.dat`, provided by the
Laboratoire de Chémoinformatique (University of Strasbourg).

**Put it here:**

```
~/.config/ISIDAGTM/licence.dat
```

```sh
mkdir -p ~/.config/ISIDAGTM
cp /path/to/licence.dat ~/.config/ISIDAGTM/licence.dat
```

Notes:

- The folder is `ISIDAGTM`. Older tutorials say `ISIDAGTM2018`; the current
  programs do not look there.
- If the environment variable `XDG_CONFIG_HOME` is set, the folder is
  `$XDG_CONFIG_HOME/ISIDAGTM` instead of `~/.config/ISIDAGTM`.
- The file name must be exactly `licence.dat` (British spelling).
- `GTMapTool` and `SGTM` also accept another location:
  `--licence=/path/to/licence.dat` (with `=`, not a space).
- The licence has an end date. When it is valid, the programs print or show
  `+++ Licence ending the: <date> +++` at start-up. The graphical programs show
  this in a pop-up: click **OK** to continue.

Which programs need it:

| Needs the licence | Does not need it |
|---|---|
| GTMapTool, SGTM | GTMClass, GTMReg, GTMReSample, GTMNodeSelect |
| xGTMapTool, xGTMClass, xGTMReg, xGTMReSample, GTMmanifold | xGTMNodeSelect |

Without the file you get `Impossible to locate licence file. Licence file should be: …`
with the exact path the program expects.

## 5. Put the programs where you can run them

Run the command-line tools from `dist/macos/bin`, or add that folder to your `PATH`:

```sh
echo 'export PATH="$HOME/path/to/ISIDAOpenGTM/dist/macos/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
GTMapTool -h
```

The `.app` bundles can be double-clicked in Finder or copied to `/Applications`:

```sh
cp -R dist/macos/*.app /Applications/
```

Programs you build yourself open without any Gatekeeper warning. If you copy them
to another Mac by download (browser, mail, AirDrop), macOS marks them as
quarantined and says the app "is damaged and can't be opened". On that Mac, run:

```sh
xattr -dr com.apple.quarantine /Applications/xGTMapTool.app   # repeat per app
```

## 6. Run the command-line tools

Every tool prints its options with `-h`. Input data are descriptor files in
LibSVM format (`.svm`): one compound per line, `<label> <index>:<value> …`.

### GTMapTool: build a map, project data

```sh
# Train a map with 9 RBF centres, standardised descriptors (-p 1)
GTMapTool -i train.svm -o mymap -m 9 -p 1
#   -> mymap.xml (the model), mymapR.svm (responsibilities)

# Train and project the training set, with 3D files for GTMmanifold
GTMapTool -i train.svm -o mymap -m 9 -p 1 -j --3D
#   -> mymapPrj.mat (x,y of each compound), mymapR.svm, mymapWPhi3D.mat, mymapPC123.mat, ...

# Project new data on an existing map (do NOT add -i here)
GTMapTool -x mymap.xml -o test -j -y test.svm
#   -> testPrj.mat, testR.svm; prints "Likelyhood of projected data: ..."

# Project with 3D files (data points for GTMmanifold)
GTMapTool -x mymap.xml -o train3d -j -y train.svm --3D
#   -> train3dZ3D.mat (data in 3D) and train3dWPhi3D.mat (manifold in 3D)

# Continue training an existing map on data, then project it
GTMapTool -i train.svm -x mymap.xml -o mymap2 -j
```

Main options:

| Option | Meaning | Default |
|---|---|---|
| `-i file.svm` | training data | |
| `-o name` | base name of the output files | |
| `-x model.xml` | existing model (projection or continued training) | |
| `-j` | project data | |
| `-y file.svm` | data to project (with `-j`) | the training data |
| `-m n` | number of RBF centres (traits) | |
| `-k n` | number of nodes | 25 × m |
| `-w x` | RBF width | 2 × RBF spacing |
| `-l x` | regularisation | 1 |
| `-c n` | maximum number of iterations | 100 |
| `-z x` | convergence threshold on the likelihood | 0.001 |
| `-p n` | pre-processing: 0 none, 1 standardise, 2 centre, 3 normalise to [-1,1], 4 normalise then centre | 1 |
| `--3D` | also write 3D (PCA) coordinates of the manifold and the data | |

### GTMClass: classification landscape

Needs the responsibilities (`*R.svm`) of the training and test sets on the
same map, and a property file per set. A property file has one comment line,
then one class label per compound, in the same order as the `.svm` file.

```sh
# Train a class landscape and predict the test set
GTMClass -m mymap.xml -r trainR.svm -p train.prp -R testR.svm -P test.prp -o cls
#   prints Accuracy, Balanced Accuracy, Precision/Recall/F/MCC per class
#   -> cls.xml (landscape), clsLS.mat, clsDens.mat, cls.tsv (predictions)

# Only build and save the landscape
GTMClass -m mymap.xml -r trainR.svm -p train.prp -o cls -W
# Reuse a saved landscape (the map is still required)
GTMClass -m mymap.xml -l cls.xml -R testR.svm -P test.prp -o pred
# 3-fold cross-validation on the training set
GTMClass -m mymap.xml -r trainR.svm -p train.prp -o cv -x 3
```

Example property file `train.prp`:

```
# class
1
0
0
...
```

### GTMReg: regression landscape

Same inputs as GTMClass, with numeric property values.

```sh
GTMReg -m mymap.xml -r trainR.svm -p train.prp -R testR.svm -P test.prp -o reg
#   prints RMSE, MAE, R2 ...; -> reg.xml, regLS.mat, regStdDevLS.mat, regDens.mat, reg.tsv
GTMReg -m mymap.xml -r trainR.svm -p train.prp -o cv -x 3      # cross-validation
```

### GTMReSample: change the number of nodes

Re-samples an existing map on a new grid without retraining it.

```sh
GTMReSample -i train.svm -x mymap.xml -o fine -k 400        # 400 nodes, pseudo-regular grid
GTMReSample -i train.svm -x mymap.xml -o grid -w 20 -e 20   # 20 x 20 rectangular grid
```

### GTMNodeSelect and SGTM

```sh
GTMNodeSelect -h     # zoom on selected nodes or generate data from them
SGTM -h              # Stargate GTM: one map linking two descriptor spaces
SGTM -o sg -i spaceA.svm,spaceB.svm -m 9 -p 1
```

## 7. Run the graphical tools

Double-click the app in Finder, or start it from the terminal:

```sh
open dist/macos/xGTMapTool.app
```

At start-up the licence pop-up appears (click **OK**), then the main window.

| App | What it does |
|---|---|
| **xGTMapTool** | Train a map ("Train model") or apply one ("Use model"). Choose the input `.svm`, the output name, the pre-processing and the parameters, then click **OK**. The log shows the likelihood at each iteration. Tick *Save full informations* to also write the 3D files. |
| **xGTMClass** | Classification landscapes, prediction and cross-validation (same inputs as GTMClass). |
| **xGTMReg** | Regression landscapes, prediction and cross-validation (same inputs as GTMReg). |
| **xGTMReSample** | Re-sample a map with a new number of nodes. |
| **xGTMNodeSelect** | Select nodes, zoom on them or generate new points from them. |
| **GTMmanifold** | 3D view of the manifold and the data (below). |

### GTMmanifold

It shows the data points (white), the manifold nodes (magenta) and the manifold
surface as a grey wireframe, in the space of the first three principal
components. It needs three files:

1. the data in 3D: `…Z3D.mat`, from `GTMapTool -x model.xml -j -y data.svm --3D`;
2. the manifold in 3D: `…WPhi3D.mat`, from the same command;
3. the model: `model.xml`.

Choose them with the three `...` buttons and click **OK**. You can also pass
them on the command line to open the view directly:

```sh
dist/macos/GTMmanifold.app/Contents/MacOS/GTMmanifold train3dZ3D.mat train3dWPhi3D.mat mymap.xml
```

Mouse: drag to rotate, Shift+drag to move, scroll wheel to zoom. The slider
changes the size of the points; the radio buttons switch the background colour.

## 8. A complete example

From a folder containing `train.svm` and `test.svm` (labels in the first column):

```sh
# 1. Train a map
GTMapTool -i train.svm -o map -m 9 -p 1

# 2. Project training and test sets
GTMapTool -x map.xml -o train -j -y train.svm --3D
GTMapTool -x map.xml -o test  -j -y test.svm

# 3. Class labels from the first column of the .svm files
{ echo "# class"; awk '{print $1}' train.svm; } > train.prp
{ echo "# class"; awk '{print $1}' test.svm;  } > test.prp

# 4. Classification landscape, evaluated on the test set
GTMClass -m map.xml -r trainR.svm -p train.prp -R testR.svm -P test.prp -o cls

# 5. Look at the map in 3D
open -a "$PWD/dist/macos/GTMmanifold.app" --args "$PWD/trainZ3D.mat" "$PWD/trainWPhi3D.mat" "$PWD/map.xml"
```

`trainPrj.mat` and `testPrj.mat` hold the 2D map coordinates of each compound
(first line is a header, then `x,y` per line), ready to plot with any tool.

## 9. Troubleshooting

| Message | Cause and fix |
|---|---|
| `Impossible to locate licence file. Licence file should be: …` | Copy `licence.dat` to the path shown (normally `~/.config/ISIDAGTM/licence.dat`). |
| `Invalid licence` | The licence has expired; ask the laboratory for a new one. |
| `Error reading licence file` / `Error inconsistent licence file` | The file was edited or damaged; copy the original again. |
| `"xGTM…" is damaged and can't be opened` | The app was downloaded or copied from another Mac: `xattr -dr com.apple.quarantine <app>`. |
| `ERROR: nothing to do. Give a training file (-i) or a model file (-x).` | GTMapTool was started without data. |
| `ERROR: a model file (-x) was given without data.` | Add `-j -y data.svm` to project, or `-i data.svm` to continue training. |
| Projection gives every compound at `0,0` and likelihood about -120 | Old GTMapTool builds with `-i` and `-x` together. Use the current build, and use `-x … -j -y …` (without `-i`) to project. |
| `ld: malformed method list atom` while building | `lld` is missing: `brew install lld`. |
| `lazbuild not found` | Set `LAZBUILD=/path/to/lazbuild`. |
| `missing <parent>/ISIDAKernel` | Run `macos/build.sh --fetch-deps`, or clone the dependencies as in section 2. |
| A graphical app shows only the licence pop-up | Click **OK**; the main window opens after it (can take a few seconds). |
