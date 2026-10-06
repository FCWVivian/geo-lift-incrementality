# Synthetic Control (SCM) — Method Note

## 1. Concept

**Question:** what would the treated unit (e.g., Texas) have done *without* the treatment?

**DiD's answer:** "all other states combined", one fixed control group for everyone.
**SCM's answer:** build a **custom control** for each treated unit, a **weighted mix of control units** that reproduces the treated unit's curve **before** the treatment.

```
synthetic Texas = 0.18 × Missouri + 0.16 × New York + 0.14 × Wisconsin + 0.12 × Utah + ...
                  (weights ≥ 0, sum to 1)
```

1. **Fit:** choose weights so synthetic ≈ actual in the **pre-period**
2. **Freeze** the weights
3. **Predict:** apply the same weights in the **post-period** → counterfactual ("no-ads Texas")
4. **Lift** = actual ÷ synthetic − 1

Core idea behind **Meta GeoLift** (Augmented SCM) and related to Google's **CausalImpact**.

**Key assumption:** a mix that tracks the treated unit before treatment would keep tracking it after, if there were no treatment.

**Terms:**
- **Donor pool:** candidate control units (here 33 states)
- **Weights:** how much each donor contributes; usually **sparse** (most are 0)
- **Pre-period fit:** how well synthetic matches actual before treatment (like *training error*)

---

## 2. When to use it

**✅ Good fit when:**
- The treated unit is **unlike the average** of controls (very large, unusual seasonality, different growth)
- A simple control **fails parallel trends**
- You have a **long, stable pre-period** (many time points vs number of donors)
- You treat **few units** (one market, a handful of DMAs) and need a credible counterfactual
- Stakeholders need a **visual**: synthetic vs actual lining up before launch is persuasive

**⚠️ Be careful when:**
- **Short or noisy pre-period** with many donors → overfits noise (33 weights on 64 noisy days here)
- Trends are **already parallel**: little bias to fix, so SCM ≈ DiD
- The pre-period isn't representative of the post-period (holiday season → January)
- The treated unit is **outside the range** of donors (e.g., bigger spikes than any donor): a weighted average can't reproduce it → use Augmented SCM or allow an intercept
- **Spillover** into donors (national media also reaches "control" states)

**Don't judge SCM by pre-period fit alone.** Judge it by **placebo error** across many units.

---

## 3. Formula

**Weights (constrained least squares):**

$$\hat{w} = \arg\min_{w} \frac{1}{T_{pre}} \sum_{t \in pre} \left( Y_{1t} - \sum_{j} w_j Y_{jt} \right)^2 \quad \text{s.t.} \quad w_j \ge 0,\ \sum_j w_j = 1$$

- $Y_{1t}$: treated unit (indexed) on day *t*; $Y_{jt}$: donor *j* (indexed)
- Index each series to its pre-period mean first so big and small units are comparable

**Counterfactual and lift:**

$$\hat{Y}^{(0)}_{1t} = \sum_j \hat{w}_j Y_{jt} \qquad \text{SCM lift} = \frac{\sum_{t \in post} Y_{1t}}{\sum_{t \in post} \hat{Y}^{(0)}_{1t}} - 1$$

**Lift vs incremental share (don't mix them up):**

| Metric | Formula | Question |
|---|---|---|
| **Lift** | (actual − cf) / **cf** | How much did ads *increase* the outcome? |
| Incremental share | (actual − cf) / **actual** | What fraction of the outcome did ads *cause*? |

**Why the constraints:** weights in [0, 1] summing to 1 keep synthetic a true **mix** (a recipe with percentages): interpretable, no extrapolation. With indexed data, they also pin synthetic's pre-period mean to 1.0 = the treated unit's mean.

**Python:**
```python
from scipy.optimize import minimize

def scm_lift(data, treated):
    """data: wide table (date × unit). treated: ONE unit name."""
    idx = data / data[pre].mean()
    donors = [s for s in data.columns if s != treated]
    X, y = idx.loc[pre, donors].values, idx.loc[pre, treated].values
    k = len(donors)
    res = minimize(lambda w: np.mean((X @ w - y) ** 2), np.full(k, 1 / k), method="SLSQP",
                   bounds=[(0, 1)] * k, constraints={"type": "eq", "fun": lambda w: w.sum() - 1})
    synthetic = (idx[donors] @ res.x) * data.loc[pre, treated].mean()   # back to real units
    return data.loc[post, treated].sum() / synthetic[post].sum() - 1
```

**`minimize` / SLSQP in one line:** SciPy's optimizer searches for the inputs (`w`) that make the loss smallest. `SLSQP` is used because it supports both bounds (0 ≤ w ≤ 1) and equality constraints (Σw = 1).

---

## 4. Example (case 03 results)

GA4 Google Merchandise Store sample, 34 states with ≥ 10 median sessions/day. Pre 11/1–1/3 (64 days, used to fit), post 1/4–1/31.

### Building synthetic Texas (pre-period MAE, indexed scale)

| Approach | States | MAE |
|---|---|---|
| Neighbor intuition | Arizona alone | 0.206 |
| Neighbors | Arizona, Oklahoma, Louisiana | 0.164 |
| Hand-picked big states | Illinois, New York, California | 0.102 |
| Top 3 by correlation = top 3 by MAE | California, New York, Virginia | 0.099 |
| **Optimizer (SCM)** | Missouri .175, New York .157, Wisconsin .143, Utah .122, South Carolina .102, … | **0.067** |

- **Size beat geography:** individual fit is driven by state size (corr −0.88), not location, because this is an online store following national shopping patterns. Small states are noisy.
- **California got weight 0**, despite being the best single match: its December peak overshoots Texas (2.00 vs 1.74) and its weekly swing is too flat; forcing 30% California made the fit worse. Weights reflect **usefulness in a combination** (errors cancelling), not individual similarity.
- Adding a correlation term to the loss changed almost nothing: indexing + sum-to-1 weights already pin the level, so MSE ≈ "moving together".

### Lift estimates

| Test | Truth | DiD | SCM |
|---|---|---|---|
| Texas, no lift | 0% | −0.7% | **+0.7%** |
| Texas, +10% injected | 10% | 9.2% | **10.8%** |
| **Placebo, 34 states: median \|error\|** | 0% | **2.9%** | **3.3%** |
| SCM beats DiD in | | | 17 of 34 states |

**Takeaways:**
- **Better pre-period fit ≠ better estimate.** SCM fit much better (0.067 vs ~0.10) but had no lower placebo error, like low training error with no better test error.
- Reasons: overfitting (33 weights, 64 noisy days), remaining error is post-period state noise that no control can predict, and trends were already mostly parallel, so there was little bias to remove.
- Estimate ≈ truth + that unit's placebo error (holds for both methods).
- **Beware cherry-picking:** on DiD's worst states (Illinois, Washington, Pennsylvania), SCM looked clearly better, but across all states it was a coin flip.
