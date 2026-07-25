library(reshape2)

returns_wide <- returns_daily %>%
    pivot_wider(names_from = symbol, values_from = daily_return)

corr_matrix <- cor(returns_wide[,-1], use = "complete.obs")

corr_long <- melt(corr_matrix)
write.csv(corr_long, "data/processed/correlation_matrix.csv", row.names = FALSE)