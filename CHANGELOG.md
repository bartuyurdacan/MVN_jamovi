# Changelog

## 1.0.0 — 2026-08-22

- Raise the jamovi module version to the library-ready 1.0.0 release.
- Prevent sparse, empty, or singular groups from aborting grouped analyses.
- Build table structure during initialization and report skipped groups clearly.
- Compute and serialize plot state only for plots requested by the user.
- Preserve the caller's random-number state when an explicit seed is used.
- Apply the finite-sample correction to bootstrap Monte Carlo p-values.
- Add cancellation checkpoints and cap bootstrap replicates at 10,000.
- Correct result invalidation dependencies, option gating, labels, and theme-aware plots.
- Add statistical-method references to jamovi output.
- Make heavy console-only dependencies optional and clean development artifacts.
- Add regression coverage for sparse groups, RNG preservation, and bootstrap p-values.
