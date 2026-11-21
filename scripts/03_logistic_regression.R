# ============================================================
# CA3 Predictive Modelling - Airline passenger satisfaction
# Script 03: Fit, check and validate the logistic regression models
# Author: Eamon Foy (L00204886)
# Report section: Building the predictive model; Model validation
# Reads:  output/train_data.rds, output/test_data.rds
#         output/tables/tbl_correlation.csv
#         output/tables/tbl_predictor_checks.csv
# Writes: output/tables/tbl_lr_models.csv
#         output/tables/tbl_vif.csv
#         output/tables/tbl_assumptions.csv
#         output/tables/tbl_variable_assumptions.csv
#         output/tables/tbl_odds_ratios.csv
#         output/tables/tbl_lr_fit.csv
#         output/tables/tbl_lr_confusion.csv
#         output/figures/fig_cooks.png
#         output/models/lr_results.rds
# ============================================================

source("scripts/ensure_packages.R")
library(caret) # confusionMatrix()
library(car) # vif()

dir.create("output/models", recursive = TRUE, showWarnings = FALSE)

train_data <- readRDS("output/train_data.rds")
test_data <- readRDS("output/test_data.rds")

# Apply the log(1 + arrival_delay) transform selected in Script 02 to both sets.
train_data$log_delay <- log(1 + train_data$arrival_delay)
test_data$log_delay <- log(1 + test_data$arrival_delay)


# ------------------------------------------------------------
# 1. Fit model_1: baseline specification with untransformed predictors
# ------------------------------------------------------------
cat("\n--- 1. Fit model_1: baseline logistic regression ---\n")

# family = binomial fits binary logistic regression for P(Satisfied).
model_1 <- glm(
  satisfaction ~ online_boarding + inflight_entertainment + seat_comfort +
    online_booking + leg_room + cleanliness +
    type_of_travel + class + customer_type +
    arrival_delay + age,
  data = train_data,
  family = binomial
)
summary(model_1)


# ------------------------------------------------------------
# 2. Fit model_2: incorporate remedies from the assumption checks
# ------------------------------------------------------------
cat("\n--- 2. Fit model_2: with log delay, curved age and categorical boarding ---\n")

# Three adjustments address the diagnostics in Script 02:
# 1. log_delay replaces raw arrival_delay to tame right skewness.
# 2. poly(age, 2) fits linear and quadratic age terms as orthogonal
#    columns, avoiding the severe collinearity of raw age + age^2.
# 3. factor(online_boarding) estimates a separate effect at each score
#    from 2 to 5 (versus 1) to capture the threshold jump at 4 and 5.
model_2 <- glm(
  satisfaction ~ factor(online_boarding) + inflight_entertainment + seat_comfort +
    online_booking + leg_room + cleanliness +
    type_of_travel + class + customer_type +
    log_delay + poly(age, 2),
  data = train_data,
  family = binomial
)
summary(model_2)


# ------------------------------------------------------------
# 3. Fit model_3: test whether dropping the weakest predictor helps
# ------------------------------------------------------------
cat("\n--- 3. Fit model_3: single-term deletion test on model_2 ---\n")

# drop1(..., test = "Chisq") removes one predictor at a time and runs a
# likelihood-ratio test. Row 1 of drop_test is the full model (<none>),
# and each remaining row gives the AIC after dropping that predictor.
drop_test <- drop1(model_2, test = "Chisq")
drop_test

# Every predictor has p < 0.001, so all rows sit above the full-model AIC.
# Removing the predictor with the smallest AIC penalty tests whether a
# simpler model achieves a better BIC.
predictor_drops <- drop_test[-1, ]
weakest <- rownames(predictor_drops)[which.min(predictor_drops$AIC)]
cat("Weakest predictor:", weakest, "\n\n")

drop_formula <- as.formula(paste(". ~ . -", weakest))
model_3 <- update(model_2, drop_formula)
summary(model_3)


# ------------------------------------------------------------
# 4. Compare the three specifications with AIC and BIC
# ------------------------------------------------------------
cat("\n--- 4. Compare model_1, model_2 and model_3 (AIC and BIC) ---\n")

# Lower AIC and BIC indicate better fit relative to complexity; BIC
# penalises extra parameters more heavily in large samples.
model_comparison <- data.frame(
  model = c("model_1", "model_2", "model_3"),
  description = c(
    "All predictors as they are",
    "model_1 + log delay, age squared, boarding as a category",
    paste("model_2 without", weakest)
  ),
  n_terms = c(length(coef(model_1)), length(coef(model_2)), length(coef(model_3))),
  AIC = round(c(AIC(model_1), AIC(model_2), AIC(model_3)), 0),
  BIC = round(c(BIC(model_1), BIC(model_2), BIC(model_3)), 0)
)
model_comparison
write.csv(model_comparison, "output/tables/tbl_lr_models.csv", row.names = FALSE)

# Takeaway: model_2 cuts AIC by 4,833 over model_1, and dropping
# cleanliness in model_3 worsens both AIC and BIC. Retain model_2.
final_model <- model_2


# ------------------------------------------------------------
# 5. Run post-estimation assumption checks on the final model
# ------------------------------------------------------------
cat("\n--- 5a. Post-estimation check: Variance Inflation Factors (VIF) ---\n")

# Multi-degree-of-freedom terms (factor(online_boarding), class, poly(age, 2))
# produce Generalised VIFs (GVIF). Squaring GVIF^(1/(2*Df)) places every
# predictor on the standard single-term VIF scale (concern above 5, severe above 10).
vif_values <- vif(final_model)
vif_values

vif_table <- data.frame(
  predictor = rownames(vif_values),
  vif = round(vif_values[, "GVIF^(1/(2*Df))"]^2, 2),
  row.names = NULL
)
vif_table
write.csv(vif_table, "output/tables/tbl_vif.csv", row.names = FALSE)
# Takeaway: every predictor sits below 2.0 (highest is cleanliness at 1.97).

cat("\n--- 5b. Post-estimation check: Cook's distance ---\n")

# A Cook's distance above 1 indicates an observation that shifts the
# fitted coefficients substantially on its own. The dashed line marks
# 4/n (about 0.00005 at n = 86,626), a strict textbook reference screen.
cooks <- cooks.distance(final_model)
cat("Largest Cook's distance:", signif(max(cooks), 3), "\n")

png("output/figures/fig_cooks.png", width = 8, height = 4.5, units = "in", res = 300)
plot(
  cooks,
  pch = 20, col = "steelblue",
  main = "Cook's distance for each training passenger",
  xlab = "Passenger", ylab = "Cook's distance"
)
abline(h = 4 / nrow(train_data), col = "red", lty = 2)
invisible(dev.off())
# Takeaway: the largest Cook's distance is 0.00056, well below 1.

cat("\n--- 5c. Assumption summary tables (model-wide and per-predictor) ---\n")

# Standard guidance asks for at least 10 observations in the rarer
# outcome class per non-intercept parameter.
n_events <- min(table(train_data$satisfaction))
n_terms <- length(coef(final_model)) - 1
events_per_term <- n_events / n_terms

# Export the model-wide assumption summary and the 11-row per-predictor
# assumption check table used in Section 3.3 of the report.
# Note on linear-regression checks omitted here: binary outcomes cannot
# yield normal or homoscedastic residuals, and survey rows have no time
# ordering for a Durbin-Watson autocorrelation test.
corr_mat <- as.matrix(read.csv("output/tables/tbl_correlation.csv", row.names = 1))
diag(corr_mat) <- 0
pct_satisfied <- round(100 * mean(train_data$satisfaction == "Satisfied"), 1)

assumptions <- data.frame(
  assumption = c(
    "Binary outcome",
    "Independent observations",
    "Enough data (events per term)",
    "No multicollinearity",
    "No influential outliers"
  ),
  evidence = c(
    paste0("2 levels; ", pct_satisfied, "% satisfied"),
    "One survey per passenger; data has no flight ID to group by",
    paste0(format(round(events_per_term), big.mark = ",", trim = TRUE), " events per term (need at least 10)"),
    paste0("Largest Spearman r = ", max(corr_mat), "; largest VIF = ", max(vif_table$vif), " (concern above 5)"),
    paste0("Largest Cook's distance = ", signif(max(cooks), 2), " (concern above 1)")
  ),
  verdict = c("Met", "Met (with caveat)", "Met", "Met", "Met")
)
assumptions
write.csv(assumptions, "output/tables/tbl_assumptions.csv", row.names = FALSE)

pred_checks <- read.csv("output/tables/tbl_predictor_checks.csv")
vif_terms <- c(
  "factor(online_boarding)", "inflight_entertainment", "seat_comfort",
  "online_booking", "leg_room", "cleanliness",
  "type_of_travel", "class", "customer_type",
  "log_delay", "poly(age, 2)"
)

variable_assumptions <- data.frame(
  predictor = c(
    "Online boarding", "In-flight entertainment", "Seat comfort",
    "Online booking", "Leg room", "Cleanliness",
    "Type of travel", "Cabin class", "Customer type",
    "Arrival delay", "Age"
  ),
  type = c(rep("Ordinal (1-5)", 6), rep("Categorical", 3), rep("Continuous", 2)),
  outliers_or_cells = pred_checks$outliers_or_cells,
  skewness = pred_checks$skewness,
  logit_linearity = c(
    "Violated (jump at 4-5)",
    "Met",
    "Partly met (step at 4)",
    "Partly met (step at 4-5)",
    "Met",
    "Met",
    rep("N/A (categorical)", 3),
    "Partly met after log",
    "Violated (curved)"
  ),
  vif = vif_table$vif[match(vif_terms, vif_table$predictor)],
  verdict = c(
    "Met: category factor(online_boarding)",
    "Met: kept as 1-5 slope",
    "Partly met: kept linear for parsimony",
    "Partly met: kept linear for parsimony",
    "Met: kept as 1-5 slope",
    "Met: kept as 1-5 slope",
    "Met: binary indicator",
    "Met: 2 category indicators",
    "Met: binary indicator",
    "Partly met: log(1 + delay)",
    "Met: curve poly(age, 2)"
  )
)
variable_assumptions
write.csv(variable_assumptions, "output/tables/tbl_variable_assumptions.csv", row.names = FALSE)


# ------------------------------------------------------------
# 6. Extract odds ratios and overall fit statistics
# ------------------------------------------------------------
cat("\n--- 6. Extract odds ratios and McFadden fit summary ---\n")

# Exponentiating log-odds coefficients and Wald 95% confidence limits
# converts effects into odds ratios, holding all other predictors fixed.
# Values above 1 raise the odds of satisfaction; values below 1 lower them.
# The two orthogonal poly(age, 2) basis terms shape the age curve jointly
# and are not interpreted individually as unit-change odds ratios.
coef_estimates <- coef(final_model)
ci_log_odds <- confint.default(final_model)
coef_p_values <- summary(final_model)$coefficients[, "Pr(>|z|)"]

odds_ratios <- data.frame(
  term = names(coef_estimates),
  odds_ratio = round(exp(coef_estimates), 3),
  lower_95 = round(exp(ci_log_odds[, 1]), 3),
  upper_95 = round(exp(ci_log_odds[, 2]), 3),
  p_value = ifelse(coef_p_values < 0.001, "< 0.001", round(coef_p_values, 3)),
  row.names = NULL
)
odds_ratios
write.csv(odds_ratios, "output/tables/tbl_odds_ratios.csv", row.names = FALSE)

# McFadden's pseudo R-squared compares residual deviance with the
# intercept-only null model; values from 0.2 to 0.4 already mark a strong fit.
mcfadden <- 1 - final_model$deviance / final_model$null.deviance

lr_fit <- data.frame(
  mcfadden_r2 = round(mcfadden, 2),
  events = n_events,
  terms = n_terms,
  events_per_term = round(events_per_term)
)
lr_fit
write.csv(lr_fit, "output/tables/tbl_lr_fit.csv", row.names = FALSE)


# ------------------------------------------------------------
# 7. Validate predictions on the held-out test set
# ------------------------------------------------------------
cat("\n--- 7. Validate final logistic regression on the test set ---\n")

# type = "response" returns predicted probabilities P(Satisfied) in [0, 1],
# classified with the standard 0.50 probability threshold.
predicted_prob <- predict(final_model, newdata = test_data, type = "response")
predicted_class <- factor(
  ifelse(predicted_prob >= 0.5, "Satisfied", "Neutral or Dissatisfied"),
  levels = levels(test_data$satisfaction)
)

results <- data.frame(
  Actual = test_data$satisfaction,
  Predicted = predicted_class,
  Probability = round(predicted_prob, 3)
)
head(results, 10)

conf_matrix_lr <- confusionMatrix(
  predicted_class,
  test_data$satisfaction,
  positive = "Satisfied"
)
print(conf_matrix_lr)

lr_confusion_df <- as.data.frame(conf_matrix_lr$table)
write.csv(lr_confusion_df, "output/tables/tbl_lr_confusion.csv", row.names = FALSE)

# Record in-sample training accuracy so Script 05 can check for overfitting.
train_prob <- predict(final_model, type = "response")
train_class <- ifelse(train_prob >= 0.5, "Satisfied", "Neutral or Dissatisfied")
lr_train_accuracy <- mean(train_class == train_data$satisfaction)

saveRDS(
  list(
    model = final_model,
    conf_matrix = conf_matrix_lr,
    train_accuracy = lr_train_accuracy,
    mcfadden = mcfadden
  ),
  "output/models/lr_results.rds"
)
