# Power Analysis & MDE — Method Note

## 1. Concept

**Question (asked *before* launch):** if the campaign truly works, **will our test be able to see it?**

A real experiment runs **once**, and that's one random draw. Depending on which geos you pick and how noise falls, the same true effect can come out large, small, or "not significant".

| Term | Meaning |
|---|---|
| **Power** | If the true effect is X%, the probability the test detects it (p < 0.05). Target: **≥ 80%** |
| **MDE** | The smallest true effect with power ≥ 80%: the "smallest reading on the scale" |
| **Power analysis** | Estimating power and MDE **before launch**, to choose # geos, test length, spend |
| **Underpowered** | A test whose power is too low; likely to come back "not significant" even if the ads work |
| **False-positive rate (α)** | Probability of "significant" when the true effect is 0; set to **5%** by p < 0.05 |

**The four outcomes:**

| | Test says **significant** | Test says **not significant** |
|---|---|---|
| **Ads truly work** | ✅ Detected → probability = **power** | ❌ Missed (false negative) |
| **Ads do nothing** | ❌ False positive (≈ 5%) | ✅ Correct |

**Analogy:** MDE is the smallest reading a scale can measure. A bathroom scale can't weigh a sip of water. That doesn't mean the water weighs nothing; the scale just isn't precise enough.

**Golden rule:** power analysis uses **only historical data**. The campaign hasn't happened yet, so simulate fake experiments inside the past.

---

## 2. When to use it

**✅ Always, before launching a geo test**, to answer:
- Is the **expected effect ≥ MDE**? If not, don't run the test as designed
- How many **treated geos** do we need?
- How **long** should the test run, and **when**?
- How much **spend** is needed to push the expected effect above the MDE?

| Expected effect vs MDE | Decision |
|---|---|
| Expected **>** MDE | ✅ Run it |
| Expected **≈** MDE | ⚠️ Borderline, ~80% chance of success |
| Expected **<** MDE | ❌ Redesign or don't run: an inconclusive result wastes budget and may be misread as "ads don't work" |

**Levers to lower the MDE:**

| Lever | Effect | Caveat |
|---|---|---|
| More treated geos | Noise shrinks ~1/√n | Diminishing returns; costs budget; fewer controls left |
| Longer test | More data | Only helps if before/after windows stay **comparable** (avoid seasonal transitions) |
| Larger / less noisy geos | Less noise per geo | Fewer candidates |
| More stable KPI | Less noise | e.g., sessions instead of purchases |
| Higher spend intensity | Raises the effect itself | Costs more |
| Avoid Q4 / holidays | States react differently in holidays → noise | Limits scheduling |
| Longer history for the analysis | Better noise estimate | Needs data |

---

## 3. Formula

**Simulation-based power** (what we did; works for any estimator):

1. **Null:** simulate *B* fake experiments with **lift = 0** on historical data → estimates $\hat{\tau}^{(b)}_0$
   **Critical value:** $c = q_{0.95}\big(|\hat{\tau}^{(b)}_0|\big)$ ← the "p < 0.05" line
2. **Alternative:** simulate *B* fake experiments with **true lift = L** → estimates $\hat{\tau}^{(b)}_L$
3. **Power:**

$$\text{Power}(L) = \frac{1}{B}\sum_{b=1}^{B} \mathbb{1}\left[\,|\hat{\tau}^{(b)}_L| > c\,\right]$$

4. **MDE** = smallest *L* with Power(L) ≥ 0.8

**Translation:** "Out of B simulated experiments with a real L% effect, what share land beyond the noise line?"

**Scaling rule of thumb** (noise ∝ 1/√n):

$$\text{MDE}_n \approx \text{MDE}_{n_0} \times \sqrt{\frac{n_0}{n}}$$

**Textbook shortcut** (for reference, assumes normal noise with std σ):

$$\text{MDE} \approx (z_{0.975} + z_{0.80})\,\sigma \approx 2.8\,\sigma$$

Here σ ≈ 1.8–2.1% → MDE ≈ 5–6%, consistent with the simulation.

**Python:**
```python
def simulate(n_treated, lift, test_days, sims=300, seed=0):
    rng = np.random.default_rng(seed)
    before, after = windows(test_days)
    estimates = []
    for _ in range(sims):
        treated = list(rng.choice(STATES, n_treated, replace=False))
        control = [s for s in STATES if s not in treated]
        Y = hist.copy()
        Y.loc[after, treated] *= 1 + lift
        estimates.append(did_lift(Y, treated, control, before, after))
    return np.array(estimates)

def power(n_treated, lift, test_days):
    null = simulate(n_treated, 0, test_days, seed=1)
    critical = np.quantile(np.abs(null), 0.95)
    estimates = simulate(n_treated, lift, test_days, seed=2)
    return np.mean(np.abs(estimates) > critical)

mde = next((lift for lift in LIFTS if power(6, lift, 28) >= 0.8), None)
```

---

## 4. Example (case 05 results)

GA4 Google Merchandise Store sample, 34 states, **historical data only** (11/01/2020 – 01/03/2021, 64 days). DiD, 300 simulations per point.

### One draw vs many draws (6 states, true lift 6%)
| Seed | 1 | 2 | 3 |
|---|---|---|---|
| Estimate | 7.0% | 7.4% | 5.3% |

### Power curve (6 states × 28 days)
| True lift | 0% | 2% | 4% | 6% | 8% | 10% | 15% |
|---|---|---|---|---|---|---|---|
| Power | 0.07 | 0.14 | 0.57 | **0.86** | 0.98 | 1.00 | 1.00 |

**MDE = 6%.** Power at 0% ≈ 5–7% = false-positive rate (sanity check ✅).

### Lever 1: more treated states (28 days)
| States | Predicted 6% × √(6/n) | MDE | Power at 2% |
|---|---|---|---|
| 3 | 8.5% | 8% | 0.09 |
| 6 | 6% | 6% | 0.14 |
| 10 | 4.6% | ≈ 4–5% (0.79 at 4%, 0.91 at 5%) | 0.35 |
| 15 | 3.8% | 4% | 0.36 |
| 17 (half of all) | | | 0.42 |

→ 1/√n prediction matched; diminishing returns; **2% stays undetectable** even with half the states treated.

### Lever 2: longer test (6 states)
| Days | Before → After | National change | Noise std | MDE |
|---|---|---|---|---|
| 14 | 12/07–12/20 → 12/21–01/03 | −41% | 2.8% | 10% |
| 21 | 11/23–12/13 → 12/14–01/03 | −22% | 2.6% | 8% |
| **28** | 11/09–12/06 → 12/07–01/03 | **+6%** | **1.8%** | **6%** |
| 32 | 11/01–12/02 → 12/03–01/03 | +11% | 2.2% | 8% |

→ **Surprise: 32 days was worse than 28.** Noise depends on how comparable the windows are, not just length. Big seasonal swings make states react differently (weaker parallel trends). Avoid seasonal transitions like Q4.

### Business decision: "we expect 2%, run 6 states × 4 weeks"
- Power for 2% = 0.14 → **don't run as designed**
- Recommend: raise spend intensity so expected lift ≥ 5%, run 10 states × 4 weeks (power ≈ 0.91 at 5%), avoid Q4, redo the analysis on a full year of history
- If the effect really is ~2%, a geo test on this data can't measure it
