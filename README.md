# ISIDA/GTM – README

## Introduction

The ISIDA/GTM software package is a comprehensive toolkit designed for the generation, analysis, and visualization of **Generative Topographic Maps (GTM)**. This package implements the GTM algorithm, as originally introduced by Bishop et al., along with its incremental, multinomial noise model, and block-based training [4] variations. It is intended for researchers, data scientists, and practitioners who require advanced tools for mapping, classifying, and regressing high-dimensional data, particularly in the field of cheminformatics.

---

## Core Tools

- **GTMapTool**: The primary software for building GTM models, continuing training, and projecting new data onto existing maps.
- **GTMClass**: A tool for classification tasks, enabling the generation of property landscapes for labeled datasets and defining applicability domains (AD).
- **GTMReg**: A tool for regression tasks, enabling the generation of property landscapes for labeled datasets and defining applicability domains (AD).
- **GTMReSample**: Allows resampling of GTM models to adjust node resolution without the need for retraining.

---

## Purpose

The ISIDA/GTM package is designed to:
- **Visualize** high-dimensional data in 2D or 3D latent spaces.
- **Perform Classification** and **Regresssion** of properties of chemical compounds or other complex datasets.
- **Define applicability domains** to ensure reliable predictions.
- **Facilitate integration** with workflows such as KNIME or Pipeline Pilot for streamlined data analysis.

---

## Installation and Access

For compilation, the [ISIDA/Kernel](https://github.com/Laboratoire-de-Chemoinformatique/ISIDAKernel) project is required.

### Building on macOS

The project builds on macOS (Apple Silicon and Intel) with Free Pascal 3.2.x and Lazarus (Cocoa widgetset).

1. Install the tools:
   ```sh
   brew install fpc lld       # lld is needed to link the GUI programs, see below
   ```
   and Lazarus (official installer, or [fpcupdeluxe](https://github.com/LongDirtyAnimAlf/fpcupdeluxe)) so that `lazbuild` is available.
2. Build everything:
   ```sh
   macos/build.sh --fetch-deps
   ```
   `--fetch-deps` clones the required sources next to this repository, where the project files expect them:
   ```
   <parent>/ISIDAOpenGTM
   <parent>/ISIDAKernel
   <parent>/ModelAnalyzerR   (ISIDAModelAnalyzerR)
   <parent>/ModelAnalyzerC   (ISIDAModelAnalyzerC)
   ```
3. The results are in `dist/macos/`: the command-line tools in `dist/macos/bin/` and the graphical tools as `.app` bundles.

The programs look for the licence file at `~/.config/ISIDAGTM/licence.dat`.

Why the GUI needs `lld`: Apple's current linker rejects the Objective-C method lists that Free Pascal 3.2.x generates for the Cocoa widgetset (`ld: malformed method list atom ...`), and its `-ld_classic` fallback has been removed. `macos/linker/ld` is a small shim that links with LLVM's `ld64.lld` instead; `macos/build.sh` passes it to the compiler with `-FD`.

Built by `macos/build.sh`: GTMapTool, GTMClass, GTMReg, GTMReSample, GTMNodeSelect, SGTM (command line) and xGTMapTool, xGTMClass, xGTMReg, xGTMReSample, xGTMNodeSelect, GTMmanifold (GUI).
Not built: xGTMView and xGTMLandscape (need the non-public `Molecule` sources), KGTM (needs a newer ISIDAKernel than the public one) and GTMGui (BGRABitmap / BGLControls).

GTMmanifold no longer uses GLScene (not available for the Cocoa widgetset); its 3D view uses Lazarus' own `TOpenGLControl` (package LazOpenGLContext). It can also be started with the three files on the command line:
`GTMmanifold <data Z3D.mat> <manifold WPhi3D.mat> <model.xml>` (files from `GTMapTool ... -j --3D`).



---

## Documentation

For detailed usage instructions, command-line options, and examples, please refer to the [ISIDA/GTM Manual](https://github.com/Laboratoire-de-Chemoinformatique/ISIDAOpenGTM_Legacy/blob/main/doc/doc_ISIDAOpenGTM_Legacy.pdf).

---