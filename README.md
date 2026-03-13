<img src="man/figures/mvn_sticker.png" align="right" width="120"/>

# MVN for jamovi

### Multivariate Normality Tests — A jamovi Module

[![jamovi](https://img.shields.io/badge/jamovi-module-blue?logo=jamovi&logoColor=white)](https://www.jamovi.org)
[![R](https://img.shields.io/badge/R-%3E%3D%204.0-276DC3?logo=r&logoColor=white)](https://cran.r-project.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-6.3.0-green.svg)](https://github.com/bartuyurdacan/MVN_jamovi/releases)
[![ORCID](https://img.shields.io/badge/ORCID-0000--0001--8168--7497-A6CE39?logo=orcid&logoColor=white)](https://orcid.org/0000-0001-8168-7497)

---

## Overview

**MVN** is a comprehensive [jamovi](https://www.jamovi.org) module for assessing **multivariate normality** — a critical assumption in many multivariate statistical methods including MANOVA, linear discriminant analysis, principal component analysis, and canonical correlation analysis.

This module brings the full capabilities of the [MVN R package](https://cran.r-project.org/package=MVN) (Korkmaz et al., 2014) into jamovi's point-and-click interface, making multivariate normality assessment accessible without writing code.

---

## Features

### Statistical Tests

| Test | Type | Reference |
|------|------|-----------|
| **Mardia** (skewness & kurtosis) | Multivariate | Mardia (1970) |
| **Henze-Zirkler** | Multivariate | Henze & Zirkler (1990) |
| **Henze-Wagner** | Multivariate | Henze & Wagner (1997) |
| **Royston** | Multivariate | Royston (1982) |
| **Doornik-Hansen** | Multivariate | Doornik & Hansen (2008) |
| **Energy** | Multivariate | Szekely & Rizzo (2005) |
| **Anderson-Darling** | Univariate | Anderson & Darling (1952) |
| **Shapiro-Wilk** | Univariate | Shapiro & Wilk (1965) |
| **Shapiro-Francia** | Univariate | Shapiro & Francia (1972) |
| **Cramer-von Mises** | Univariate | Cramer (1928) |
| **Lilliefors** | Univariate | Lilliefors (1967) |

### Diagnostic Plots

- **Multivariate Q-Q Plot** — Chi-square quantiles vs. Mahalanobis distances
- **Univariate Q-Q Plots** — Per-variable normal probability plots
- **Box Plots** — Distribution summaries with outlier detection
- **Histograms** — Frequency distributions with normal curve overlay

### Additional Capabilities

- **Descriptive statistics** — Mean, SD, median, range, quartiles, skewness, kurtosis
- **Multivariate outlier detection** — Robust Mahalanobis distance (quantile & adjusted methods)
- **Data transformations** — Log, square root, square
- **Power transformations** — Box-Cox, Box-Cox (with negatives), Yeo-Johnson
- **Missing data handling** — Listwise deletion, mean/median imputation, MICE
- **Bootstrap resampling** — For improved p-value estimation in small samples
- **Grouped analysis** — Stratified testing by a categorical variable

---

## Installation

### Option 1: From `.jmo` file (recommended)

1. Download the latest `.jmo` file from [Releases](https://github.com/bartuyurdacan/MVN_jamovi/releases)
2. Open jamovi
3. Click the **Modules** button (+ icon, top-right)
4. Select **Sideload** and choose the downloaded `.jmo` file

### Option 2: Build from source

```r
# Requires: R >= 4.0, jmvtools
install.packages("jmvtools")
library(jmvtools)

# Clone and install
# git clone https://github.com/bartuyurdacan/MVN_jamovi.git
jmvtools::install(home = "/path/to/jamovi")
```

### R Package (standalone)

```r
# From GitHub
devtools::install_github("bartuyurdacan/MVN_jamovi")

# Usage
library(MVN)
result <- mvn(data = iris[, 1:4], mvn_test = "hz")
summary(result)
```

---

## Usage in jamovi

1. Open your dataset in jamovi
2. Navigate to **MVN > Multivariate Normality Test**
3. Drag at least **2 numeric variables** into the Variables box
4. Select your preferred multivariate test (default: Henze-Zirkler)
5. Enable desired outputs:

| Option | Description |
|--------|-------------|
| Descriptive Statistics | Mean, SD, skewness, kurtosis, etc. |
| Multivariate Q-Q Plot | Chi-square Q-Q plot for MVN assessment |
| Univariate Q-Q Plots | Normal Q-Q plot per variable |
| Box Plots | Side-by-side box plots |
| Histograms | With normal density overlay |
| Outlier Detection | Robust Mahalanobis distance method |

### Example Output

Using Fisher's Iris dataset (4 numeric variables, n = 150):

```
Multivariate Normality Test
─────────────────────────────────────────────
  Test             Statistic    p         Result
─────────────────────────────────────────────
  Henze-Zirkler    2.333        < .001    Not normal
─────────────────────────────────────────────

Univariate Normality Tests
──────────────────────────────────────────────────────
  Test               Variable         Statistic    p
──────────────────────────────────────────────────────
  Anderson-Darling   SepalLengthCm    0.889        .023
  Anderson-Darling   SepalWidthCm     0.966        .015
  Anderson-Darling   PetalLengthCm    7.673        < .001
  Anderson-Darling   PetalWidthCm     5.063        < .001
──────────────────────────────────────────────────────
```

---

## Workflow Diagram

```
┌─────────────────┐
│   Raw Data      │
└────────┬────────┘
         │
    ┌────▼────┐
    │ Options │  Missing data handling, transformations,
    │         │  scaling, power transforms
    └────┬────┘
         │
    ┌────▼──────────────────────────────────┐
    │       Multivariate Normality Test     │
    │  (Mardia / HZ / HW / Royston / DH /  │
    │   Energy) + Bootstrap (optional)      │
    └────┬──────────────────────────────────┘
         │
    ┌────▼──────────────────────────────────┐
    │       Univariate Normality Tests      │
    │  (AD / SW / SF / CVM / Lilliefors)    │
    └────┬──────────────────────────────────┘
         │
    ┌────▼──────────────────────────────────┐
    │           Diagnostics                 │
    │  Q-Q Plots · Box Plots · Histograms  │
    │  Descriptive Statistics · Outliers    │
    └───────────────────────────────────────┘
```

---

## Authors

| Name | Role | Affiliation | ORCID |
|------|------|-------------|-------|
| **Fikret Bartu Yurdacan** | Author, Maintainer | Trakya University | [![ORCID](https://img.shields.io/badge/-0000--0001--8168--7497-A6CE39?logo=orcid&logoColor=white)](https://orcid.org/0000-0001-8168-7497) |
| Selcuk Korkmaz | Author | Trakya University | [![ORCID](https://img.shields.io/badge/-0000--0003--4632--6850-A6CE39?logo=orcid&logoColor=white)](https://orcid.org/0000-0003-4632-6850) |
| Dincer Goksuluk | Author | Erciyes University | |
| Gokmen Zararsiz | Author | Erciyes University | |

---

## Citation

If you use this module in your research, please cite:

> Korkmaz S, Goksuluk D, Zararsiz G (2014). "MVN: An R Package for Assessing Multivariate Normality." *The R Journal*, **6**(2), 151–162. [https://doi.org/10.32614/RJ-2014-031](https://journal.r-project.org/articles/RJ-2014-031/RJ-2014-031.pdf)

For the jamovi module specifically:

> Yurdacan FB, Korkmaz S, Goksuluk D, Zararsiz G (2026). "MVN for jamovi: A Graphical Module for Multivariate Normality Assessment." [https://github.com/bartuyurdacan/MVN_jamovi](https://github.com/bartuyurdacan/MVN_jamovi)

```r
citation("MVN")
```

---

## Related Resources

- **Original R package:** [CRAN — MVN](https://cran.r-project.org/package=MVN)
- **Shiny web app:** [biosoft.shinyapps.io/mvn-shiny-app](https://biosoft.shinyapps.io/mvn-shiny-app/)
- **Tutorial site:** [selcukorkmaz.github.io/mvn-tutorial](https://selcukorkmaz.github.io/mvn-tutorial/)
- **jamovi:** [jamovi.org](https://www.jamovi.org)

---

## License

This project is licensed under the [MIT License](LICENSE.md).

Copyright (c) 2025–2026 MVN authors.
