# Market Selection — Method Note

## 1. Concept

**Question:** which geos should receive the treatment (ads), and which should stay as controls?

Picking matters: in case 02, a single-state DiD error was 0.7% for Texas but 5.1% for Illinois. Market selection reduces bad luck and keeps the test affordable.

Three steps, the same idea behind Meta GeoLift's `GeoLiftMarketSelection`:

| Step | Question | Tool |
|---|---|---|
| 1. **Exclusion rules** | Which geos should *never* be treated? | Size / share thresholds |
| 2. **Stratified randomization** | How do we keep groups balanced and the budget predictable? | Sort by size → strata → one per stratum |
| 3. **Search + validation** | Can we find a set that tracks its control especially well? | Backtest many sets, then **check out-of-sample** |

**Terms:**
- **Candidate:** a geo allowed to be treated
- **Stratum / strata**: groups of similar-size geos
- **Budget share:** treated geos' share of national traffic, a proxy for spend
- **Backtest**: run a zero-lift test on many historical windows to measure how much error a set produces
- **RMSE** (root mean squared error): the "typical size" of those errors
- **Out-of-sample**: data that was **not** used to make the choice, the only honest check
- **Overfitting / winner's curse:** picking the best of many noisy tries selects **lucky** options, not truly better ones

**Analogy:** backtest RMSE is a **practice exam**; the real test period is the **real exam**. Choosing the student with the best practice score only works if practice scores actually predict real scores.

---

## 2. When to use it

**✅ Always:**
- **Exclude** geos that are too small (noise) or too large (cost, weak control, no counterfactual). Large geos can still be controls.
- **Stratify** treatment selection by size (or region / other key traits)
- **Report the budget share** of the treatment group before launch
- Pair selection with a **power analysis** (case 05)

**⚠️ Search for the "best" set only when:**
- History is **long** (e.g., a full year) and **representative** of the test period (same season)
- You **validate out-of-sample** on a held-out period before trusting the ranking
- You compare candidates on power / MDE **and** budget, not just fit

**❌ Don't:**
- Trust a ranking built on a short or unusual period (e.g., 64 holiday days, then test in January)
- Pick the single best of thousands of tries without validation
- Ignore cost: similar-error sets can differ 2.5× in budget

---

## 3. Formula

**Exclusion rules:**
- Too small: median daily KPI < threshold (here 10 sessions/day)
- Too big: share of national KPI > threshold (here 15%)

**Stratified draw:**
```python
strata = np.array_split(size[CANDIDATES].sort_values().index.values, 6)
treated = [rng.choice(s) for s in strata]      # one geo per stratum
```

**Budget share:**

$$\text{budget share} = \frac{\sum_{g \in \text{treated}} \text{KPI}_g}{\sum_{g} \text{KPI}_g}$$

**Backtest RMSE** for a treated set *S*, over *W* historical before/after windows (true effect = 0):

$$\text{RMSE}(S) = \sqrt{\frac{1}{W}\sum_{w=1}^{W} \hat{\tau}_w(S)^2}$$

**Translation:** "Across many past windows where nothing happened, how far off is this set's DiD on average?"

**Out-of-sample check:** compute the same zero-lift error on a period **not used for selection**, then check whether the historical ranking still holds (e.g., correlation between backtest RMSE and held-out error).

```python
S["jan_error"] = [jan_error(data, t) for t in S.treated]
S.backtest_rmse.corr(S.jan_error)        # ≈ 0 → ranking doesn't generalize
```

---

## 4. Example (case 06 results)

GA4 Google Merchandise Store sample. Selection used history only (11/01/2020 – 01/03/2021); January (01/04 – 01/31) used only for the out-of-sample check.

### A. Exclusions
| Rule | Excluded | Why |
|---|---|---|
| Too small (median < 10/day) | 17 states | case 02: small-state error 11.3% vs 2.5% for large |
| Too big (> 15% of traffic) | California (21%) | Expensive, removes biggest control, unlike any other state (case 03: weight 0) |

→ 33 treatment candidates (California kept as a control).

### B. Random vs stratified (1,000 draws each, 6 states)
| Method | Budget share p10 – p90 | Median backtest RMSE |
|---|---|---|
| Random | 8.2% – 19.3% | 2.3% |
| **Stratified** | **12.2% – 16.0%** | 2.3% |

→ Same noise, **much more predictable budget**, always balanced.

### C. Search 2,000 sets for the lowest backtest RMSE
- Top 10: RMSE **0.5% – 0.7%** vs median **2.3%** → ~4× better *in history*
- Frequent states: Massachusetts, Virginia, Tennessee (5/10), Texas, New York, Pennsylvania (4/10)
- Budget share of top 10: **10% – 25%** for similar error

### D. Out-of-sample check (January)
| Group by backtest RMSE | Backtest RMSE | January error |
|---|---|---|
| Best 20% | 1.3% | 1.3% |
| 2nd | 1.8% | 1.3% |
| 3rd | 2.3% | 1.6% |
| 4th | 2.8% | 1.2% |
| Worst 20% | 3.6% | 1.3% |

**Correlation = −0.01.** The "best" sets were no better in January.
- **Why:** best-of-2,000 selects lucky sets (overfitting / winner's curse); history was holiday season, January is a different regime
- Same lesson as case 03: **training error ≠ test error**

### E. Recommended procedure
1. Exclude too-small and too-large geos (keep large ones as controls)
2. Stratified randomization by size
3. Power analysis: launch only if MDE < expected effect
4. Search only with long, representative history, and always validate out-of-sample
5. Report budget share; avoid seasonal transitions (Q4)
