library(dplyr)
library(purrr)

set.seed(42)

# basic setup
channels  <- c("Facebook", "Google Search", "Instagram", "Email", "TikTok")
variants  <- c("A", "B")
start_date <- as.Date("2024-01-01")
n_days <- 90

# Performance assumptions for each channel and variant
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

# Add some inconsistencies to mimic a raw export
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