# ============================================================
# CA3 Predictive Modelling - Airline passenger satisfaction
# Script 04: Fit and validate the random forest classifier
# Author: Eamon Foy (L00204886)
# Report section: Building the predictive model; Model validation
# Reads:  output/train_data.rds, output/test_data.rds
# Writes: output/tables/tbl_rf_confusion.csv
#         output/tables/tbl_rf_importance.csv
#         output/figures/fig_rf_error.png
#         output/figures/fig_rf_importance.png
#         output/models/rf_results.rds
# ============================================================

source("scripts/ensure_packages.R")
library(randomForest)
library(caret) # confusionMatrix()

dir.create("output/models", recursive = TRUE, showWarnings = FALSE)

train_data <- readRDS("output/train_data.rds")
test_data <- readRDS("output/test_data.rds")

# Decision trees partition predictors on threshold rules and make no
# assumptions about linearity, skewness or outliers. The forest therefore
# takes the eleven predictors in their original untransformed form.


# ------------------------------------------------------------
# 1. Fit the random forest on the training set
# ------------------------------------------------------------
cat("\n--- 1. Fit random forest (201 trees, mtry = 3) ---\n")

# Parameter choices:
# - ntree = 201 builds an odd number of trees so majority votes cannot
#   tie, and out-of-bag error stabilises well before 201 trees.
# - mtry = 3 tests three randomly chosen predictors at each split,
#   matching the standard floor(sqrt(11)) classification rule.
# - importance = TRUE records permutation and Gini variable importance.
set.seed(123)
model_random_forest <- randomForest(
  satisfaction ~ online_boarding + inflight_entertainment + seat_comfort +
    online_booking + leg_room + cleanliness +
    type_of_travel + class + customer_type +
    arrival_delay + age,
  data = train_data,
  ntree = 201,
  mtry = 3,
  importance = TRUE
)

# Each tree trains on a bootstrap draw (~63% of training rows) and is
# evaluated on the ~37% out-of-bag (OOB) rows it never saw, providing
# an internal generalisation estimate before touching the test set.
print(model_random_forest)

png("output/figures/fig_rf_error.png", width = 8, height = 4.5, units = "in", res = 300)
plot(model_random_forest, main = "Random forest: error rate as trees are added")
legend(
  "topright",
  legend = c("Overall (OOB)", "Neutral or Dissatisfied", "Satisfied"),
  col = 1:3, lty = 1:3, cex = 0.8
)
invisible(dev.off())
# Takeaway: all three error curves flatten well before 201 trees, so
# adding further trees would raise run time without improving accuracy.


# ------------------------------------------------------------
# 2. Validate predictions on the held-out test set
# ------------------------------------------------------------
cat("\n--- 2. Validate random forest on the test set ---\n")

predictions <- predict(model_random_forest, newdata = test_data, type = "class")

results <- data.frame(
  Actual = test_data$satisfaction,
  Predicted = predictions
)
head(results, 10)

conf_matrix_rf <- confusionMatrix(
  predictions,
  test_data$satisfaction,
  positive = "Satisfied"
)
print(conf_matrix_rf)

rf_confusion_df <- as.data.frame(conf_matrix_rf$table)
write.csv(rf_confusion_df, "output/tables/tbl_rf_confusion.csv", row.names = FALSE)

# Use out-of-bag accuracy rather than resubstitution training accuracy
# when checking for overfitting in Script 05: scoring trees on the rows
# they grew on would look artificially close to 100%.
rf_oob_accuracy <- 1 - model_random_forest$err.rate[model_random_forest$ntree, "OOB"]


# ------------------------------------------------------------
# 3. Rank predictor importance
# ------------------------------------------------------------
cat("\n--- 3. Rank predictor importance (mean decrease in accuracy) ---\n")

# MeanDecreaseAccuracy measures how much OOB accuracy drops when a
# predictor's values are randomly permuted (scaled by its standard error);
# MeanDecreaseGini sums the impurity reductions across splits on that variable.
# Predictors are ranked by MeanDecreaseAccuracy because it directly reflects
# classification performance on unseen OOB rows.
rf_importance_raw <- importance(model_random_forest)

importance_rf <- data.frame(
  predictor = rownames(rf_importance_raw),
  mean_decrease_accuracy = round(rf_importance_raw[, "MeanDecreaseAccuracy"], 1),
  mean_decrease_gini = round(rf_importance_raw[, "MeanDecreaseGini"], 0)
)
importance_rf <- importance_rf[order(-importance_rf$mean_decrease_accuracy), ]
rownames(importance_rf) <- NULL
importance_rf
write.csv(importance_rf, "output/tables/tbl_rf_importance.csv", row.names = FALSE)

# Reverse the vector order because horizontal barplot() draws from bottom
# to top, placing the most important predictor at the top of the chart.
png("output/figures/fig_rf_importance.png", width = 8, height = 5, units = "in", res = 300)
old_par <- par(mar = c(5, 12, 4, 2))
barplot(
  rev(importance_rf$mean_decrease_accuracy),
  names.arg = rev(importance_rf$predictor),
  horiz = TRUE, las = 1,
  main = "Random forest: variable importance",
  xlab = "Mean decrease in accuracy",
  col = "lightblue"
)
par(old_par)
invisible(dev.off())

saveRDS(
  list(
    model = model_random_forest,
    conf_matrix = conf_matrix_rf,
    oob_accuracy = rf_oob_accuracy
  ),
  "output/models/rf_results.rds"
)
