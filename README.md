# Geo Lift: Incrementality Testing on GA4 Data

Eight case studies on designing and reading geo experiments, built on real GA4 traffic and checked against Meta's open-source **GeoLift**:

**market selection → power / MDE → DiD & synthetic control → placebo inference → iROAS**

Every test is **semi-synthetic**: real state-level traffic (with real noise and holiday seasonality) plus a lift injected at a known size. Because the true effect is known, each method can be graded on how close it gets.

📘 **[Field guide](https://fcwvivian.github.io/geo-lift-incrementality/docs/field_guide.html)**: the whole workflow as one decision tree (which method, which number, which threshold), plus a formula sheet and glossary.

## Key findings

| Question | Finding |
|---|---|
| Does a before/after comparison work? | No. Texas showed **−3.4%** "lift" with zero true effect; the typical state dropped 4.4% from December to January. |
| How noisy is a single-geo test? | Placebo DiD error was **5.1%** for a typical state (Illinois: +5.1% with no ads). Pooling 6 states cut it to **1.8%**. |
| Is synthetic control better than DiD? | Better pre-period fit (MAE 0.067), but **no better on placebo error**: 3.3% vs 2.9%, winning 17 of 34 states. |
| Is a 6.9% lift real? | Placebo test: **p < 0.001**, 95% CI **[2.8%, 10.5%]** (true lift 8%). A real 2% lift returned p = 0.76: underpowered, not "no effect". |
| Can a 6-state, 4-week test detect a 2% lift? | No. **MDE = 6%**; power at 2% is 0.14, and only 0.42 even with half of all states treated. A 32-day window was *worse* than 28. |
| Do the best historical geo sets stay best? | No. The top sets from a 2,000-set search were 4× better in history but showed **no advantage out-of-sample** (correlation −0.01). |
| Was the campaign worth it? | **iROAS 1.33** (0.57–1.97) vs a 2.0 profit break-even → loses money. Platform ROAS (3.5) overstated the return ~2.6×. |
| How does Meta GeoLift compare? | GeoLift **7.4%** vs DiD **6.9%** (truth 8%); both CIs covered the truth. On a zero-effect placebo it returned +4.5% with p = 0.61. |

## Case studies

| # | Notebook | Question | Method note |
|---|---|---|---|
| 01 | [Why before/after fails](01_why_before_after_fails.ipynb) | Would a before/after comparison measure the campaign? | |
| 02 | [Difference-in-differences](02_difference_in_differences.ipynb) | Does a control group remove seasonality? How noisy is one geo? | [DiD](docs/02_difference_in_differences.md) |
| 03 | [Synthetic control](03_synthetic_control.ipynb) | Does a custom weighted control beat DiD? | [SCM](docs/03_synthetic_control.md) |
| 04 | [Placebo inference](04_placebo_inference.ipynb) | Is the lift real? What range is plausible? | [Inference](docs/04_placebo_inference.md) |
| 05 | [Power analysis & MDE](05_power_analysis_mde.ipynb) | Can the design detect the expected effect? Which levers help? | [Power](docs/05_power_analysis_mde.md) |
| 06 | [Market selection](06_market_selection.ipynb) | Which geos should be treated? Does optimizing the choice hold up? | [Selection](docs/06_market_selection.md) |
| 07 | [iROAS & profit](07_iroas_and_profit.ipynb) | Was the campaign worth the money? | [iROAS](docs/07_iroas.md) |
| 08 | [Meta GeoLift comparison](08_meta_geolift_comparison.ipynb) | How does an industry tool compare on the same data? | [GeoLift](docs/08_meta_geolift.md) |

Each notebook follows the same structure: **question → answer → steps → findings → implications**.

## Data

- **Source:** BigQuery public dataset `bigquery-public-data.ga4_obfuscated_sample_ecommerce`, the Google Merchandise Store GA4 sample (2020-11-01 to 2021-01-31)
- **Panel:** [`sql/ga4_state_daily.sql`](sql/ga4_state_daily.sql) aggregates event-level data to **US state × day** (sessions, users, purchases, revenue) → [`data/ga4_state_daily.csv`](data/ga4_state_daily.csv)
- **Geo unit:** state. The DMA field in the older UA sample was mostly missing ("not available in demo dataset"); see [`data/profiling/`](data/profiling/)
- **Filtering:** 34 states with median ≥ 10 sessions/day (95.5% of sessions)
- **GeoLift inputs:** [`data/geolift_pre.csv`](data/geolift_pre.csv) (pre-period only) and [`data/geolift_experiment.csv`](data/geolift_experiment.csv) (8% lift injected into Texas, Florida, Georgia, Arizona, Ohio, Michigan from 2021-01-04)

## Reproduce

```bash
pip install -r requirements.txt
jupyter notebook          # run 01–07 top to bottom
```

The CSVs are included, so BigQuery is optional. To rebuild the panel (scans ~1.1 GB, within the free tier):

```bash
bq query --use_legacy_sql=false --format=csv --max_rows=10000 < sql/ga4_state_daily.sql > data/ga4_state_daily.csv
```

Case 08 runs in **Google Colab with an R runtime**: upload the notebook and the two `geolift_*.csv` files, then run the install cell (10–20 minutes).

## Limitations

- **Semi-synthetic:** lifts are injected, so results validate the *methods and design*, not a real campaign.
- **Obfuscated, scaled-down sample:** Google removed and noised part of the data, so state-level volumes are small and MDEs are large. Dollar amounts in case 07 are illustrative; the ratios are the point.
- **Short, seasonal history:** 64 pre-period days span Black Friday to New Year. GeoLift itself warns the pre-period is short (it recommends ≥ 4× the test length).
- **Revenue is modeled:** incremental revenue = incremental sessions × baseline CVR × AOV. Ad-driven visitors often convert worse, so iROAS is likely optimistic.
- **Spend and margin are assumed** ($800, 50%) to illustrate the iROAS and profit logic.
- **GeoLift workaround:** `GeoLift()` fails with multiple treated locations ([facebookincubator/GeoLift#230](https://github.com/facebookincubator/GeoLift/issues/230)), so treated states were aggregated into one unit, which is the same aggregation the DiD uses.

## Repository layout

```
├── 01 … 08 notebooks          case studies
├── docs/                      method notes + field guide (HTML)
├── data/                      state × day panel, GeoLift inputs, profiling of the UA sample
├── sql/                       BigQuery query that builds the panel
├── requirements.txt
└── LICENSE
```

## AI assistance

Developed with AI assistance (Claude) for code scaffolding, code review, and explanations. I ran every analysis, checked the results, and can walk through each decision.

## License

[MIT](LICENSE). The data in `data/` is derived from Google's public BigQuery sample dataset and remains subject to its original terms.
