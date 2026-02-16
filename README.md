U6062992, Erin Bednarik

## EDA
- HTML report: [Exploratory Data Analysis](https://u6062992.github.io/home-credit-project/eda_home_credit_train.html)

## Data Preparation
- R script: [Data Preparation Script](data_preparation.R)

## Data Preparation

### Overview
Comprehensive data preparation pipeline for Home Credit Default Risk analysis. Cleans, transforms, and engineers features from credit application data.

### Script: [data_preparation.R](data_preparation.R)

**What It Does:**
1. **Loads Data** - Reads 5 CSV files (application train/test, bureau, previous applications, installments)
2. **Cleans Application Data**:
   - Fixes DAYS_EMPLOYED anomaly (365243 → 0, creates indicator)
   - Handles missing values in EXT_SOURCE variables (creates missing indicators)
   - Converts OCCUPATION_TYPE NAs to "Unknown"
   - Imputes OWN_CAR_AGE missing values with 0
   - Drops sparse building features (60-70% missing)
3. **Engineers Features** - Creates 50+ new features:
   - Demographics: Age/employment in years, age/employment groups
   - Log transforms: Income, credit, annuity, goods price
   - Financial ratios: Credit-to-income, debt-to-income, loan-to-value (9 ratios)
   - Interaction terms: Age×employment, income×credit
   - Indicators: Document submission count, contact methods, has children
4. **Aggregates Supplementary Data**:
   - Bureau: Credit counts, overdue metrics, debt ratios
   - Previous applications: Application counts, approval rates, loan amounts
   - Installments: Payment history, late payments
5. **Joins All Data** - Left joins all aggregated data to train/test sets
6. **Imputes Missing Values** - Uses training set medians for consistency
7. **Saves Output** - Prepared CSVs and imputation statistics

**How to Run:**
```r
# Install required packages
install.packages(c("tidyverse", "lubridate"))

# Run the script
source("data_preparation.R")