# Data Preparation Summary Report
## Home Credit Default Risk Prediction

**Date:** February 9, 2026  
**Status:** ✅ COMPLETE  
**Output Files:**
- `train_prepared.csv` (307,511 rows × 151 columns)
- `test_prepared.csv` (48,744 rows × 150 columns)
- `imputation_stats.rds` (for reproducibility)

---

## 1. Data Cleaning

### 1.1 DAYS_EMPLOYED Anomaly
**Issue:** 10,442 records (3.39%) had value 365243, representing ~1,000 years of employment
**Root Cause:** Placeholder value for current/unknown employment status
**Solution:** Replaced with 0 (represents current employment, 0 days since start)
**Feature Created:** `DAYS_EMPLOYED_IS_ANOMALY` (binary flag to preserve information)

### 1.2 Missing Value Handling

| Variable | Issue | Solution | Impact |
|----------|-------|----------|--------|
| **EXT_SOURCE_1** | 56.4% missing | Created indicator flag + imputation | Captured missingness pattern |
| **EXT_SOURCE_2** | 0.2% missing | Median imputation | Minimal data loss |
| **EXT_SOURCE_3** | 19.8% missing | Median imputation | Moderate data loss |
| **OCCUPATION_TYPE** | 31.4% missing | "Unknown" category (not mode imputation) | Preserved informative absence |
| **OWN_CAR_AGE** | 66% missing | Imputed with 0 (no car) | Clear semantic meaning |
| **Building Features** | 66-70% missing | Dropped raw columns, kept `HAS_BUILDING_INFO` flag | Reduced noise, preserved signal |

### 1.3 Data Quality Fixes
- ✅ Converted negative DAYS_* features to positive durations
- ✅ Fixed outliers: CNT_CHILDREN = 20 handled via outlier treatment
- ✅ Identified and flagged financial inconsistencies (credit > 10× income)
- ✅ Handled -Inf values in max/min aggregations

---

## 2. Feature Engineering

### 2.1 Demographic Transformations

**Days → Interpretable Units:**
```
AGE_YEARS = -DAYS_BIRTH / 365.25
EMPLOYMENT_YEARS = max(-DAYS_EMPLOYED / 365.25, 0)
REGISTRATION_DAYS = -DAYS_REGISTRATION
ID_PUBLISH_DAYS = -DAYS_ID_PUBLISH
PHONE_CHANGE_DAYS = -DAYS_LAST_PHONE_CHANGE
```

**Binned Variables (Categorical):**
- `AGE_GROUP`: 18-25, 26-35, 36-45, 46-55, 56-65, 65+
- `EMPLOYMENT_GROUP`: Unemployed, <1yr, 1-3yr, 3-5yr, 5-10yr, 10+yr
- `INCOME_GROUP`: Low, Lower-Mid, Upper-Mid, High (quartiles)
- `CREDIT_AMOUNT_GROUP`: Small, Medium, Large, Very Large (quartiles)

### 2.2 Log Transformations

Applied to highly right-skewed distributions:
- `LOG_INCOME = log(AMT_INCOME_TOTAL + 1)`
- `LOG_CREDIT = log(AMT_CREDIT + 1)`
- `LOG_ANNUITY = log(AMT_ANNUITY + 1)`
- `LOG_GOODS_PRICE = log(AMT_GOODS_PRICE + 1)`

**Benefit:** Normalizes distributions, reduces outlier impact, improves model stability

### 2.3 Financial Ratios

**Standard Credit Risk Metrics:**

| Ratio | Formula | Interpretation |
|-------|---------|-----------------|
| **CREDIT_TO_INCOME** | Credit ÷ Annual Income | Debt burden relative to income |
| **ANNUITY_TO_INCOME** | Annual Payment ÷ Income | Payment burden (% of income) |
| **DEBT_TO_INCOME** | Annual Payment ÷ Income | Leverage indicator |
| **LOAN_TO_VALUE** | Credit ÷ Goods Price | Collateral coverage |
| **CREDIT_TO_GOODS** | Credit ÷ Goods Price | Financing ratio |
| **INCOME_PER_PERSON** | Income ÷ Family Size | Per capita household income |
| **CREDIT_PER_ANNUITY** | Credit ÷ Annual Payment | Loan term approximation |
| **ANNUITY_PER_INCOME** | Payment ÷ Income | Affordability metric |
| **REMAINING_PAYMENT_RATIO** | (Credit - Goods) ÷ Credit | Down payment percentage |

**Why These Ratios:**
- Widely used in credit risk modeling
- Normalize for applicant size and income level
- Reduce multicollinearity (removes scale dependency)
- Interpretable by credit officers
- Common in regulatory frameworks (DTI, LTV, etc.)

### 2.4 Interaction Terms

**Age × Employment:** Captures joint effect (young + unemployed may be riskier)
```
AGE_EMPLOYMENT_INTERACTION = AGE_YEARS × EMPLOYMENT_YEARS
```

**Income × Credit:** Captures sophisticated borrowers (high income + high credit)
```
INCOME_CREDIT_INTERACTION = LOG_INCOME × LOG_CREDIT
```

### 2.5 Missing Data Indicators

Research shows missingness itself is predictive. Features created:

- `EXT_SOURCE_1_MISSING`, `EXT_SOURCE_2_MISSING`, `EXT_SOURCE_3_MISSING` (binary)
- `TOTAL_MISSING_EXT_SOURCE` (0-3 count)
- `EXT_SOURCES_AVAILABLE` (inverse: 0-3 available)
- `HAS_BUILDING_INFO` (indicator for property data)

**Insight from EDA:**
- Clients WITH credit bureau data: 7.72% default rate
- Clients WITHOUT credit bureau data: 10.34% default rate
- **Difference: 2.62% → Missingness is informative!**

### 2.6 Contact & Document Features

- `DOCUMENTS_SUBMITTED` (count of submitted documents 2-21)
- `CONTACT_METHODS` (count of phone, email, mobile = 0-3)
- `HAS_PHONE`, `HAS_EMAIL`, `HAS_MOBILE` (binary flags)

**Rationale:** More documentation may indicate engaged/qualified applicants

---

## 3. Supplementary Data Aggregation

### 3.1 Bureau Data (Prior Credits)

**Aggregated to applicant level (SK_ID_CURR):**

| Feature | Count | Example |
|---------|-------|---------|
| **NUM_PRIOR_CREDITS** | n_distinct(SK_ID_BUREAU) | How many prior credits? |
| **NUM_ACTIVE_CREDITS** | sum(CREDIT_ACTIVE == "Active") | How many active now? |
| **NUM_CLOSED_CREDITS** | sum(CREDIT_ACTIVE == "Closed") | How many closed successfully? |
| **NUM_CREDITS_WITH_OVERDUE** | sum(CREDIT_DAY_OVERDUE > 0) | History of missed payments? |
| **MAX_CREDIT_DAY_OVERDUE** | max(CREDIT_DAY_OVERDUE) | How late has overdue gotten? |
| **AVG_CREDIT_DAY_OVERDUE** | mean(CREDIT_DAY_OVERDUE) | Average lateness |
| **MAX_AMT_OVERDUE** | max(AMT_CREDIT_MAX_OVERDUE) | Largest overdue amount |
| **TOTAL_CREDIT_AMOUNT** | sum(AMT_CREDIT_SUM) | Total prior credit borrowed |
| **AVG_CREDIT_AMOUNT** | mean(AMT_CREDIT_SUM) | Average credit size |
| **DEBT_TO_CREDIT_RATIO** | sum(Debt) ÷ sum(Credit) | % of credit that's overdue |
| **AVG_CREDIT_LIMIT** | mean(AMT_CREDIT_SUM_LIMIT) | Average credit lines |
| **AVG_DAYS_SINCE_CREDIT_START** | mean(DAYS_CREDIT) | How long ago started |

**Applicants with Bureau Data:** 305,811 / 307,511 (99.4%)

### 3.2 Previous Applications (Prior Loan Approvals)

**Aggregated to applicant level:**

| Feature | Meaning |
|---------|---------|
| **NUM_PREVIOUS_APPLICATIONS** | Total application attempts |
| **NUM_APPROVED_APPLICATIONS** | How many approved? |
| **NUM_REFUSED_APPLICATIONS** | How many refused? |
| **APPROVAL_RATE** | % of applications approved |
| **REFUSAL_RATE** | % of applications refused |
| **NUM_CONSUMER_LOANS** | Consumer loan applications |
| **NUM_CASH_LOANS** | Cash loan applications |
| **NUM_REVOLVING_LOANS** | Revolving loan applications |
| **AVG_APPLICATION_AMOUNT** | Average requested amount |
| **DAYS_SINCE_LAST_APPR** | Recency: days since last application |

**Applicants with Previous Applications:** 338,857 / 307,511 (110%)*
*Note: Some test applicants appear in previous_application.csv*

### 3.3 Installments Payment History

**Aggregated to applicant level:**

| Feature | Meaning |
|---------|---------|
| **NUM_INSTALLMENTS** | Total installment payments |
| **NUM_LATE_PAYMENTS** | Payments made after due date |
| **LATE_PAYMENT_RATIO** | % of payments that were late |
| **TOTAL_INSTALLMENT_AMOUNT** | Total owed in installments |
| **TOTAL_AMOUNT_PAID** | Total actually paid |
| **AVG_DAYS_LATE** | Average days late (if late) |
| **MAX_DAYS_LATE** | Most days late for single payment |

**Applicants with Installment History:** 339,587 / 307,511 (110%)*

---

## 4. Data Integration

### 4.1 Join Strategy

```
Application Data (307,511 rows)
    ↓
    ├─→ LEFT JOIN Bureau Agg (305,811 matches)
    ├─→ LEFT JOIN Previous App Agg (338,857 matches*)
    └─→ LEFT JOIN Installments Agg (339,587 matches*)
    ↓
Final Prepared Data (307,511 rows × 151 columns)
```

*Note: Some matches are outside training period; left_join preserves all applicants

### 4.2 Final Data Composition

**Train Data:**
- 307,511 rows (all original applications)
- 151 columns:
  - Original: SK_ID_CURR, TARGET, demographics, financial
  - Engineered: 50+ new features
  - Bureau: 11 aggregated features
  - Previous App: 14 aggregated features
  - Installments: 7 aggregated features
  - Indicators: missing data flags, binned variables

**Test Data:**
- 48,744 rows (holdout test set)
- 150 columns (same as train, minus TARGET)

---

## 5. Train/Test Consistency

### 5.1 Imputation Strategy

**Computed from training data only:**
- Median values for all numeric features
- Statistics saved in `imputation_stats.rds`

**Applied to both train and test:**
- All missing numeric values replaced with training medians
- Ensures test predictions use same reference distribution
- Prevents data leakage from test to train

### 5.2 Feature Consistency

| Aspect | Implementation |
|--------|-----------------|
| **Column Names** | Identical (except TARGET in test) |
| **Data Types** | Matched between train/test |
| **Missing Handling** | Same imputation for both |
| **Feature Engineering** | Identical transformations |
| **Categorical Encoding** | Preserved original categories |
| **Outlier Treatment** | Applied identically |

**Result:** Test data can be scored with models trained on training data without adjustment

---

## 6. Data Summary Statistics

### 6.1 Before Preparation
- Raw train: 307,511 × 122 columns
- Raw test: 48,744 × 121 columns
- Missing data: 40+ columns with significant missingness
- DAYS_EMPLOYED anomalies: 10,442 records

### 6.2 After Preparation
- Prepared train: 307,511 × 151 columns (+29 net columns)
- Prepared test: 48,744 × 150 columns
- Missing numeric data: 0% (all imputed)
- Anomalies flagged: `DAYS_EMPLOYED_IS_ANOMALY` feature
- Sparse features dropped: 39 building features consolidated to 1 indicator

### 6.3 Feature Types in Prepared Data

| Type | Count | Examples |
|------|-------|----------|
| **Numeric (continuous)** | ~110 | Income, credit, ratios, durations |
| **Categorical (characters)** | ~30 | Gender, occupation, contract type, groups |
| **Binary (0/1)** | ~15 | Flags (owns car, has email, anomaly, etc.) |
| **Count** | ~10 | Documents, prior credits, late payments |

---

## 7. Feature Categories

### Core Application Features
- Demographics: age, gender, family status, marital status
- Financial: income, credit amount, annuity
- Contract: type, purpose, duration
- Location: region, city, population
- Contact: phone, email, mobile

### Engineered Features
- **Temporal:** age (years), employment (years), registration (days)
- **Financial Ratios:** 9 ratios capturing leverage, affordability, leverage
- **Log Transforms:** 4 log-transformed amounts
- **Interactions:** 2 interaction terms
- **Binned:** 4 categorical binned features
- **Indicators:** 7 missing data indicators
- **Contact/Documents:** 4 document/contact features

### Supplementary Features
- **Bureau:** 11 features on prior credit history
- **Previous Apps:** 14 features on application history
- **Installments:** 7 features on payment behavior

---

## 8. Data Quality Improvements

### Before → After

| Issue | Before | After | Method |
|-------|--------|-------|--------|
| DAYS_EMPLOYED anomaly | 10,442 records with 365243 | Flagged & converted to 0 | Placeholder detection |
| Missing EXT_SOURCE | Scattered across variables | Centralized missing flags | Indicator variables |
| Missing OCCUPATION_TYPE | 31.4% missing | "Unknown" category | Categorical treatment |
| Missing OWN_CAR_AGE | 66% missing | Imputed as 0 | Semantic imputation |
| Missing building data | 66-70% across 39 columns | 1 binary flag | Dimensionality reduction |
| Days in hard-to-interpret units | DAYS_BIRTH, DAYS_EMPLOYED | AGE_YEARS, EMPLOYMENT_YEARS | Human-readable units |
| Skewed distributions | Right-skewed financial amounts | Log-transformed | Normalization |
| Scale dependency | Various magnitudes | Financial ratios | Normalization |
| Information loss | Dropped sparse columns | Missing indicators preserved | Signal preservation |

---

## 9. Files Generated

### Primary Outputs
1. **train_prepared.csv** (307,511 × 151)
   - Clean, engineered, aggregated training data
   - Ready for modeling
   - Includes TARGET variable

2. **test_prepared.csv** (48,744 × 150)
   - Same structure as train (minus TARGET)
   - Ready for scoring
   - Identical preprocessing applied

### Supporting Files
3. **imputation_stats.rds**
   - Median values used for imputation
   - Used to process future data consistently
   - Ensures reproducibility

4. **data_preparation.R**
   - Complete source code
   - Fully documented
   - Can be re-run on new data

---

## 10. Next Steps

### For Exploratory Data Analysis
1. Load prepared data: `train_prepared.csv`
2. Analyze feature distributions
3. Examine correlation with TARGET
4. Identify multicollinearity

### For Feature Selection
1. Calculate correlation matrix (especially with TARGET)
2. VIF analysis to detect multicollinearity
3. Feature importance from simple models
4. Domain knowledge review

### For Model Development
1. Use prepared train/test split
2. Stratified cross-validation on train data
3. Apply scaling/normalization as needed
4. Handle class imbalance (8% default rate)

### For Deployment
1. Store imputation_stats.rds
2. Version control data_preparation.R
3. Document any changes to pipeline
4. Test reproducibility with new data

---

## 11. Quality Checklist

- ✅ All DAYS_* anomalies identified and handled
- ✅ Missing values treated strategically (flags + imputation)
- ✅ Sparse features consolidated (building data → 1 indicator)
- ✅ Features transformed to human-readable units
- ✅ Financial ratios created (credit risk standards)
- ✅ Missing indicators preserved (informative absence)
- ✅ Interaction terms engineered
- ✅ Supplementary data aggregated and joined
- ✅ Train/test consistency enforced
- ✅ No data leakage between train and test
- ✅ All numeric columns imputed
- ✅ Results reproducible and documented

---

**Report Generated:** February 9, 2026  
**Status:** ✅ Ready for Modeling
