# Placebo Inference (p-value & Confidence Interval) — Method Note

## 1. Concept

**Question:** we estimated a lift of 6.9%. **Is it real, or could it be noise?** And **how big is the effect, really?**

**Placebo (permutation) test:** run the *same* analysis on **fake treatment groups** drawn from units that got **no** treatment. Their true effect is 0, so every result is **pure noise**. Repeat many times → the **distribution of lift that noise alone produces**, a "ruler for noise".

- **Placebo:** borrowed from medicine. A sugar pill that looks real but has no active ingredient; it shows what happens *without* the real treatment.
- Also called **permutation test** (reshuffling who is "treated") or **falsification test**.

From that ruler, two numbers:

| Number | Question it answers |
|---|---|
| **p-value** | *If* the ads did nothing, how often would noise produce a result at least this extreme? |
| **95% confidence interval** | What range of true effects is consistent with what we observed? |

```
          placebo lifts (noise only)
               ▁▃▅█▇▅▃▁
   ──────────────────────────────│──
  −5%         0%          +5%    6.9% ← our estimate, outside the noise → likely real
```

**Rules for valid placebos:**
1. Draw fake groups **only from control units**, so real treated units never enter a placebo (as fake-treated or fake-control).
2. Run placebos on data with **no treatment effect**. In a real experiment there's no clean copy, so rule 1 is the only protection. (In our semi-synthetic setup we also use `wide`, the un-injected data.)

---

## 2. When to use it

**✅ Good fit when:**
- You have **few treated units** (geo tests, a handful of DMAs/states), where textbook standard errors are unreliable
- The estimator has **no simple formula** for uncertainty (synthetic control, custom DiD)
- Noise is **not normally distributed** (the placebo distribution here was lumpy, not bell-shaped). Placebos measure noise directly from the data, no normality assumption needed.
- You want an explanation stakeholders can follow: "random groups of states never moved this much"

**⚠️ Be careful when:**
- **Too few control units:** few distinct placebo groups → coarse p-values
- **Too few placebo runs:** with N runs, the smallest resolvable p-value is 1/N (report "p < 0.001", not "p = 0")
- Control units **differ systematically** from treated units (placebos then measure the wrong noise)
- **Spillover** into control units contaminates the noise ruler
- **Borderline results:** p-value and CI can disagree at the edge, so report the CI

---

## 3. Formula

**Placebo distribution:**

$$\hat{\tau}^{(b)} = \text{lift}\big(\text{fake treated}_b,\ \text{fake control}_b\big), \quad b = 1, \dots, B \quad \text{(true effect = 0)}$$

**Two-sided p-value:**

$$p = \frac{1}{B}\sum_{b=1}^{B} \mathbb{1}\left[\,|\hat{\tau}^{(b)}| \ge |\hat{\tau}|\,\right]$$

"Share of placebo results at least as extreme as our estimate, in either direction."

**95% confidence interval:** estimate = truth + noise → truth = estimate − noise

$$\text{CI} = \Big[\ \hat{\tau} - q_{0.975}\big(\hat{\tau}^{(b)}\big),\ \ \hat{\tau} - q_{0.025}\big(\hat{\tau}^{(b)}\big)\ \Big]$$

The quantiles **swap**: if noise pushed the estimate up a lot (97.5th), the truth is lower → that gives the **lower** bound.

**Python:**
```python
rng = np.random.default_rng(42)
placebos = []
for _ in range(1000):
    fake_treated = list(rng.choice(CONTROL, 6, replace=False))
    fake_control = [s for s in CONTROL if s not in fake_treated]
    placebos.append(did_lift(wide, fake_treated, fake_control))
placebos = np.array(placebos)

p_value = np.mean(np.abs(placebos) >= abs(estimate))
ci_low  = estimate - np.quantile(placebos, 0.975)   # subtract LARGE noise → lower bound
ci_high = estimate - np.quantile(placebos, 0.025)   # subtract SMALL noise → upper bound
```

**Reading p-values correctly:**

| ❌ Wrong | ✅ Right |
|---|---|
| "p = 0.03 → 3% chance the ads didn't work" | "*If* the ads didn't work, a result this large appears 3% of the time" |
| "Small p → big effect" | Small p → *unlikely to be noise*; effect size comes from the estimate/CI |
| "p = 0.2 → the ads had no effect" | p = 0.2 → *can't distinguish from noise* (absence of evidence ≠ evidence of absence) |

**Rule of thumb:** a 95% CI excludes 0 ⟺ p < 0.05 (approximately; can disagree at the edge).

---

## 4. Example (case 04 results)

GA4 Google Merchandise Store sample, 34 states. **6 treated states:** Texas, Florida, Georgia, Arizona, Ohio, Michigan; 28 control states. DiD, before 12/7–1/3, after 1/4–1/31. 1,000 placebos (seed 42).

### Main test: true lift = 8%

| | Result |
|---|---|
| Estimate | **6.9%** (this group carries ≈ −1% of its own noise) |
| Placebo distribution | mean 0.4%, std **2.1%**, range −4.7% to +5.8% |
| p-value | **< 0.001** (0 of 1,000 placebos reached 6.9%) |
| 95% CI | **≈ [2.8%, 10.5%]**: contains the true 8%, excludes 0 |

### Smaller true lifts (same placebo ruler)

| True lift | Estimate | p-value | 95% CI | Significant? |
|---|---|---|---|---|
| 0% | −1.0% | 0.748 | [−5.1%, 2.6%] | No ✅ correct |
| 2% | 1.0% | 0.757 | [−3.1%, 4.6%] | No ⚠️ real effect missed |
| 5% | 3.9% | 0.040 | [−0.1%, 7.6%] | Borderline (p and CI disagree) |
| 10% | 8.9% | < 0.001 | [4.8%, 12.5%] | Yes |

**Quick prediction rule that matched every row:** estimate ≈ true lift − 1% (this group's noise); significant only if the estimate exceeds ~3.8% (95% of |placebo| values fall below it).

**Takeaways:**
- The placebo ruler is reusable: it never touches the injected data.
- **2% was real but undetectable.** "Not significant" meant "this design can't see 2%," not "the ads failed."
- **5% was borderline:** p = 0.04 but the CI touched 0. At the edge, report the range, not the label "significant."
- This design (6 states × 28 days) detects ~10% reliably, ~5% barely. Knowing that **before** launching is the **Minimum Detectable Effect (MDE)** → case 05 power analysis.
