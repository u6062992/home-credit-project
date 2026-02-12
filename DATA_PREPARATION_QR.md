# Data Preparation Quick Reference

## Files Created
```
📁 home-credit-project/
├── train_prepared.csv          (307,511 × 151) ✓ Ready for modeling
├── test_prepared.csv           (48,744 × 150)  ✓ Ready for scoring
├── imputation_stats.rds        For reproducibility
├── data_preparation.R          Complete pipeline script
├── DATA_PREPARATION_SUMMARY.md Complete documentation
└── DATA_PREPARATION_QR.md      This file (quick reference)
```

## Loading the Prepared Data
```r
library(tidyverse)

# Load training data
train <- read_csv("train_prepared.csv")

# Load test data
test <- read_csv("test_prepared.csv")

# Load imputation statistics (for future use)
imputation_stats <- readRDS("imputation_stats.rds")
```

## Data Dimensions
- **Train:** 307,511 rows × 151 columns
- **Test:** 48,744 rows × 150 columns
- **New features engineered:** 67 columns
- **Missing numeric values:** 0 (complete)

## Key Engineered Features

### Demographic (5)
- `AGE_YEARS` - Client age in years
- `EMPLOYMENT_YEARS` - Years employed
- `AGE_GROUP` - Binned age (6 categories)
- `EMPLOYMENT_GROUP` - Binned employment (6 categories)
- `HAS_CHILDREN` - Binary flag

### Financial Transformations (4)
- `LOG_INCOME` - Log-transformed income
- `LOG_CREDIT` - Log-transformed credit
- `LOG_ANNUITY` - Log-transformed annuity
- `LOG_GOODS_PRICE` - Log-transformed goods price

### Financial Ratios (9)
```
CREDIT_TO_INCOME        # Primary debt burden metric
ANNUITY_TO_INCOME       # Annual payment as % of income
DEBT_TO_INCOME          # Alternative leverage metric
LOAN_TO_VALUE           # Credit vs goods price (LTV)
CREDIT_TO_GOODS         # Financing proportion
INCOME_PER_PERSON       # Per capita household income
CREDIT_PER_ANNUITY      # Loan duration proxy
ANNUITY_PER_INCOME      # Alternative affordability
REMAINING_PAYMENT_RATIO # Down payment %
```

### Interaction Terms (2)
- `AGE_EMPLOYMENT_INTERACTION` - Young × unemployed effect
- `INCOME_CREDIT_INTERACTION` - High income × high credit

### Missing Data Indicators (4)
- `EXT_SOURCE_1_MISSING` - Binary flag
- `EXT_SOURCE_2_MISSING` - Binary flag
- `EXT_SOURCE_3_MISSING` - Binary flag
- `TOTAL_MISSING_EXT_SOURCE` - Count (0-3)
- `EXT_SOURCES_AVAILABLE` - Inverse count (0-3)
- `HAS_BUILDING_INFO` - Has property data flag

### Contact Features (4)
- `DOCUMENTS_SUBMITTED` - Count of documents
- `CONTACT_METHODS` - Count of contact options (0-3)
- `HAS_PHONE` - Binary flag
- `HAS_EMAIL` - Binary flag
- `HAS_MOBILE` - Binary flag

### Data Quality Flags (1)
- `DAYS_EMPLOYED_IS_ANOMALY` - Placeholder value detected

### Binned Variables (4)
- `INCOME_GROUP` - Quartile-based bins
- `CREDIT_AMOUNT_GROUP` - Quartile-based bins
- `AGE_GROUP` - 6 age ranges
- `EMPLOYMENT_GROUP` - 6 employment durations

## Aggregated Supplementary Features

### From Bureau Data (11)
```
NUM_PRIOR_CREDITS              # Prior credit count
NUM_ACTIVE_CREDITS             # Currently active credits
NUM_CLOSED_CREDITS             # Successfully closed
NUM_CREDITS_WITH_OVERDUE       # History of missed payments
MAX_CREDIT_DAY_OVERDUE         # Maximum days late
AVG_CREDIT_DAY_OVERDUE         # Average lateness
MAX_AMT_OVERDUE                # Largest overdue amount
TOTAL_CREDIT_AMOUNT            # Total prior credit borrowed
DEBT_TO_CREDIT_RATIO           # % of credit that's overdue
AVG_CREDIT_LIMIT               # Average credit lines
AVG_DAYS_SINCE_CREDIT_START    # Relationship duration
```

### From Previous Applications (14)
```
NUM_PREVIOUS_APPLICATIONS      # Total applications
NUM_APPROVED_APPLICATIONS      # How many approved
NUM_REFUSED_APPLICATIONS       # How many refused
APPROVAL_RATE                  # % approved
NUM_CONSUMER_LOANS             # Consumer loan apps
NUM_CASH_LOANS                 # Cash loan apps
AVG_APPLICATION_AMOUNT         # Avg requested amount
AVG_CREDIT_AMOUNT_PREV         # Avg previous credit
DAYS_SINCE_LAST_APPR           # Recency (days)
```

### From Installments (7)
```
NUM_INSTALLMENTS               # Total installment payments
NUM_LATE_PAYMENTS              # Payments made late
LATE_PAYMENT_RATIO             # % of payments late
TOTAL_INSTALLMENT_AMOUNT       # Total owed
AVG_DAYS_LATE                  # Average days late
MAX_DAYS_LATE                  # Maximum days late
```

## Data Quality Improvements

| Issue | Solution | Impact |
|-------|----------|--------|
| DAYS_EMPLOYED = 365243 | Converted to 0, created flag | Preserved anomaly signal |
| Missing EXT_SOURCE | Created indicators + median imputation | Captured missingness pattern |
| Missing OCCUPATION_TYPE (31%) | "Unknown" category | Preserved informative absence |
| Missing OWN_CAR_AGE (66%) | Imputed as 0 | Clear semantic meaning |
| Sparse building data (66-70%) | 1 indicator flag instead of 39 cols | Reduced noise, preserved signal |
| DAYS_* in days (hard to interpret) | Converted to years | Human-readable |
| Right-skewed distributions | Log transformation | Normalized |
| Scale-dependent variables | Ratios created | Scale-invariant features |

## Target Variable
- **Feature name:** `TARGET`
- **Values:** 0 = No payment difficulties, 1 = Has payment difficulties
- **Prevalence:** 8% positive class (91.9% negative)
- **In train:** ✅ Yes
- **In test:** ❌ No (holdout for evaluation)

## Feature Statistics

### Numeric Features (135 columns)
- Min/max handled with log transforms
- All missing values imputed with training medians
- Ranges: Income ($25K - $117M), Credit ($0 - $4.5M)

### Categorical Features (16 columns)
- Original categories preserved
- New categories created (binned variables, "Unknown")
- One-hot encoding may be needed for modeling

## Train/Test Consistency

✅ **Guaranteed identical processing:**
1. Imputation computed from training data only
2. Applied identically to test data
3. No data leakage from test to train
4. All statistics stored in `imputation_stats.rds`

## Next Steps for Modeling

1. **Feature Selection**
   - Correlation analysis with TARGET
   - Multicollinearity check (VIF)
   - Feature importance from simple models

2. **Preprocessing for ML**
   - Scale/normalize numeric features
   - One-hot encode categorical variables
   - Handle class imbalance (8% positive)

3. **Cross-Validation**
   - Use stratified K-fold on training data
   - Preserve class distribution in splits

4. **Model Training**
   - Use train_prepared.csv
   - Generate predictions on test_prepared.csv
   - Evaluate using ROC-AUC, precision, recall

## Common Patterns in Code

### Load and inspect
```r
train <- read_csv("train_prepared.csv")
glimpse(train)
summary(train)
```

### Feature engineering check
```r
train |> select(starts_with("LOG_")) |> head()
train |> select(ends_with("_RATIO")) |> head()
train |> select(ends_with("_MISSING")) |> head()
```

### Aggregated features check
```r
train |> select(starts_with("NUM_PRIOR")) |> head()
train |> select(starts_with("NUM_LATE")) |> head()
```

### Missing value check
```r
train |> summarise(across(everything(), ~sum(is.na(.)))) |>
  select(where(~. > 0))
# Should return empty!
```

## File Sizes
- train_prepared.csv: 273 MB
- test_prepared.csv: 43.3 MB
- Total: ~320 MB prepared data

## Reproducibility

To reproduce on new data:
1. Source `data_preparation.R`
2. Load new application CSVs
3. Load `imputation_stats.rds` for test data
4. Apply identical transformations
5. Merge supplementary data same way

## Questions About Features?

**Financial Ratios Explained:**
- **CREDIT_TO_INCOME:** How much credit relative to annual income (high = risky)
- **DEBT_TO_INCOME:** What % of annual income goes to loan payment
- **LOAN_TO_VALUE:** Credit amount vs goods price (high = more risk)
- **INCOME_PER_PERSON:** Account for household size when assessing affordability

**Why Missing Indicators Matter:**
- Missingness in credit bureau data is non-random
- Clients WITH data have 2.6% lower default rate
- Missing data itself is predictive feature

**Why Log Transforms:**
- Income/credit heavily right-skewed
- Log transformation normalizes distributions
- Reduces outlier impact on models
- Makes relationships more linear

**Why Ratios Over Raw Amounts:**
- Raw amounts vary wildly (scale-dependent)
- Ratios normalize for applicant size
- Easier to compare across applicants
- More stable for model training

---

**Status:** ✅ Ready for Exploratory Analysis and Modeling
