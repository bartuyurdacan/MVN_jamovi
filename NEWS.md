# MVN 6.3.0 (jamovi module)

## New Features

* Full jamovi module integration with interactive GUI
* Multivariate Q-Q plot rendering in jamovi
* Univariate Q-Q plots, box plots, and histograms with normal curve overlay
* Grouped analysis support with optional grouping variable
* Missing data handling: listwise deletion, mean/median imputation, MICE
* Power transformations: Box-Cox, Box-Cox with negatives, Yeo-Johnson
* Bootstrap resampling for p-value estimation (Mardia, Henze-Zirkler, Royston)
* Six multivariate normality tests: Mardia, Henze-Zirkler, Henze-Wagner, Royston, Doornik-Hansen, Energy
* Five univariate normality tests: Anderson-Darling, Shapiro-Wilk, Shapiro-Francia, Cramer-von Mises, Lilliefors

## Bug Fixes

* Fixed `curve()` scoping bug in histogram normal overlay — mean and sd were computed on the plotting sequence instead of the data
* Fixed plot rendering in jamovi: render functions now use `image$setState()` / `image$state` pattern since `self$data` is unavailable during render callbacks
* Added missing `stats::ppoints` import to NAMESPACE
* Removed `Collate` field from DESCRIPTION to resolve jmvtools build conflicts

## Infrastructure

* Added comprehensive `.gitignore`
* Added `NEWS.md` changelog
* Updated `CITATION` with jamovi module reference
