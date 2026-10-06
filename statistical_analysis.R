# ============================================================
# VIVIANA MALL - SILENT ANALYSIS (Only final summary output)
# ============================================================

# 1. SET WORKING DIRECTORY
setwd("C:/Users/DELL/PyCharmProjects/JupyterProject")

# 2. LOAD LIBRARIES
suppressMessages({
  library(readxl)
  library(ggplot2)
  library(dplyr)
  library(fitdistrplus)
  library(lubridate)
})

# 3. IMPORT DATA
df <- read_excel("viviana_mall_data.xlsx", sheet = "Data")
df$Arrival_DT <- as.POSIXct(paste(df$Date, df$Arrival_Time), format="%d-%m-%Y %H:%M:%S")
df <- df %>% arrange(Outlet_Name, Arrival_DT)

# ============================================================
# TEST 1: CHI-SQUARE
# ============================================================
df <- df %>%
  group_by(Outlet_Name) %>%
  mutate(Inter_Arrival_mins = as.numeric(difftime(Arrival_DT, lag(Arrival_DT), units="mins"))) %>%
  ungroup()

df_clean <- df %>% filter(!is.na(Inter_Arrival_mins), Inter_Arrival_mins > 0)
chi_p_values <- c()

for (outlet_name in unique(df_clean$Outlet_Name)) {
  subset_data <- df_clean$Inter_Arrival_mins[df_clean$Outlet_Name == outlet_name]
  if(length(subset_data) < 10) next
  
  lambda_hat <- 1 / mean(subset_data)
  breaks <- quantile(subset_data, probs = seq(0, 1, 0.25))
  breaks[1] <- 0
  breaks[length(breaks)] <- max(subset_data) + 0.01
  
  observed <- table(cut(subset_data, breaks = breaks, include.lowest = TRUE))
  expected_probs <- diff(pexp(breaks, rate = lambda_hat))
  expected_probs[length(expected_probs)] <- 1 - sum(expected_probs[-length(expected_probs)])
  
  chi_res <- chisq.test(x = as.numeric(observed), p = expected_probs)
  chi_p_values[outlet_name] <- round(chi_res$p.value, 4)
}

# ============================================================
# TEST 2: TWO-SAMPLE Z-TEST
# ============================================================
dominos_wait <- df$Wait_Time_mins[df$Outlet_Name == "Dominos"]
mcdonalds_wait <- df$Wait_Time_mins[df$Outlet_Name == "McDonald's"]
n1 <- length(dominos_wait); n2 <- length(mcdonalds_wait)
mean1 <- mean(dominos_wait); mean2 <- mean(mcdonalds_wait)
sd1 <- sd(dominos_wait); sd2 <- sd(mcdonalds_wait)
z_stat <- (mean1 - mean2) / sqrt((sd1^2/n1) + (sd2^2/n2))
p_value_z <- 2 * pnorm(-abs(z_stat))

# ============================================================
# TEST 3: ONE-SAMPLE Z-TEST
# ============================================================
all_wait <- df$Wait_Time_mins
mu_0 <- 5
z_stat_1 <- (mean(all_wait) - mu_0) / (sd(all_wait) / sqrt(length(all_wait)))
p_value_1sample <- 1 - pnorm(z_stat_1)

# ============================================================
# TEST 4: ANOVA
# ============================================================
anova_model <- aov(Wait_Time_mins ~ Outlet_Name, data = df)
anova_p_value <- summary(anova_model)[[1]][["Pr(>F)"]][1]

# ============================================================
# TEST 5: T-TEST
# ============================================================
t_test_res <- t.test(Wait_Time_mins ~ Day_Type, data = df)
t_p_value <- t_test_res$p.value

# ============================================================
# TEST 6: ERLANG vs EXPONENTIAL
# ============================================================
fit_gamma <- suppressWarnings(fitdist(df$Service_Time_mins, "gamma"))
fit_exp <- suppressWarnings(fitdist(df$Service_Time_mins, "exp"))
aic_gamma <- fit_gamma$aic
aic_exp <- fit_exp$aic

# ============================================================
# PLOTS
# ============================================================
p1 <- ggplot(df, aes(x = Outlet_Name, y = Wait_Time_mins, fill = Outlet_Name)) +
  geom_boxplot() + labs(title = "Wait Time by Outlet", x = "Outlet", y = "Wait Time (mins)") + theme_minimal()

p2 <- ggplot(df, aes(x = Time_Slot, y = Wait_Time_mins, fill = Time_Slot)) +
  geom_boxplot() + labs(title = "Wait Time by Time Slot", x = "Time Slot", y = "Wait Time (mins)") + theme_minimal()

p3 <- ggplot(df, aes(x = Num_People_Ahead, y = Wait_Time_mins)) +
  geom_point(alpha = 0.5, color = "blue") + geom_smooth(method = "lm", color = "red") +
  labs(title = "Queue Length vs. Wait Time", x = "People Ahead", y = "Wait Time (mins)") + theme_minimal()

# ============================================================
# FINAL CLEAN SUMMARY (ONLY THIS WILL PRINT)
# ============================================================
cat("\n\n########################################\n")
cat("   VIVIANA MALL - FINAL SUMMARY OUTPUT   \n")
cat("########################################\n\n")

cat("--- TEST 1: CHI-SQUARE (Poisson Test) ---\n")
print(chi_p_values)

cat("\n--- TEST 2: TWO-SAMPLE Z-TEST (Dominos vs McD) ---\n")
cat("P-Value:", round(p_value_z, 4), "\n")

cat("\n--- TEST 3: ONE-SAMPLE Z-TEST (Wait vs 5-min) ---\n")
cat("P-Value:", round(p_value_1sample, 4), "\n")

cat("\n--- TEST 4: ANOVA ---\n")
cat("P-Value:", format(anova_p_value, scientific = FALSE), "\n")

cat("\n--- TEST 5: T-TEST (Weekday vs Weekend) ---\n")
cat("P-Value:", round(t_p_value, 4), "\n")

cat("\n--- TEST 6: ERLANG vs EXPONENTIAL ---\n")
cat("AIC (Gamma/Erlang):", round(aic_gamma, 2), "\n")
cat("AIC (Exponential):", round(aic_exp, 2), "\n")
cat("Erlang Shape (k):", round(fit_gamma$estimate["shape"]), "\n")

cat("\n✅ ANALYSIS COMPLETE!\n")
cat("Check the 'Plots' tab in the bottom-right pane for the 3 charts.\n") 
