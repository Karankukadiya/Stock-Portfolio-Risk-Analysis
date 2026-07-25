library(dplyr)
library(tidyr)

stock_data <- read.csv("data/raw/stock_prices_raw.csv")

stock_clean <- stock_data %>%
    select(symbol, date, adjusted) %>%
    arrange(symbol, date) %>%
    drop_na()

write.csv(stock_clean, "data/processed/stock_prices_clean.csv", row.names = FALSE)