# ============================================================
# CA3 Predictive Modelling - Airline passenger satisfaction
# Script 01: Prepare the data and split into training and test sets
# Author: Eamon Foy (L00204886)
# Report section: Research question; Building the predictive model
# Reads:  data/airline_passenger_satisfaction.csv
# Writes: output/tables/tbl_delay_correlation.csv
#         output/tables/tbl_wifi_check.csv
#         output/tables/tbl_cleaning.csv
#         output/tables/tbl_split.csv
#         output/train_data.rds, output/test_data.rds
# ============================================================

source("scripts/ensure_packages.R")
library(caret)

dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)


# ------------------------------------------------------------
# 1. Import and inspect the survey dataset
# ------------------------------------------------------------
cat("\n--- 1. Import and inspect the survey dataset ---\n")

airline <- read.csv("data/airline_passenger_satisfaction.csv")

dim(airline)
str(airline)
summary(airline)


# ------------------------------------------------------------
# 2. Give columns short lower-case names
# ------------------------------------------------------------
cat("\n--- 2. Give columns short lower-case names ---\n")

# read.csv() replaces spaces and hyphens in CSV headers with dots
# (for example, "Customer.Type"). Short snake_case names make the
# model formulas and tables easier to read across scripts.
colnames(airline) <- c(
  "id", "gender", "age", "customer_type", "type_of_travel", "class",
  "flight_distance", "departure_delay", "arrival_delay",
  "time_convenience", "online_booking", "checkin_service",
  "online_boarding", "gate_location", "onboard_service",
  "seat_comfort", "leg_room", "cleanliness", "food_and_drink",
  "inflight_service", "wifi", "inflight_entertainment",
  "baggage_handling", "satisfaction"
)
colnames(airline)


# ------------------------------------------------------------
# 3. Check for missing values
# ------------------------------------------------------------
cat("\n--- 3. Check for missing values ---\n")

colSums(is.na(airline))
# Takeaway: only arrival_delay has recorded NAs (393 passengers).
# Service ratings also use 0 to mean "not applicable", handled in Section 6.


# ------------------------------------------------------------
# 4. Justify the two predictors excluded before modelling
# ------------------------------------------------------------
cat("\n--- 4a. Excluded predictor check: departure vs arrival delay ---\n")

# Departure and arrival delay move almost one-for-one (r = 0.965).
# Keeping both would duplicate delay information and inflate variance,
# so only arrival delay (the delay experienced at destination) is kept.
delay_correlation <- cor(
  airline$departure_delay,
  airline$arrival_delay,
  use = "complete.obs"
)
delay_cor_table <- data.frame(correlation = round(delay_correlation, 3))
delay_cor_table
write.csv(delay_cor_table, "output/tables/tbl_delay_correlation.csv", row.names = FALSE)

cat("\n--- 4b. Excluded predictor check: satisfaction by Wi-Fi score ---\n")

# Satisfaction by Wi-Fi score does not behave like a normal service
# rating: passengers who scored Wi-Fi 5 (99.0%) or 0 ("not applicable",
# 99.7%) were nearly all satisfied, while score 1 (32.8%) beat scores
# 2 and 3 (around 25%). Including an apparent survey artefact like this
# would inflate accuracy without giving the airline usable guidance.
wifi_props <- prop.table(table(airline$wifi, airline$satisfaction), margin = 1)
wifi_check <- data.frame(
  wifi_rating = rownames(wifi_props),
  pct_satisfied = round(100 * wifi_props[, "Satisfied"], 1),
  row.names = NULL
)
wifi_check
write.csv(wifi_check, "output/tables/tbl_wifi_check.csv", row.names = FALSE)


# ------------------------------------------------------------
# 5. Select the outcome and the eleven predictors
# ------------------------------------------------------------
cat("\n--- 5. Select the outcome and the eleven predictors ---\n")

# Retain the binary target alongside six service ratings, three
# passenger/trip characteristics, arrival delay and age. These were
# the clearest satisfaction drivers identified in CA2.
model_variables <- c(
  "satisfaction",
  "online_boarding", "inflight_entertainment", "seat_comfort",
  "online_booking", "leg_room", "cleanliness",
  "type_of_travel", "class", "customer_type",
  "arrival_delay", "age"
)
airline_model <- airline[, model_variables]
rows_start <- nrow(airline_model)
colnames(airline_model)


# ------------------------------------------------------------
# 6. Remove "not applicable" ratings and missing arrival delays
# ------------------------------------------------------------
cat("\n--- 6. Remove 'not applicable' ratings (0) and missing delays ---\n")

# On the survey's 1-to-5 scales, 0 marks "not applicable" rather than
# poor service. Leaving 0 in numeric columns would pull slopes and
# medians downward, so 0 is recoded to NA before dropping incomplete rows.
rating_variables <- c(
  "online_boarding", "inflight_entertainment",
  "seat_comfort", "online_booking",
  "leg_room", "cleanliness"
)

for (v in rating_variables) {
  airline_model[[v]][airline_model[[v]] == 0] <- NA
}
colSums(is.na(airline_model))

airline_model <- na.omit(airline_model)
rows_end <- nrow(airline_model)
rows_removed <- rows_start - rows_end

cleaning <- data.frame(
  step = c(
    "Passengers in the survey",
    "Removed: a rating of 0 (not applicable) or a missing arrival delay",
    "Passengers used for modelling"
  ),
  passengers = c(rows_start, rows_removed, rows_end),
  percent = round(100 * c(1, rows_removed / rows_start, rows_end / rows_start), 1)
)
cleaning
write.csv(cleaning, "output/tables/tbl_cleaning.csv", row.names = FALSE)
# Takeaway: 95.3% of survey responses remain (123,750 passengers), so
# complete-case filtering loses very little data.


# ------------------------------------------------------------
# 7. Set factor levels and reference categories
# ------------------------------------------------------------
cat("\n--- 7. Set factor levels and reference categories ---\n")

# In glm(..., family = binomial), the first level of the outcome is 0
# and the second level ("Satisfied") is the predicted event (1).
# For each categorical predictor, the first level sets the baseline
# against which odds ratios are compared (Personal, Economy, First-time).
airline_model$satisfaction <- factor(
  airline_model$satisfaction,
  levels = c("Neutral or Dissatisfied", "Satisfied")
)
airline_model$type_of_travel <- factor(
  airline_model$type_of_travel,
  levels = c("Personal", "Business")
)
airline_model$class <- factor(
  airline_model$class,
  levels = c("Economy", "Economy Plus", "Business")
)
airline_model$customer_type <- factor(
  airline_model$customer_type,
  levels = c("First-time", "Returning")
)
str(airline_model)
table(satisfaction = airline_model$satisfaction)


# ------------------------------------------------------------
# 8. Split into training (70%) and test (30%) sets
# ------------------------------------------------------------
cat("\n--- 8. Split into training (70%) and test (30%) sets ---\n")

# A fixed seed keeps the random split reproducible across runs.
# createDataPartition() stratifies on satisfaction so both sets hold
# the same 42.4% share of satisfied passengers. All assumption checks
# and model fitting use train_data; test_data is held back for validation.
set.seed(123)
train_index <- createDataPartition(airline_model$satisfaction, p = 0.70, list = FALSE)

train_data <- airline_model[train_index, ]
test_data <- airline_model[-train_index, ]

split_table <- data.frame(
  data_set = c("Training", "Test"),
  passengers = c(nrow(train_data), nrow(test_data)),
  pct_satisfied = round(100 * c(
    mean(train_data$satisfaction == "Satisfied"),
    mean(test_data$satisfaction == "Satisfied")
  ), 1)
)
split_table
write.csv(split_table, "output/tables/tbl_split.csv", row.names = FALSE)

saveRDS(train_data, "output/train_data.rds")
saveRDS(test_data, "output/test_data.rds")
