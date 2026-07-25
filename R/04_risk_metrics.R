library(PerformanceAnalytics)
library(tidyquant)

risk_free_rate <- 0.03 / 252  # daily risk-free rate assumption

risk_metrics <- returns_daily %>%
    group_by(symbol) %>%
    summarise(
        volatility = sd(daily_return) * sqrt(252),
        mean_return = mean(daily_return) * 252,
        sharpe_ratio = (mean_return - 0.03) / volatility,
        VaR_95 = quantile(daily_return, 0.05),
        CVaR_95 = mean(daily_return[daily_return <= quantile(daily_return, 0.05)])
    )

write.csv(risk_metrics, "data/processed/risk_metrics.csv", row.names = FALSE)