# Marketing Campaign ROI Dashboard

An end-to-end marketing analytics project that simulates a multi-channel A/B test for an
e-commerce advertiser, cleans a messy raw export in **R**, computes core marketing KPIs
and statistical significance, and visualizes the results in an interactive **Tableau**
dashboard.

---

## Project Overview

**Scenario:** An e-commerce company runs Variant A (original ad creative) vs. Variant B
(new ad creative) across 5 channels — Facebook, Google Search, Instagram, Email, and
TikTok — over a 90-day period (Jan 1 – Mar 30, 2024).

**Goal:** Determine which channels and creative variants deliver the best return on ad
spend (ROAS), lowest customer acquisition cost (CAC), and statistically significant lift,
then turn that into a budget-reallocation recommendation.

**Tech stack:**
| Layer | Tool |
|---|---|
| Data simulation & cleaning | R (`dplyr`, `lubridate`, `readr`, `broom`, `purrr`) |
| Statistical testing | R (`prop.test` — two-proportion z-test) |
| Visualization | Tableau (`Dashboard.twb`) |

---

## Repository Structure

```
├── 01_generate_data.R              # Simulates a realistic, messy raw ad-platform export
├── 02_clean_and_analyze.R          # Cleans data, computes KPIs, runs A/B significance tests
├── campaign_daily_clean.csv        # Cleaned daily grain data (date x channel x variant)
├── ab_test_summary.csv             # Aggregated totals per channel x variant
├── ab_significance_results.csv     # Two-proportion z-test results per channel (A vs B)
├── channel_summary.csv             # Channel-level rollup (CAC, ROAS, conversion rate)
├── Dashboard.twb                   # Tableau workbook (4 worksheets)
└── README.md
```

## Tableau Dashboard

`Dashboard.twb` contains four worksheets:
1. **Daily Trend** – Spend, revenue, and conversions over time by channel
2. **Spend vs. Conversions** – Efficiency scatter/comparison across channels
3. **CAC by Channel** – Customer acquisition cost ranked by channel
4. **A/B Conversion Rate Comparison** – Variant A vs. B conversion rates per channel

Open with Tableau Desktop / Public and point the data source connection at
`campaign_daily_clean.csv`, `ab_test_summary.csv`, and `channel_summary.csv` if prompted
to relocate the file.

## Methodology

1. **Simulate** a realistic raw export with intentional messiness: inconsistent channel
   naming/casing, mixed date formats (`MM/DD/YYYY` vs `DD-MM-YYYY`), missing spend values,
   impossible rows (conversions > clicks), and duplicate rows.
2. **Clean**: standardize channel names, parse dates in a fixed priority order (ISO →
   MDY → DMY), drop exact duplicates, impute missing spend with the channel/variant
   median, and remove impossible rows.
3. **Compute KPIs**: CTR, conversion rate, CAC (spend / conversions), ROAS
   (revenue / spend).
4. **Test significance**: a two-proportion z-test (`prop.test`) per channel, comparing
   Variant A vs. B conversion rates at the 95% confidence level.
5. **Export** Tableau-ready CSVs and build the dashboard.

## Known Data Quality Note

A small number of rows (~2%) carry dates outside the intended Jan 1 – Mar 30, 2024
window (a handful straying as far as October–December). This stems from inherent
ambiguity in `DD-MM-YYYY` vs `MM-DD-YYYY` formats when both day and month are ≤ 12
(e.g., `03/04/2024` could be March 4 or April 3) — no fixed parsing order can resolve
that case with certainty from the value alone. These rows are immaterial to the totals
(under 2% of rows) but are worth flagging as a real-world reminder to capture the date
format at the source system rather than reconstruct it after export.

## Reproducing the Analysis

```r
# From the project root, with an R environment that has dplyr, lubridate, readr, broom, purrr
Rscript 01_generate_data.R          # writes data/raw/campaign_raw.csv
Rscript 02_clean_and_analyze.R      # writes data/clean/*.csv
```

Then open `Dashboard.twb` in Tableau and refresh the data source.

## Headline Results

| Metric | Value |
|---|---|
| Total ad spend | $35,749.84 |
| Total revenue | $658,172.02 |
| Blended ROAS | 18.4x |
| Blended CAC | $2.95 |
| Total conversions | 11,109 |

See `Marketing_Campaign_ROI_Report.docx` for the full write-up of insights, trends, and
recommendations, and `Marketing_Campaign_ROI_Deck.pptx` for the stakeholder-ready summary.

## 📄 Deliverables in this Package

- **README.md** – this file
- **Marketing_Campaign_ROI_Report.docx** – full analysis report (insights, trends, recommendations)
- **Marketing_Campaign_ROI_Deck.pptx** – executive presentation deck
