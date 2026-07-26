# ============================================================
# 02_clean_and_analyze.R
# ------------------------------------------------------------
# Purpose: Clean the raw campaign export, validate it, compute
# marketing KPIs, run A/B significance tests, and export
# Tableau-ready CSVs.
#
# Steps:
#   1. Load raw data
#   2. Standardize channel names and date formats
#   3. Remove duplicates
#   4. Handle missing values
#   5. Flag / remove impossible rows
#   6. Compute KPIs: CTR, conversion rate, CAC, ROAS
#   7. Run statistical significance test per channel (A vs B)
#   8. Export clean daily data + summary tables for Tableau
# ============================================================

library(dplyr)
library(lubridate)
library(readr)
library(broom)

raw <- read_csv("data/raw/campaign_raw.csv", show_col_types = FALSE)

cat("Rows in raw file:", nrow(raw), "\n")

# ---- Step 1: Validate raw data BEFORE cleaning (know what you're dealing with) ----
cat("\n--- Pre-clean validation ---\n")
cat("Unique channel spellings found:\n")
print(table(raw$channel))
cat("Missing spend values:", sum(is.na(raw$spend)), "\n")
cat("Exact duplicate rows:", sum(duplicated(raw)), "\n")
cat("Rows where conversions > clicks (impossible):",
    sum(raw$conversions > raw$clicks, na.rm = TRUE), "\n")

# ---- Step 2: Standardize channel names ----
standardize_channel <- function(x) {
  x <- trimws(x)
  case_when(
    tolower(x) %in% c("facebook", "fb")                 ~ "Facebook",
    tolower(x) %in% c("google search", "google")         ~ "Google Search",
    tolower(x) %in% c("instagram", "ig")                 ~ "Instagram",
    tolower(x) %in% c("email")                           ~ "Email",
    tolower(x) %in% c("tiktok", "tik tok")               ~ "TikTok",
    TRUE ~ x
  )
}

# ---- Step 3: Parse inconsistent date formats safely ----
parse_flexible_date <- function(x) {
  # Try ISO (YYYY-MM-DD) first, then MM/DD/YYYY, then DD-MM-YYYY.
  # This explicit order avoids the classic bug of guessing wrong on
  # ambiguous dates (like day <= 12) — each format is tried in a
  # fixed, known priority instead of "auto-detecting."
  parsed <- suppressWarnings(ymd(x))
  parsed[is.na(parsed)] <- suppressWarnings(mdy(x[is.na(parsed)]))
  parsed[is.na(parsed)] <- suppressWarnings(dmy(x[is.na(parsed)]))
  parsed
}

clean <- raw %>%
  mutate(
    channel = standardize_channel(channel),
    date = parse_flexible_date(date)
  )

# ---- Step 4: Remove exact duplicate rows ----
n_before <- nrow(clean)
clean <- clean %>% distinct()
cat("\nRemoved", n_before - nrow(clean), "exact duplicate rows.\n")

# ---- Step 5: Handle missing spend values ----
# Impute missing spend using the median spend for that channel + variant,
# rather than dropping rows outright (dropping would bias CAC calculations
# since it would remove real conversions from the denominator context).
clean <- clean %>%
  group_by(channel, variant) %>%
  mutate(spend = if_else(is.na(spend), median(spend, na.rm = TRUE), spend)) %>%
  ungroup()

# ---- Step 6: Flag and remove impossible rows ----
n_before <- nrow(clean)
impossible <- clean %>% filter(conversions > clicks)
clean <- clean %>% filter(conversions <= clicks)
cat("Removed", n_before - nrow(clean), "rows where conversions > clicks (tracking errors).\n")

# ---- Step 7: Sanity-check date range and completeness ----
cat("\nDate range after cleaning:", as.character(min(clean$date)), "to", as.character(max(clean$date)), "\n")
expected_rows <- n_distinct(clean$date) * length(unique(clean$channel)) * length(unique(clean$variant))
cat("Expected rows (days x channels x variants):", expected_rows, "| Actual:", nrow(clean), "\n")

# ---- Step 8: Compute core KPIs ----
clean <- clean %>%
  mutate(
    ctr = clicks / impressions,
    conversion_rate = conversions / clicks,
    cac = round(spend / conversions, 2),          # Customer Acquisition Cost
    roas = round(revenue / spend, 2)              # Return on Ad Spend
  )

write_csv(clean, "data/clean/campaign_daily_clean.csv")

# ---- Step 9: A/B significance test per channel ----
# For each channel, test whether Variant B's conversion rate is
# statistically different from Variant A's, using a two-proportion
# z-test (prop.test) on total clicks vs total conversions.
ab_results <- clean %>%
  group_by(channel, variant) %>%
  summarise(
    total_clicks = sum(clicks),
    total_conversions = sum(conversions),
    total_spend = sum(spend),
    total_revenue = sum(revenue),
    .groups = "drop"
  ) %>%
  mutate(
    conversion_rate = round(total_conversions / total_clicks, 4),
    cac = round(total_spend / total_conversions, 2),
    roas = round(total_revenue / total_spend, 2)
  )

run_sig_test <- function(ch) {
  d <- ab_results %>% filter(channel == ch)
  a <- d %>% filter(variant == "A")
  b <- d %>% filter(variant == "B")
  test <- prop.test(
    x = c(a$total_conversions, b$total_conversions),
    n = c(a$total_clicks, b$total_clicks)
  )
  tibble(
    channel = ch,
    variant_a_cvr = a$conversion_rate,
    variant_b_cvr = b$conversion_rate,
    p_value = round(test$p.value, 4),
    significant_at_95 = test$p.value < 0.05,
    winner = if_else(test$p.value < 0.05,
                      if_else(b$conversion_rate > a$conversion_rate, "B", "A"),
                      "No significant difference")
  )
}

sig_summary <- map_dfr(unique(ab_results$channel), run_sig_test)

write_csv(ab_results, "data/clean/ab_test_summary.csv")
write_csv(sig_summary, "data/clean/ab_significance_results.csv")

cat("\n--- A/B Test Significance Results ---\n")
print(sig_summary)

# ---- Step 10: Channel-level rollup for CAC / ROAS comparison chart ----
channel_summary <- clean %>%
  group_by(channel) %>%
  summarise(
    total_spend = sum(spend),
    total_conversions = sum(conversions),
    total_revenue = sum(revenue),
    cac = round(total_spend / total_conversions, 2),
    roas = round(total_revenue / total_spend, 2),
    conversion_rate = round(sum(conversions) / sum(clicks), 4)
  ) %>%
  arrange(cac)

write_csv(channel_summary, "data/clean/channel_summary.csv")

cat("\n--- Channel Summary (CAC / ROAS) ---\n")
print(channel_summary)

cat("\nAll clean files written to data/clean/\n")
