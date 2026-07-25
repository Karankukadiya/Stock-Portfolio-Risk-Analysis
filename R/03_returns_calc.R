library(tidyquant)

returns_daily <- stock_clean %>%
    group_by(symbol) %>%
    tq_transmute(select = adjusted,
                mutate_fun = periodReturn,
                period = "daily",
                col_rename = "daily_return")

returns_monthly <- stock_clean %>%
    group_by(symbol) %>%
    tq_transmute(select = adjusted,
                mutate_fun = periodReturn,
                period = "monthly",
                col_rename = "monthly_return")

write.csv(returns_daily, "data/processed/returns_daily.csv", row.names = FALSE)
write.csv(returns_monthly, "data/processed/returns_monthly.csv", row.names = FALSE)