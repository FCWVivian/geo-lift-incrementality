# Meta GeoLift — Method Note

## 1. Concept

**GeoLift** is Meta's open-source R package for geo experiments. It bundles what cases 01–07 built by hand:

| GeoLift function | What it does | Case |
|---|---|---|
| `GeoDataRead()` | Formats panel data; converts dates → time index (1, 2, 3…) | Setup |
| `GeoPlot()` | Plots every location over time with the test start marked | case 01 |
| `GeoLiftMarketSelection()` | Searches treatment sets; ranks by power / MDE / fit / budget | cases 05 + 06 + case 07 |
| `GeoLift()` | Estimates lift with **Augmented Synthetic Control** + conformal inference | cases 03 + 04 |

**Key terms:**
- **Augmented SCM (ASCM):** plain synthetic control (case 03) **plus** an outcome model that corrects SCM's remaining bias
- **`model = "best"`:** tries `none` (plain SCM), `ridge` (ridge-augmented), `GSYN` (generalized SCM) and picks the best **pre-period fit**
- **Ridge regression:** regression with an case 02 penalty that shrinks coefficients to limit overfitting
- **Negative weights:** ridge augmentation lets donor weights go below 0 (still summing to ≈ 1) → the synthetic unit can **extrapolate** beyond the range of the donors
- **Conformal inference:** GeoLift's method for p-values and CIs; similar spirit to placebo tests (case 04), typically more conservative on short data
- **Scaled case 02 imbalance:** pre-period mismatch between treated and synthetic (lower = better fit)
- **`abs_lift_in_zero`:** lift estimated when the true effect is 0 (a built-in placebo, case 04)

**Running it in Google Colab (R runtime):**
1. *Runtime → Change runtime type → R*
2. Upload CSVs to `/content` (same level as `sample_data/`, **not inside it**)
3. Install (10–20 min): `remotes::install_github("ebenmichael/augsynth")`, then `remotes::install_github("facebookincubator/GeoLift")`
4. Colab resets when idle → re-upload files and re-install

---

## 2. When to use it

**✅ Good fit when:**
- You need a **standard, reproducible** geo-test workflow that teams recognize
- You want market selection + power + budget in one pass
- The treated unit is **outside the range** of donors (ridge augmentation can extrapolate)
- You need inference without writing your own placebo loop

**⚠️ Be careful when:**
- **Short pre-period:** GeoLift itself warns. Rule of thumb: ≥ 4× the test length (28-day test → 112 days). We had 64
- **Trusting `GeoLiftMarketSelection` rankings:** built on the same short history; validate out-of-sample (case 06)
- **Multiple treated locations in `GeoLift()`:** known bug ([Issue #230](https://github.com/facebookincubator/GeoLift/issues/230)), "Tibble columns must have compatible sizes" → **aggregate treated geos into one unit** before `GeoDataRead()`
- **Negative / dominant weights:** less interpretable; one donor carrying the whole counterfactual (e.g., California 1.08) is fragile
- **Point estimates without p-value / CI:** a zero-effect placebo still showed +4.5%

**Rule:** use GeoLift as a fast, standard tool, but **validate** with placebos and held-out checks.

---

## 3. Formula & code

**Data format:** one row per (date, location) with columns `date` (yyyy-mm-dd), `location` (lowercase), `Y` (KPI).

**Workaround for multiple treated geos** (aggregate into one unit):
```r
TREATED <- c("texas", "florida", "georgia", "arizona", "ohio", "michigan")
exp_agg_raw <- exp_raw %>%
  mutate(location = ifelse(location %in% TREATED, "treatedgroup", location)) %>%
  group_by(date, location) %>%
  summarise(Y = sum(Y), .groups = "drop")
exp_agg <- GeoDataRead(data = exp_agg_raw, date_id = "date", location_id = "location",
                       Y_id = "Y", format = "yyyy-mm-dd", summary = TRUE)
```

**Market selection** (pre-period only):
```r
selection <- GeoLiftMarketSelection(
  data = pre, treatment_periods = c(28), N = c(6),
  Y_id = "Y", location_id = "location", time_id = "time",
  effect_size = seq(0, 0.15, 0.025), lookback_window = 1,
  exclude_markets = c("california"), cpic = 1.12, alpha = 0.05,
  side_of_test = "two_sided", fixed_effects = TRUE, Correlations = TRUE)
head(selection$BestMarkets, 10)
```

**Lift estimation:**
```r
result <- GeoLift(Y_id = "Y", time_id = "time", location_id = "location",
                  data = exp_agg, locations = c("treatedgroup"),
                  treatment_start_time = 65, treatment_end_time = 92,
                  alpha = 0.05, model = "best", fixed_effects = TRUE,
                  ConfidenceIntervals = TRUE)
summary(result)
```

**Converting GeoLift's CI (in sessions) to %:**

$$\text{lift} = \frac{\text{incremental}}{\text{actual} - \text{incremental}}$$

**Time ↔ date lookup:**
```r
date_lookup <- data.frame(date = sort(unique(as.Date(exp_raw$date))))
date_lookup$time <- seq_len(nrow(date_lookup))
```

**Reading `BestMarkets`:**

| Column | Meaning | Case |
|---|---|---|
| `EffectSize` | MDE for that set | case 05 |
| `Power` | Power at that effect | case 05 |
| `Average_MDE` | MDE averaged over simulations | case 05 |
| `Investment` | Budget needed (via `cpic`) | case 07 |
| `ProportionTotal_Y` | Treated share of KPI ≈ budget share | case 06 |
| `Holdout` | Control share (1 − above) | case 06 |
| `abs_lift_in_zero` | Placebo bias | case 04 |
| `AvgScaledL2Imbalance` | Pre-period fit | case 03 |

---

## 4. Example (case 08 results)

GA4 Google Merchandise Store sample, 34 states, 11/01/2020 – 01/31/2021 (time 1–92). Treated: Texas, Florida, Georgia, Arizona, Ohio, Michigan; **true 8% lift** injected from 01/04 (time 65).

### A. Data & plot
Holiday peak around time 38–46 (early–mid December), drop at Christmas–New Year (time 55–64), rebound in January. California is 2–3× Texas and far more volatile.

### B. Market selection (6 states, 28 days, California excluded)
- ⚠️ "Small pre-treatment period" warning (64 days vs recommended 112)
- **#1:** Florida, Georgia, New York, Oregon, Tennessee, Texas → **MDE 2.5%** (avg 3.4%), investment ≈ $342, budget share 25.7%, placebo bias 0.9%
- New York and Texas in **all 10** top sets; Virginia 8; Florida, Illinois 6 → mostly large states, budget share **26–34%** (vs 12–16% for stratified draws)
- **Out-of-sample (January, zero-lift DiD):** #1 = 0.1% error (excellent), but #2–#5 = 1.9–2.9%, **worse than random median 1.3%** → ranking doesn't reliably generalize (same as case 06)

### C. Lift estimate (true 8%)
| | DiD (case 04) | GeoLift (Ridge ASCM) | Truth |
|---|---|---|---|
| Lift | 6.9% | **7.4%** | 8% |
| 95% CI | [2.8%, 10.5%] | **[2.3%, 11.6%]** (245–1,154 sessions) | |
| p-value | < 0.001 | **0.03** | |
| Incremental sessions | 716 | **760** | ≈ 820 |

- Multi-location `GeoLift()` failed (bug: 552 = 6 × 92 rows vs 92) → aggregated the 6 states into one unit
- `model = "best"` chose **ridge**; weights summed to ≈ 1 (+1.98 positive, −0.98 negative) → extrapolation; California got **0.72** (vs 0 for Texas alone in case 03)
- Pre-period fit improved 72% over the naive model
- 0.5-pt gap vs DiD is small next to ~9-pt CI widths; both CIs contain 8%

### D. Placebo (Virginia, New York, Illinois, Pennsylvania, Washington, North Carolina; true 0%)
| | Lift | p-value |
|---|---|---|
| GeoLift | +4.5% | **0.61** ✅ not significant |
| DiD | +3.2% | |

- p-value did its job (0.03 for the real test, 0.61 for the placebo)
- The +4.5% point estimate alone would mislead
- Counterfactual ≈ **1.08 × California**; all other weights ≈ ±0.01 → fragile single-donor dependence
- Across C and D, GeoLift and DiD each won once → sophistication ≠ accuracy (same as case 03)

### E. Takeaways
- **Tool strengths:** one call covers cases 05–07; ASCM + conformal inference built in; warns about short history
- **Checks still needed:** validate rankings out-of-sample, inspect weights for extrapolation or single-donor dependence, never report a point estimate without its interval
