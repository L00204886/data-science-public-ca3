# ============================================================
# CA3 Predictive Modelling - Airline passenger satisfaction
# Script 05: Compare model performance and forecast devised cases
# Author: Eamon Foy (L00204886)
# Report section: Model validation; Model forecasting
# Reads:  output/train_data.rds, output/test_data.rds
#         output/models/lr_results.rds, output/models/rf_results.rds
# Writes: output/tables/tbl_comparison.csv
#         output/tables/tbl_mcnemar.csv
#         output/tables/tbl_forecasts.csv
#         output/figures/fig_comparison.png
#         output/figures/fig_forecasts.png
# ============================================================

source("scripts/ensure_packages.R")
library(randomForest)
library(caret)

train_data <- readRDS("output/train_data.rds")
test_data <- readRDS("output/test_data.rds")
lr <- readRDS("output/models/lr_results.rds")
rf <- readRDS("output/models/rf_results.rds")


# ------------------------------------------------------------
# 1. Compare accuracy, class metrics and paired errors on test data
# ------------------------------------------------------------
cat("\n--- 1. Compare model performance and run McNemar's test ---\n")

# Extract overall test accuracy alongside class-specific metrics where
# "Satisfied" is the positive class: sensitivity (share of satisfied
# flyers found), specificity (share of dissatisfied flyers found) and
# precision (share of "Satisfied" predictions that are right).
# Comparing training/OOB accuracy against test accuracy checks overfitting.
lr_overall <- lr$conf_matrix$overall
rf_overall <- rf$conf_matrix$overall
lr_by_class <- lr$conf_matrix$byClass
rf_by_class <- rf$conf_matrix$byClass

comparison <- data.frame(
  model = c("Logistic regression", "Random forest"),
  training_accuracy = round(100 * c(lr$train_accuracy, rf$oob_accuracy), 1),
  test_accuracy = round(100 * c(lr_overall["Accuracy"], rf_overall["Accuracy"]), 1),
  sensitivity = round(100 * c(lr_by_class["Sensitivity"], rf_by_class["Sensitivity"]), 1),
  specificity = round(100 * c(lr_by_class["Specificity"], rf_by_class["Specificity"]), 1),
  precision = round(100 * c(lr_by_class["Pos Pred Value"], rf_by_class["Pos Pred Value"]), 1),
  row.names = NULL
)
comparison
write.csv(comparison, "output/tables/tbl_comparison.csv", row.names = FALSE)

# No-information baseline: accuracy achieved by predicting the majority
# class ("Neutral or Dissatisfied") for every test passenger.
baseline_accuracy <- round(100 * mean(test_data$satisfaction == "Neutral or Dissatisfied"), 1)

# Because both models are scored on the exact same 37,124 test passengers,
# McNemar's test evaluates paired disagreements (one model right, the other
# wrong) under H0 that both models make equal numbers of unique errors.
test_data_lr <- test_data
test_data_lr$log_delay <- log(1 + test_data$arrival_delay)

lr_prob <- predict(lr$model, newdata = test_data_lr, type = "response")
lr_pred_label <- ifelse(lr_prob >= 0.5, "Satisfied", "Neutral or Dissatisfied")
lr_correct <- lr_pred_label == test_data$satisfaction
rf_correct <- predict(rf$model, newdata = test_data) == test_data$satisfaction

table(LR_correct = lr_correct, RF_correct = rf_correct)
mcnemar_result <- mcnemar.test(table(lr_correct, rf_correct))
mcnemar_result

mcnemar_p_text <- ifelse(
  mcnemar_result$p.value < 0.001,
  "< 0.001",
  round(mcnemar_result$p.value, 3)
)

mcnemar_summary <- data.frame(
  baseline_accuracy = baseline_accuracy,
  both_right = sum(lr_correct & rf_correct),
  both_wrong = sum(!lr_correct & !rf_correct),
  lr_right_rf_wrong = sum(lr_correct & !rf_correct),
  rf_right_lr_wrong = sum(rf_correct & !lr_correct),
  mcnemar_chi_squared = round(unname(mcnemar_result$statistic), 1),
  mcnemar_p = mcnemar_p_text
)
mcnemar_summary
write.csv(mcnemar_summary, "output/tables/tbl_mcnemar.csv", row.names = FALSE)
# Takeaway: on the 2,614 passengers where the two models disagree, the
# random forest is right 2,039 times versus 575 for logistic regression
# (p < 0.001), confirming a genuine 4.0 percentage-point accuracy gain.

png("output/figures/fig_comparison.png", width = 8, height = 4.5, units = "in", res = 300)
barplot(
  t(as.matrix(comparison[, c("test_accuracy", "sensitivity", "specificity", "precision")])),
  beside = TRUE,
  names.arg = comparison$model,
  col = c("steelblue", "lightblue", "orange", "grey"),
  ylim = c(0, 100),
  ylab = "Percent",
  main = "Test-data performance of the two models",
  legend.text = c("Accuracy", "Sensitivity", "Specificity", "Precision"),
  args.legend = list(x = "bottomright", cex = 0.8)
)
abline(h = baseline_accuracy, lty = 2)
invisible(dev.off())


# ------------------------------------------------------------
# 2. Devise nine passenger profiles for scenario forecasting
# ------------------------------------------------------------
cat("\n--- 2. Devise nine passenger profiles (baseline profile shown below) ---\n")

# Anchor all scenarios on a single baseline profile built from training
# medians and modal categories. Matching train_data's factor levels ensures
# predict() aligns dummy columns identically in both models.
most_common <- function(x) {
  names(which.max(table(x)))
}

rating_variables <- c(
  "online_boarding", "inflight_entertainment", "seat_comfort",
  "online_booking", "leg_room", "cleanliness"
)

typical <- data.frame(
  online_boarding = median(train_data$online_boarding),
  inflight_entertainment = median(train_data$inflight_entertainment),
  seat_comfort = median(train_data$seat_comfort),
  online_booking = median(train_data$online_booking),
  leg_room = median(train_data$leg_room),
  cleanliness = median(train_data$cleanliness),
  type_of_travel = factor(
    most_common(train_data$type_of_travel),
    levels = levels(train_data$type_of_travel)
  ),
  class = factor(
    most_common(train_data$class),
    levels = levels(train_data$class)
  ),
  customer_type = factor(
    most_common(train_data$customer_type),
    levels = levels(train_data$customer_type)
  ),
  arrival_delay = median(train_data$arrival_delay),
  age = median(train_data$age)
)
typical

# Vary one or two inputs at a time from the typical passenger so any shift
# in predicted probability is attributable to that specific change.
case_1 <- typical

# Poor versus top-rated online boarding
case_2 <- typical
case_2$online_boarding <- 2

case_3 <- typical
case_3$online_boarding <- 5

# Same business traveller seated in Economy
case_4 <- typical
case_4$class <- "Economy"

# Leisure trip in Economy with otherwise typical service ratings
case_5 <- typical
case_5$type_of_travel <- "Personal"
case_5$class <- "Economy"

# Two-hour arrival delay on an otherwise well-rated business flight
case_6 <- typical
case_6$arrival_delay <- 120

# First-time flyer with the airline on an otherwise typical business trip
case_7 <- typical
case_7$customer_type <- "First-time"

# Upper extreme: all six service ratings at 5
case_8 <- typical
case_8[, rating_variables] <- 5

# Lower extreme: leisure passenger in Economy with all six ratings at 2
case_9 <- typical
case_9[, rating_variables] <- 2
case_9$type_of_travel <- "Personal"
case_9$class <- "Economy"

new_passengers <- rbind(
  case_1, case_2, case_3, case_4, case_5,
  case_6, case_7, case_8, case_9
)

case_labels <- c(
  "1. Typical passenger",
  "2. Online boarding = 2",
  "3. Online boarding = 5",
  "4. Economy class",
  "5. Leisure trip in Economy",
  "6. Arrival delay 120 min",
  "7. First-time customer",
  "8. Ideal: all ratings 5",
  "9. At risk: all ratings 2, leisure, Economy"
)


# ------------------------------------------------------------
# 3. Generate satisfaction probability forecasts from both models
# ------------------------------------------------------------
cat("\n--- 3. Generate satisfaction probability forecasts ---\n")

# Logistic regression reads log_delay; randomForest uses its model formula
# and reads raw arrival_delay while ignoring extra columns.
new_passengers$log_delay <- log(1 + new_passengers$arrival_delay)

lr_forecast <- predict(lr$model, newdata = new_passengers, type = "response")
rf_prob_matrix <- predict(rf$model, newdata = new_passengers, type = "prob")
rf_forecast <- rf_prob_matrix[, "Satisfied"]
cat("Forecast probabilities computed for", nrow(new_passengers), "devised profiles.\n")


# ------------------------------------------------------------
# 4. Benchmark forecasts against similar real test passengers
# ------------------------------------------------------------
cat("\n--- 4. Benchmark forecasts against similar real test passengers ---\n")

# Match each devised profile to held-out test passengers with the same
# travel purpose, cabin class, customer type and online boarding score,
# plus a mean service rating within 0.5 points. Case 6 also requires an
# arrival delay of at least 60 minutes so the delayed scenario is checked
# against genuinely delayed flyers. Require at least 30 matches to report
# an observed satisfaction rate.
test_mean_rating <- rowMeans(test_data[, rating_variables])

observed <- numeric(nrow(new_passengers))
matches <- numeric(nrow(new_passengers))

for (i in seq_len(nrow(new_passengers))) {
  case_mean_rating <- mean(as.numeric(new_passengers[i, rating_variables]))

  similar <- test_data$type_of_travel == new_passengers$type_of_travel[i] &
    test_data$class == new_passengers$class[i] &
    test_data$customer_type == new_passengers$customer_type[i] &
    test_data$online_boarding == new_passengers$online_boarding[i] &
    abs(test_mean_rating - case_mean_rating) <= 0.5

  if (i == 6) {
    similar <- similar & test_data$arrival_delay >= 60
  }

  matches[i] <- sum(similar)
  observed[i] <- ifelse(
    matches[i] >= 30,
    round(100 * mean(test_data$satisfaction[similar] == "Satisfied"), 1),
    NA
  )
}

forecasts <- data.frame(
  case = case_labels,
  logistic_regression = round(100 * lr_forecast, 1),
  random_forest = round(100 * rf_forecast, 1),
  similar_passengers = matches,
  observed_pct_satisfied = observed
)
forecasts
write.csv(forecasts, "output/tables/tbl_forecasts.csv", row.names = FALSE)
# Takeaway: both models agree at the extremes, whereas on intermediate
# profiles (Cases 2 and 7) the random forest produces overconfident
# probabilities far from the empirical test rate while logistic regression
# stays close to observed passenger behaviour.

# Reverse row order so Case 1 appears at the top of the horizontal chart;
# the dashed vertical line marks the 50% classification threshold.
png("output/figures/fig_forecasts.png", width = 9, height = 5.5, units = "in", res = 300)
old_par <- par(mar = c(5, 17, 4, 2))
barplot(
  t(as.matrix(forecasts[nrow(forecasts):1, c("logistic_regression", "random_forest")])),
  beside = TRUE, horiz = TRUE, las = 1,
  names.arg = rev(forecasts$case),
  col = c("steelblue", "orange"),
  xlim = c(0, 100),
  xlab = "Predicted chance of being satisfied (%)",
  main = "Forecasts for the devised passengers",
  legend.text = c("Logistic regression", "Random forest"),
  args.legend = list(x = "bottomright", cex = 0.8)
)
abline(v = 50, lty = 2)
par(old_par)
invisible(dev.off())
