library(tidyquant)
library(dplyr)

tickers <- c("AAPL", "MSFT", "GOOGL", "AMZN", "TSLA", "^GSPC")  # ^GSPC = S&P500 (benchmark)

stock_data <- tq_get(tickers,
                        from = "2019-01-01",
                        to = Sys.Date(),
                        get = "stock.prices")

write.csv(stock_data, "data/raw/stock_prices_raw.csv", row.names = FALSE)