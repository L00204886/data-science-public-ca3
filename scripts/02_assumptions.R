# ============================================================
# CA3 Predictive Modelling - Airline passenger satisfaction
# Script 02: Check the training data against logistic regression
#            assumptions before fitting the model
# Author: Eamon Foy (L00204886)
# Report section: Building the predictive model
# Reads:  output/train_data.rds
# Writes: output/tables/tbl_outliers.csv
#         output/tables/tbl_skewness.csv
#         output/tables/tbl_predictor_checks.csv
#         output/tables/tbl_correlation.csv
#         output/figures/fig_boxplots.png
#         output/figures/fig_density.png
#         output/figures/fig_correlation.png
#         output/figures/fig_logit.png
# ============================================================

source("scripts/ensure_packages.R")
library(e1071) # skewness()
library(psych) # pairs.panels()

# Run all diagnostic checks on the training set only so the held-out
# test set never shapes variable transformations or model choices.
train_data <- readRDS("output/train_data.rds")


# ------------------------------------------------------------
# 1. Confirm that the outcome is binary and balanced enough
# ------------------------------------------------------------
cat("\n--- 1. Confirm binary outcome balance (training set) ---\n")

table(satisfaction = train_data$satisfaction)
round(100 * prop.table(table(satisfaction = train_data$satisfaction)), 1)
# Takeaway: satisfaction has two levels and 42.4% of training
# passengers are satisfied, so neither outcome class is rare.


# ------------------------------------------------------------
# 2. Check continuous predictors for outliers
# ------------------------------------------------------------
cat("\n--- 2. Check continuous predictors for outliers (1.5 x IQR) ---\n")

# Service ratings are bounded between 1 and 5 after cleaning, so
# outlier screening applies to the two continuous predictors only.
png("output/figures/fig_boxplots.png", width = 9, height = 4.5, units = "in", res = 300)
old_par <- par(mfrow = c(1, 2))
boxplot(train_data$age, main = "Age", ylab = "Years", col = "lightblue")
boxplot(train_data$arrival_delay, main = "Arrival delay", ylab = "Minutes", col = "lightblue")
par(old_par)
invisible(dev.off())

# boxplot.stats() flags observations above Q3 + 1.5 * IQR in $out and
# stores the upper whisker in $stats[5].
age_box <- boxplot.stats(train_data$age)
delay_box <- boxplot.stats(train_data$arrival_delay)

age_n_out <- length(age_box$out)
delay_n_out <- length(delay_box$out)

outliers <- data.frame(
  variable = c("age", "arrival_delay"),
  n_outliers = c(age_n_out, delay_n_out),
  pct_of_data = round(100 * c(age_n_out, delay_n_out) / nrow(train_data), 1),
  upper_whisker = c(age_box$stats[5], delay_box$stats[5])
)
outliers
write.csv(outliers, "output/tables/tbl_outliers.csv", row.names = FALSE)
# Takeaway: age has no outliers, whereas arrival_delay has 11,682 values
# above 32 minutes because most flights arrive on time and compress the IQR.
# These are genuine delayed flights rather than data errors, so they are kept
# and damped with a log transform in the next step.


# ------------------------------------------------------------
# 3. Check skewness, normality and category cell sizes
# ------------------------------------------------------------
cat("\n--- 3. Check skewness, normality and category cell sizes ---\n")

# Logistic regression does not require normal predictors, but severe
# skewness gives extreme tail values high leverage on a linear slope.
# Conventional skewness bands: within [-0.5, 0.5] is roughly symmetrical,
# 0.5 to 1 in magnitude is moderate, and beyond 1 is highly skewed.
# Adding 1 before taking logs handles the many zero-minute delays.
train_data$log_delay <- log(1 + train_data$arrival_delay)

age_density <- density(train_data$age)
delay_density <- density(train_data$arrival_delay)
log_delay_density <- density(train_data$log_delay)

png("output/figures/fig_density.png", width = 12, height = 4, units = "in", res = 300)
old_par <- par(mfrow = c(1, 3))
plot(
  age_density,
  main = "Density plot: Age",
  xlab = "Age",
  sub = paste("Skewness:", round(skewness(train_data$age), 2))
)
polygon(age_density, col = "red")

plot(
  delay_density,
  main = "Density plot: Arrival delay",
  xlab = "Minutes",
  sub = paste("Skewness:", round(skewness(train_data$arrival_delay), 2))
)
polygon(delay_density, col = "red")

plot(
  log_delay_density,
  main = "Density plot: log(1 + arrival delay)",
  xlab = "log minutes",
  sub = paste("Skewness:", round(skewness(train_data$log_delay), 2))
)
polygon(log_delay_density, col = "red")
par(old_par)
invisible(dev.off())

# shapiro.test() accepts at most 5,000 observations, so normality is
# tested on a reproducible 5,000-passenger random sample. At n = 5,000
# even minor departures yield p < 0.05, so skewness and density plots
# provide the practical guide.
set.seed(123)
shapiro_sample <- train_data[sample(1:nrow(train_data), 5000), ]

skew_table <- data.frame(
  variable = c("age", "arrival_delay", "log(1 + arrival_delay)"),
  skewness = round(c(
    skewness(train_data$age),
    skewness(train_data$arrival_delay),
    skewness(train_data$log_delay)
  ), 2),
  shapiro_p = signif(c(
    shapiro.test(shapiro_sample$age)$p.value,
    shapiro.test(shapiro_sample$arrival_delay)$p.value,
    shapiro.test(shapiro_sample$log_delay)$p.value
  ), 3)
)
skew_table
write.csv(skew_table, "output/tables/tbl_skewness.csv", row.names = FALSE)
# Takeaway: age is symmetrical (-0.01), while raw arrival_delay is heavily
# right-skewed (6.29). Logging reduces skewness to 0.86, so log_delay is
# carried forward into logistic regression.

# Check skewness across the six 1-to-5 service ratings as well.
rating_vars <- c(
  "online_boarding", "inflight_entertainment", "seat_comfort",
  "online_booking", "leg_room", "cleanliness"
)
rating_skew <- numeric(length(rating_vars))
names(rating_skew) <- rating_vars
for (v in rating_vars) {
  rating_skew[v] <- round(skewness(train_data[[v]]), 2)
}
rating_skew

# For categorical predictors, verify that every category has substantial
# counts in both outcome classes so no odds ratio rests on a sparse cell.
table(type_of_travel = train_data$type_of_travel, satisfaction = train_data$satisfaction)
table(class = train_data$class, satisfaction = train_data$satisfaction)
table(customer_type = train_data$customer_type, satisfaction = train_data$satisfaction)

cat_vars <- c("type_of_travel", "class", "customer_type")
cat_min_cell <- numeric(length(cat_vars))
names(cat_min_cell) <- cat_vars
for (v in cat_vars) {
  cat_min_cell[v] <- min(table(train_data[[v]], train_data$satisfaction))
}

# Save per-predictor pre-model checks so Script 03 can pair them with VIFs.
predictor_checks <- data.frame(
  variable = c(rating_vars, cat_vars, "arrival_delay", "age"),
  outliers_or_cells = c(
    rep("None (1-5 scale)", length(rating_vars)),
    paste0("Min cell: ", format(cat_min_cell, big.mark = ",", trim = TRUE)),
    paste0(
      format(outliers$n_outliers[2], big.mark = ",", trim = TRUE),
      " (", outliers$pct_of_data[2], "%)"
    ),
    paste0(outliers$n_outliers[1], " (0%)")
  ),
  skewness = c(
    as.character(rating_skew),
    rep("N/A", length(cat_vars)),
    paste0(skew_table$skewness[2], " -> ", skew_table$skewness[3]),
    as.character(skew_table$skewness[1])
  )
)
predictor_checks
write.csv(predictor_checks, "output/tables/tbl_predictor_checks.csv", row.names = FALSE)
# Takeaway: all six ratings sit within [-0.49, 0.12] and the smallest
# categorical outcome cell holds 1,464 passengers (Satisfied in Economy Plus).


# ------------------------------------------------------------
# 4. Check pairwise correlations among numeric and ordinal predictors
# ------------------------------------------------------------
cat("\n--- 4. Check pairwise Spearman correlations ---\n")

# Spearman rank correlation suits ordinal 1-to-5 ratings alongside
# skewed numeric variables. Correlations above 0.80 warn of redundancy.
numeric_predictors <- c(
  "online_boarding", "inflight_entertainment", "seat_comfort",
  "online_booking", "leg_room", "cleanliness", "age", "log_delay"
)

correlations <- round(cor(train_data[, numeric_predictors], method = "spearman"), 2)
correlations
write.csv(correlations, "output/tables/tbl_correlation.csv")

# Plot a 2,000-passenger subset so the scatterplot panels remain legible.
png("output/figures/fig_correlation.png", width = 10, height = 10, units = "in", res = 200)
pairs.panels(
  shapiro_sample[1:2000, numeric_predictors],
  method = "spearman",
  density = TRUE,
  ellipses = FALSE,
  lm = FALSE,
  hist.col = 4,
  stars = TRUE
)
invisible(dev.off())
# Takeaway: the strongest correlation is 0.68 (cleanliness with in-flight
# entertainment), comfortably below 0.80. Multicollinearity is checked
# again with Variance Inflation Factors in Script 03.


# ------------------------------------------------------------
# 5. Check linearity of each numeric/ordinal predictor with the logit
# ------------------------------------------------------------
cat("\n--- 5. Check linearity with empirical log-odds ---\n")

# Binary logistic regression assumes a straight-line relationship between
# each numeric predictor and the empirical log-odds log(p / (1 - p)),
# where p is the proportion satisfied in each bin.
logit_by_bin <- function(x, bins) {
  group <- cut(x, breaks = bins, include.lowest = TRUE)
  p <- tapply(train_data$satisfaction == "Satisfied", group, mean)
  data.frame(
    x = tapply(x, group, mean),
    logit = log(p / (1 - p))
  )
}

age_breaks <- unique(quantile(train_data$age, probs = seq(0, 1, 0.1)))
delay_breaks <- c(-0.1, 0.5, 1.5, 2, 2.5, 3, 3.5, 4, 5, 8)
rating_breaks <- c(0.5, 1.5, 2.5, 3.5, 4.5, 5.5)

age_bins <- logit_by_bin(train_data$age, age_breaks)
delay_bins <- logit_by_bin(train_data$log_delay, delay_breaks)

rating_titles <- c(
  online_boarding = "Online boarding",
  inflight_entertainment = "In-flight entertainment",
  seat_comfort = "Seat comfort",
  online_booking = "Online booking",
  leg_room = "Leg room",
  cleanliness = "Cleanliness"
)

png("output/figures/fig_logit.png", width = 13, height = 6.5, units = "in", res = 300)
old_par <- par(mfrow = c(2, 4), mar = c(4.2, 4.2, 2.8, 1))

plot(
  age_bins$x, age_bins$logit,
  main = "Age", xlab = "Age (bin mean)",
  ylab = "Log-odds of satisfied", pch = 19, col = "steelblue"
)
abline(lm(logit ~ x, data = age_bins), col = "red", lwd = 2)

plot(
  delay_bins$x, delay_bins$logit,
  main = "log(1 + arrival delay)", xlab = "log minutes (bin mean)",
  ylab = "Log-odds of satisfied", pch = 19, col = "steelblue"
)
abline(lm(logit ~ x, data = delay_bins), col = "red", lwd = 2)

# Plotting all six 1-to-5 ratings on a shared vertical scale makes the
# contrast between online boarding's sharp step and the gentler slopes clear.
for (v in names(rating_titles)) {
  bins_v <- logit_by_bin(train_data[[v]], rating_breaks)
  plot(
    bins_v$x, bins_v$logit,
    main = rating_titles[[v]], xlab = "Rating (1 to 5)",
    ylab = "Log-odds of satisfied", ylim = c(-2.2, 2.0), pch = 19, col = "steelblue"
  )
  abline(lm(logit ~ x, data = bins_v), col = "red", lwd = 2)
}
par(old_par)
invisible(dev.off())
cat("Saved 8-panel log-odds linearity plot: output/figures/fig_logit.png\n")
# Takeaways from the red straight-line fits:
# 1. Age follows an inverted U (rising into middle age, falling past 60),
#    so Script 03 enters age as a quadratic curve via poly(age, 2).
# 2. Online boarding stays flat from 1 to 3 and jumps nearly 4 log-odds
#    units across 4 and 5, so Script 03 enters it as a 5-level factor.
# 3. In-flight entertainment, cleanliness and leg room rise steadily across
#    1 to 5. Seat comfort and online booking show a much smaller step at 4-5
#    and stay linear to avoid adding 20 extra indicator terms.
# 4. log(1 + arrival_delay) drops early and flattens; linearity is only
#    partly met, and the single logged term is retained because delay is
#    among the weakest predictors.
