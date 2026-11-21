CA3: Predicting Airline Passenger Satisfaction

**Module:** DATA_IT904 - Data Science (2026/27).
**Assessment:** CA 3 - Predictive Modelling.
**Author:** Eamon Foy (L00204886).

## Research question

Which service ratings and passenger characteristics best predict whether an airline passenger is satisfied, and does a random forest predict satisfaction more accurately than logistic regression?

Data: the Kaggle *Airline Passenger Satisfaction* survey (Bhat, 2022), 129,880 passengers.

---

## 1. Prerequisites (Windows and macOS)

You need **R (4.1 or newer)** and the packages listed below.

### Install R

- **Windows:**
  1. Download and run the installer from CRAN: https://cran.r-project.org/bin/windows/base/ (or run `winget install RProject.R` in PowerShell).
  2. To use `Rscript` from Command Prompt or PowerShell, add your R `bin` folder (for example, `C:\Program Files\R\R-4.4.2\bin`) to your `PATH`, or run the commands below inside **RGui** / **RStudio**.
- **macOS:**
  1. Download and install the `.pkg` for your Mac (Apple Silicon `arm64` or Intel `x86_64`) from CRAN: https://cran.r-project.org/bin/macosx/ (or run `brew install --cask r` with Homebrew).
  2. For `make`, macOS includes it with Xcode Command Line Tools (`xcode-select --install` if not already installed).

### Install required R packages

Open **R** (or **RStudio**) and run:

```r
install.packages(
  c("caret", "randomForest", "car", "e1071", "psych", "knitr", "rmarkdown"),
  repos = "https://cloud.r-project.org"
)
```

Or from a terminal (macOS / Windows with `Rscript` on `PATH`):

```bash
Rscript -e 'install.packages(c("caret", "randomForest", "car", "e1071", "psych", "knitr", "rmarkdown"), repos = "https://cloud.r-project.org")'
```

---

## 2. How to run

Run all commands from the **project root folder** (takes about 1 minute).

### Option A: Using the Makefile

```bash
make run
```

*(Note: on Windows without `make` installed, use Option B below.)*

### Option B: Using R

From a terminal (`macOS` Terminal or `Windows` PowerShell / Command Prompt):

```bash
Rscript scripts/run_all.R
```

Or inside an interactive **R** / **RStudio** session (with the working directory set to the project root):

```r
source("scripts/run_all.R")
```

You can also run the stages one at a time in order (`01` through `05`), for example `Rscript scripts/01_data_preparation.R`.

**To check the results without running anything**, open `output/run_log.txt`, which records the output of every section from the last run.

---

## 3. Files in `data/`, `scripts/`, and `output/`

### `data/`

| File                                   | Purpose                                                              |
| :------------------------------------- | :------------------------------------------------------------------- |
| `airline_passenger_satisfaction.csv` | Raw Kaggle passenger satisfaction survey (129,880 rows, 24 columns). |
| `data_dictionary.csv`                | Column definitions and value scales for the raw survey.              |
| `url.md`                             | Link to the original Kaggle dataset page.                            |

### `scripts/`

| File                          | Purpose                                                                                                                                                                                                                        |
| :---------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `01_data_preparation.R`     | Imports and renames raw columns, checks excluded variables (departure delay and Wi-Fi), removes `0` ("not applicable") ratings and missing delays, sets factor baselines, and creates the stratified 70/30 train/test split. |
| `02_assumptions.R`          | Runs pre-model logistic regression assumption checks on the training set: outcome balance, continuous outliers, skewness/normality, categorical cell counts, Spearman correlations, and empirical log-odds linearity plots.    |
| `03_logistic_regression.R`  | Fits `model_1`, `model_2`, and `model_3`, compares AIC/BIC, checks VIFs and Cook's distance, writes assumption and odds-ratio tables, and validates `model_2` on the held-out test set.                                |
| `04_random_forest.R`        | Fits the 201-tree random forest on the training set, records out-of-bag and test-set confusion matrices, and ranks predictor importance.                                                                                       |
| `05_compare_and_forecast.R` | Compares both models on the test set, runs McNemar's test, forecasts satisfaction probabilities for nine devised passenger profiles, and benchmarks them against similar test passengers.                                      |
| `run_all.R`                 | Master runner that executes Scripts `01` to `05` in isolated environments and saves all section headings and results to `output/run_log.txt`.                                                                            |

### `output/`

#### Data, log, and saved models

| File                      | Purpose                                                                                                                                                       |
| :------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `train_data.rds`        | Cleaned 70% training set (86,626 passengers) created by `01_data_preparation.R`.                                                                            |
| `test_data.rds`         | Cleaned 30% held-out test set (37,124 passengers) created by `01_data_preparation.R`.                                                                       |
| `run_log.txt`           | Section-by-section console output from the latest `run_all.R` execution.                                                                                    |
| `models/lr_results.rds` | Saved final logistic regression model, test confusion matrix, and fit statistics from `03_logistic_regression.R` (git-ignored due to size; created on run). |
| `models/rf_results.rds` | Saved random forest model, test confusion matrix, and OOB accuracy from `04_random_forest.R` (git-ignored due to size; created on run).                     |

#### `output/tables/` (CSV tables)

| File                             | Created by | Purpose                                                                                        |
| :------------------------------- | :--------- | :--------------------------------------------------------------------------------------------- |
| `tbl_delay_correlation.csv`    | `01`     | Correlation between departure delay and arrival delay.                                         |
| `tbl_wifi_check.csv`           | `01`     | Percentage satisfied at each in-flight Wi-Fi rating (`0` to `5`).                          |
| `tbl_cleaning.csv`             | `01`     | Row counts before and after removing `0` ratings and missing delays.                         |
| `tbl_split.csv`                | `01`     | Passenger counts and `% satisfied` in the training and test sets.                            |
| `tbl_outliers.csv`             | `02`     | Outlier counts (`1.5 x IQR`) and upper whiskers for age and arrival delay.                   |
| `tbl_skewness.csv`             | `02`     | Skewness and Shapiro-Wilk p-values for age, raw delay, and logged delay.                       |
| `tbl_predictor_checks.csv`     | `02`     | Pre-model outlier/cell-size and skewness checks for all 11 predictors.                         |
| `tbl_correlation.csv`          | `02`     | Pairwise Spearman correlation matrix of numeric and ordinal predictors.                        |
| `tbl_lr_models.csv`            | `03`     | Parameter count, AIC, and BIC comparing `model_1`, `model_2`, and `model_3`.             |
| `tbl_vif.csv`                  | `03`     | Adjusted Variance Inflation Factors for `model_2`.                                           |
| `tbl_assumptions.csv`          | `03`     | Summary of the five model-wide logistic regression assumption checks.                          |
| `tbl_variable_assumptions.csv` | `03`     | Per-variable assumption checks, VIFs, and functional form for all 11 predictors.               |
| `tbl_odds_ratios.csv`          | `03`     | Odds ratios, Wald 95% confidence intervals, and p-values for `model_2`.                      |
| `tbl_lr_fit.csv`               | `03`     | McFadden's pseudo R-squared and events-per-term sample-size check.                             |
| `tbl_lr_confusion.csv`         | `03`     | Test-set confusion matrix cell counts for logistic regression.                                 |
| `tbl_rf_confusion.csv`         | `04`     | Test-set confusion matrix cell counts for the random forest.                                   |
| `tbl_rf_importance.csv`        | `04`     | Random forest variable importance (`MeanDecreaseAccuracy` and `MeanDecreaseGini`).         |
| `tbl_comparison.csv`           | `05`     | Training/OOB accuracy, test accuracy, sensitivity, specificity, and precision for both models. |
| `tbl_mcnemar.csv`              | `05`     | Majority-class baseline, paired prediction counts, and McNemar's test result.                  |
| `tbl_forecasts.csv`            | `05`     | Forecast satisfaction probabilities for the nine devised profiles and observed test-set rates. |

#### `output/figures/` (PNG charts)

| File                      | Created by | Purpose                                                                              |
| :------------------------ | :--------- | :----------------------------------------------------------------------------------- |
| `fig_boxplots.png`      | `02`     | Boxplots of age and arrival delay on the training set.                               |
| `fig_density.png`       | `02`     | Density plots of age, raw arrival delay, and `log(1 + arrival_delay)`.             |
| `fig_correlation.png`   | `02`     | Spearman scatterplot and correlation matrix on a 2,000-passenger sample.             |
| `fig_logit.png`         | `02`     | Empirical log-odds linearity grid across all eight numeric and ordinal predictors.   |
| `fig_cooks.png`         | `03`     | Cook's distance plot across training passengers for `model_2`.                     |
| `fig_rf_error.png`      | `04`     | Out-of-bag and class error rates as trees are added up to 201.                       |
| `fig_rf_importance.png` | `04`     | Horizontal bar chart of random forest variable importance.                           |
| `fig_comparison.png`    | `05`     | Grouped bar chart comparing test-set metrics against the majority baseline.          |
| `fig_forecasts.png`     | `05`     | Horizontal bar chart comparing both models' forecasts across the nine devised cases. |
