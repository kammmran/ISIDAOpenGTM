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



---

## Documentation

For detailed usage instructions, command-line options, and examples, please refer to the [ISIDA/GTM Manual](https://github.com/Laboratoire-de-Chemoinformatique/ISIDAOpenGTM_Legacy/blob/main/doc/doc_ISIDAOpenGTM_Legacy.pdf).

---