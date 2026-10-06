# iROAS & Incremental Revenue — Method Note

## 1. Concept

**Question:** the ads worked (lift +6.9%, p < 0.001), but **was it worth the money?**

"Did it work?" and "Was it worth it?" are different questions. A highly significant lift can still lose money.

| Metric | Unit | Question |
|---|---|---|
| Lift | % | Did the ads change the KPI? |
| Incremental sessions | sessions | How many *extra* sessions did the ads **cause**? |
| Incremental revenue | $ | How much *extra* revenue did the ads cause? |
| **iROAS** (incremental Return On Ad Spend) | $ per $1 | For every $1 of spend, how much **incremental** revenue? |
| CPIS (cost per incremental session) | $ | What did each extra session cost? |
| Profit | $ | After product costs, did we make or lose money? |

**Attribution vs incrementality:**

| | Platform ROAS | iROAS |
|---|---|---|
| Question | Who **touched an ad** and then bought? | Who bought **because of** the ad? |
| Method | Ad exposure/click → later purchase → credit the ad | Compare geos with vs without ads |
| Nature | **Correlation** | **Causation** |
| Bias | Overstates (would-have-bought-anyway, retargeting, double counting, platform incentive) | Unbiased, but noisy (needs CI) |

**Analogy:** a restaurant hands out flyers at its door and counts every flyer-holder who eats as "flyer-driven". Many were coming anyway. A geo test hands out flyers in area A, not area B, and compares.

---

## 2. When to use it

**✅ Use iROAS when:**
- Deciding whether to **scale, hold, or cut** a channel/campaign
- Comparing channels on a **causal** basis (not platform-reported ROAS)
- **Calibrating** platform numbers or **MMM** channel ROIs with experiment results

**Always add:**
- The **confidence interval** (propagate the lift CI through to iROAS)
- The **profit view**: revenue break-even (iROAS = 1) ≠ profit break-even (iROAS = 1 / margin)

**⚠️ Be careful when:**
- **Converting sessions → revenue with baseline CVR:** ad-driven visitors often convert *worse* → iROAS may be overstated
- **Short test windows:** long-term / brand effects aren't captured
- **Margin assumptions:** break-even moves a lot with margin (50% → 2.0, 70% → 1.43)
- **Measuring revenue directly:** very noisy (here daily CV 2.44 vs 0.33 for sessions) → would need a much bigger test

---

## 3. Formula

**Incremental KPI** (lift is relative to the **counterfactual**):

$$\text{counterfactual} = \frac{\text{actual}}{1 + \text{lift}} \qquad \text{incremental} = \text{actual} - \text{counterfactual}$$

⚠️ Shortcut `actual × lift` overstates by ≈ the lift itself (it applies the lift to a base that already includes the ad effect).
⚠️ The counterfactual is the **treated geos without ads**, not the control geos' total. The control's role is already inside the DiD lift.

**Funnel conversion** (when revenue is too noisy to measure directly):

$$\text{incremental revenue} = \text{incremental sessions} \times \text{CVR} \times \text{AOV}$$

- CVR = purchases ÷ sessions; AOV = revenue ÷ purchases (treated geos, pre-period)

**Return metrics:**

$$\text{iROAS} = \frac{\text{incremental revenue}}{\text{ad spend}} \qquad \text{CPIS} = \frac{\text{ad spend}}{\text{incremental sessions}}$$

Unit check: iROAS = **revenue ÷ spend**. If both sides are revenue, it's wrong.

**Profit:**

$$\text{profit} = \text{incremental revenue} \times \text{margin} - \text{spend} \qquad \text{profit break-even iROAS} = \frac{1}{\text{margin}}$$

**Incrementality factor** (calibration):

$$\text{factor} = \frac{\text{iROAS}}{\text{platform ROAS}} \quad\Rightarrow\quad \widehat{\text{iROAS}}_{\text{future}} \approx \text{platform ROAS}_{\text{future}} \times \text{factor}$$

**Python:**
```python
counterfactual = actual / (1 + lift)
incremental_sessions = actual - counterfactual

cvr = hist_tr.purchases.sum() / hist_tr.sessions.sum()
aov = hist_tr.revenue.sum() / hist_tr.purchases.sum()
incremental_revenue = incremental_sessions * cvr * aov

iroas = incremental_revenue / SPEND
cpis  = SPEND / incremental_sessions
profit = incremental_revenue * MARGIN - SPEND
```

---

## 4. Example (case 07 results)

case 04's experiment: 6 treated states, true lift 8%, DiD estimate **6.9%** (95% CI 2.8%–10.5%). Assumed spend **$800**, gross margin **50%**, platform-attributed revenue **$2,800**. (GA4 sample is scaled down; the logic is identical at any scale.)

### A. Incremental sessions
| | Sessions |
|---|---|
| Actual (treated, test period) | 11,076 |
| Counterfactual = 11,076 / 1.069 | 10,361 |
| **Incremental** | **716** |
| Shortcut actual × lift | 765 (overstated) |

### B. Incremental revenue
| | Value |
|---|---|
| CVR (treated, pre-period) | 2.01% |
| AOV | $73.95 |
| **Incremental revenue** = 716 × 2.01% × $73.95 | **≈ $1,066** |

Why not measure revenue directly: daily revenue noise (CV 2.44) is ~7× sessions (0.33).

### C. Returns
- **iROAS = $1,066 / $800 = 1.33** → each $1 brought back $1.33 of revenue
- **CPIS = $800 / 716 = $1.12**

### D. Uncertainty and profit
| Case | Lift | iROAS | Profit |
|---|---|---|---|
| CI low | 2.8% | 0.57 | −$574 |
| Estimate | 6.9% | 1.33 | −$267 |
| CI high | 10.5% | 1.97 | −$13 |

- Revenue view: iROAS CI 0.57–1.97 **includes 1.0** → unclear even on revenue
- Profit view: break-even = 1 / 0.5 = **2.0** → **loses money in every case**
- **"The ads work" ≠ "the ads are worth it."**

### E. Platform ROAS vs iROAS
| | Revenue credited | Return per $1 |
|---|---|---|
| Platform (attribution) | $2,800 | **3.5** |
| Geo test (incrementality) | $1,066 | **1.33** |

→ Only **~38%** of platform-attributed revenue was incremental. Incrementality factor ≈ **0.38**.
→ Acting on platform ROAS (3.5 > 2.0) would scale a money-losing campaign.

### F. Recommendation
**Don't scale; pause or reduce, and re-test a cheaper version.** Next steps: test lower spend (diminishing returns), target higher-margin products / new customers, use incrementality (not platform ROAS) and calibrate the MMM. Caveats: baseline-CVR assumption likely makes iROAS optimistic; 4-week window misses long-term effects; break-even depends on margin.
