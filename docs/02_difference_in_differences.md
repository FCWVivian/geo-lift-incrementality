# DiD (Difference-in-Differences) — Method Note

## 1. Concept

**Question:** what would the treated group have done *without* the treatment? You can never observe that directly. It's the **counterfactual**.

**DiD's answer:** use a **control group** that didn't get the treatment. Whatever the control did over the same period (seasonality, holidays, market trends) is assumed to have happened to the treatment group as well. Subtract it out, and what's left is the treatment effect.

```
Treatment change = ad effect + shared trend + noise
Control change   =             shared trend + noise
────────────────────────────────────────────────────
Difference       = ad effect               (+ leftover noise)
```

**Name:** two differences:
1. **Before vs after**, computed separately for each group
2. **Treatment vs control**, the difference between those two changes

**Key assumption, parallel trends:** without the treatment, the treatment and control groups would have moved **in parallel**. Not necessarily the same level, but the same *direction and size of change*.

---

## 2. When to use it

**✅ Good fit when:**
- You have **before and after** data for both groups
- Something affects everyone over time (seasonality, holidays, economy), and you want to remove it
- Treatment and control have **similar trends in the pre-period** (check with a plot)
- You need something **simple and explainable** to stakeholders
- Examples: geo lift tests, a policy change in some states, a feature launched in some markets, a price change in some stores

**⚠️ Be careful when:**
- **Pre-trends differ.** For example, treatment was already growing faster before launch, so DiD credits that growth to the treatment.
- **Only 1 or a few treated units.** Geo-specific noise is large (in our data, a typical single-state error was **5.1%**).
- **Units are very small.** Small states had **11.3%** error vs **2.5%** for large ones.
- **A shock hits only one group** during the test (local news, a store opening, weather).
- **Spillover:** the treatment leaks into the control (for example, national TV ads also reach "control" states).

**When to switch to something else:**
- Treatment doesn't look like any simple control group → **Synthetic Control** (case 03)
- Need a confidence interval or p-value → add a **placebo / permutation test** (case 04)

---

## 3. Formula

**Ratio form (relative lift, the standard for lift reports):**

$$\text{DiD lift} = \frac{T_{after} / T_{before}}{C_{after} / C_{before}} - 1$$

**Subtraction form (percentage points):**

$$\text{DiD} = \left(\frac{T_{after}}{T_{before}} - 1\right) - \left(\frac{C_{after}}{C_{before}} - 1\right)$$

The two are about equal when changes are small. Use the ratio form for lift.

**Regression form (what you'll see in papers and interviews):**

$$Y_{it} = \beta_0 + \beta_1 \cdot \text{Treated}_i + \beta_2 \cdot \text{Post}_t + \beta_3 \cdot (\text{Treated}_i \times \text{Post}_t) + \varepsilon_{it}$$

- $\beta_1$: baseline difference between groups
- $\beta_2$: shared time trend
- **$\beta_3$ = the DiD effect** (the interaction term)

If you log the outcome ($\log Y$), $\beta_3$ ≈ the % lift.

**Python:**
```python
def did_lift(data, treated):
    before = data[(data.date >= START - WINDOW) & (data.date < START)]
    after  = data[(data.date >= START) & (data.date < START + WINDOW)]
    T_before = before[before.state.isin(treated)].sessions.sum()
    T_after  = after[after.state.isin(treated)].sessions.sum()
    C_before = before[~before.state.isin(treated)].sessions.sum()
    C_after  = after[~after.state.isin(treated)].sessions.sum()
    return (T_after / T_before) / (C_after / C_before) - 1
```

---

## 4. Example

### Simple version (easy to explain in an interview)

A brand runs ads in Texas starting January 4. Sessions over 28 days:

| | Before | After | Change |
|---|---|---|---|
| Texas (ads) | 1,000 | 1,020 | **+2.0%** |
| Other states (no ads) | 10,000 | 9,560 | **−4.4%** |

- **Naive lift:** +2.0%, which says "ads barely worked" ❌
- **DiD (subtraction):** 2.0 − (−4.4) = **+6.4 pts**
- **DiD (ratio):** 1.020 / 0.956 − 1 = **+6.7%** ✅

Without ads, Texas would likely have dropped about 4.4% like everyone else. Instead it grew 2%, so the ads were worth about 6.7%. Naive lift underestimated the effect by more than 3×.

### Real data (case 02 results)

GA4 Google Merchandise Store sample. Texas as treatment, all other states as control. Before 12/7–1/3, after 1/4–1/31.

| Test | Naive | DiD | Truth |
|---|---|---|---|
| No lift (true effect = 0) | −3.4% | **−0.7%** | 0% |
| Injected +10% | +6.2% | **+9.2%** | 10% |
| Placebo, every state (median error) | — | **5.1%** | 0% |
| Pooling 1 → 6 → 10 states (error std) | — | 4.4% → 1.8% → 1.6% | 0% |

**Takeaways:**
- DiD removed most of the seasonal bias (−3.4% → −0.7%)
- Texas was lucky. A typical single state has a 5% error, and Illinois showed **+5.1% "lift" with zero ads**.
- Use **multiple treatment geos** (about 6 here). Error shrinks roughly like 1/√n, then plateaus.
