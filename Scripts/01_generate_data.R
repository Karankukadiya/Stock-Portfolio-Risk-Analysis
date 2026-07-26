# ============================================================
# 01_generate_data.R
# ------------------------------------------------------------
# Purpose: Simulate a realistic marketing A/B test dataset.
#
# In a real job, this data would come from your ad platforms
# (Meta Ads Manager, Google Ads, TikTok Ads, email service
# provider) via their APIs or exported reports, then combined
# into one table. Since this is a portfolio project without
# access to a live ad account, this script SIMULATES that export
# — including realistic messiness (inconsistent naming, missing
# values, bad rows, duplicates) so the cleaning script has real
# problems to solve, just like a real export would.
#
# Scenario: An e-commerce company is running Variant A (original
# ad creative) vs Variant B (new ad creative) across 5 channels,
# over a 90-day period (Jan 1 - Mar 30, 2024).
# ============================================================

library(dplyr)
library(purrr)

set.seed(42)

channels  <- c("Facebook", "Google Search", "Instagram", "Email", "TikTok")
variants  <- c("A", "B")
start_date <- as.Date("2024-01-01")
n_days <- 90

# Baseline performance assumptions per channel x variant.
# These control the "story" the data will tell:
#   - Facebook & Instagram: Variant B (new creative) wins
#   - Google Search: Variant A (original) wins narrowly
#   - Email: statistical tie
#   - TikTok: Variant B wins clearly, and the channel grows over time
profiles <- tribble(
  ~channel,        ~variant, ~impr, ~ctr,   ~cvr,   ~cpm,
  "Facebook",       "A",     8000,  0.018,  0.045,  6.5,
  "Facebook",       "B",     8000,  0.024,  0.052,  6.5,
  "Google Search",  "A",     5000,  0.045,  0.090,  12.0,
  "Google Search",  "B",     5000,  0.041,  0.085,  12.0,
  "Instagram",      "A",     9000,  0.015,  0.030,  5.5,
  "Instagram",      "B",     9000,  0.021,  0.038,  5.5,
  "Email",          "A",     3000,  0.080,  0.120,  1.0,
  "Email",          "B",     3000,  0.085,  0.110,  1.0,
  "TikTok",         "A",     7000,  0.020,  0.025,  4.0,
  "TikTok",         "B",     7000,  0.030,  0.040,  4.0
)

simulate_day <- function(d) {
  date <- start_date + d
  growth_tiktok  <- 1 + (d / n_days) * 0.6   # TikTok scales up over time
  fatigue_google <- 1 - (d / n_days) * 0.15  # Google Search creative fatigues

  profiles %>%
    rowwise() %>%
    mutate(
      date = date,
      impressions = round(rnorm(1, impr, impr * 0.1)),
      impressions = if_else(channel == "TikTok", round(impressions * growth_tiktok), impressions),
      ctr_actual  = max(0.001, rnorm(1, ctr, ctr * 0.15)),
      ctr_actual  = if_else(channel == "Google Search", ctr_actual * fatigue_google, ctr_actual),
      clicks      = pmax(1, round(impressions * ctr_actual)),
      cvr_actual  = max(0.001, rnorm(1, cvr, cvr * 0.15)),
      conversions = round(clicks * cvr_actual),
      spend       = round(impressions / 1000 * cpm * rnorm(1, 1, 0.05), 2),
      aov         = max(20, rnorm(1, 55, 8)),
      revenue     = round(conversions * aov, 2)
    ) %>%
    ungroup() %>%
    select(date, channel, variant, impressions, clicks, conversions, spend, revenue)
}

clean_truth <- map_dfr(0:(n_days - 1), simulate_day)

# ---- Inject realistic real-world messiness for the RAW export ----
channel_aliases <- list(
  "Facebook"      = c("Facebook", "facebook", "FB"),
  "Google Search" = c("Google Search", "google search", "Google"),
  "Instagram"     = c("Instagram", "instagram", "IG"),
  "Email"         = c("Email", "email", "EMAIL"),
  "TikTok"        = c("TikTok", "tiktok", "Tik Tok")
)

messy <- clean_truth %>%
  rowwise() %>%
  mutate(
    # ~15% of dates exported in an inconsistent format
    date = if (runif(1) < 0.15) {
      format(date, sample(c("%m/%d/%Y", "%d-%m-%Y"), 1))
    } else {
      as.character(date)
    },
    # ~20% of channel names in inconsistent casing/abbreviation
    channel = if (runif(1) < 0.2) sample(channel_aliases[[channel]], 1) else channel,
    # ~3% missing spend values (common in ad platform exports)
    spend = if (runif(1) < 0.03) NA else spend,
    # ~1% impossible rows: conversions greater than clicks (tracking glitch)
    conversions = if (runif(1) < 0.01) clicks + sample(1:5, 1) else conversions
  ) %>%
  ungroup()

# Add ~10 duplicate rows (a common export artifact from re-pulled reports)
dupes <- messy %>% slice_sample(n = 10)
raw_export <- bind_rows(messy, dupes) %>% slice_sample(prop = 1)

write.csv(raw_export, "data/raw/campaign_raw.csv", row.names = FALSE)

cat("Raw rows written:", nrow(raw_export), "\n")
