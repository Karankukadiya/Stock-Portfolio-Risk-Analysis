master_export <- returns_daily %>%
    left_join(risk_metrics, by = "symbol") %>%
    left_join(beta_data, by = "symbol")

write.csv(master_export, "data/processed/tableau_master_dataset.csv", row.names = FALSE)