U6062992, Erin Bednarik

## EDA
- HTML report: [Exploratory Data Analysis](https://u6062992.github.io/home-credit-project/eda_home_credit_train.html)

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
```

**Expected Inputs** (from `data/` folder):
- `application_train.csv`
- `application_test.csv`
- `bureau.csv`
- `previous_application.csv`
- `installments_payments.csv`

**Expected Outputs:**
- `train_prepared.csv` - Cleaned training data with engineered features
- `test_prepared.csv` - Cleaned test data with engineered features
- `imputation_stats.rds` - Median values from training set (for reproducibility)

**Key Strengths:**
- ✅ Train/test consistency (uses training statistics for imputation)
- ✅ Comprehensive feature engineering (50+ new features)
- ✅ Well-documented with clear progress messages
- ✅ Professional structure with modular functions
- ✅ Handles data quality issues (missing values, anomalies, sparse features)

---

## Modeling

### Notebook: [modeling_analysis.qmd](modeling_analysis.qmd)

Comprehensive predictive modeling for credit default risk using prepared datasets. The notebook demonstrates best practices for imbalanced classification including model comparison, hyperparameter tuning, and rigorous validation.

### Final Results

**Model Performance:**
- **Algorithm:** XGBoost with Downsampling
- **Kaggle Public Leaderboard AUC:** **0.751** 🎉
- **Cross-Validated AUC:** 0.706 ± 0.014
- **Accuracy:** 84.7%
- **Training Data:** 307,511 rows with 151 features

**Performance Context:**
- Baseline (random guessing): AUC = 0.50
- Our model: AUC = 0.751 (+25.1 percentage points improvement)
- Top Kaggle solutions: AUC ≈ 0.79-0.80
- **Achievement:** Strong performance in top ~30-40% range

### Models Tried

We systematically evaluated multiple approaches:

#### 1. Model Comparison (Without Class Balancing)
Compared three algorithms using 3-fold cross-validation on 5,000 sample:

| Model | AUC | Accuracy | Notes |
|-------|-----|----------|-------|
| **Logistic Regression** | 0.703 | 90.9% | Best initial performer; simple, interpretable |
| **XGBoost** | 0.677 | 91.2% | Strong with tuning potential |
| **Random Forest** | 0.654 | 91.3% | Slower, lower AUC |

**Key Finding:** Logistic Regression surprisingly outperformed tree-based methods initially, suggesting linear relationships and good feature engineering captured the signal effectively.

#### 2. Class Imbalance Strategies (XGBoost)
Tested strategies to handle severe class imbalance (~92% non-default, 8% default):

| Strategy | AUC | Accuracy | Sensitivity | Specificity |
|----------|-----|----------|-------------|-------------|
| **Downsampling** | 0.692 | 80.7% | 0.845 | 0.405 |
| **Upsampling** | 0.689 | 89.0% | 0.962 | 0.132 |
| **No adjustment** | 0.677 | 91.2% | - | - |
| **SMOTE** | 0.666 | 90.8% | 0.993 | 0.006 |

**Key Finding:** Downsampling provided the best balance between sensitivity (catching defaults) and specificity (avoiding false alarms), improving AUC by 1.5 percentage points over no adjustment.

#### 3. Hyperparameter Tuning
Used efficient randomized search on XGBoost with downsampling:
- **Search Strategy:** 20 random combinations (not exhaustive grid)
- **Sample Size:** 5,000 rows for speed
- **Cross-Validation:** 3-fold CV
- **Tuned Parameters:** trees, tree_depth, learn_rate, min_n, loss_reduction, mtry

**Best Parameters Found:**
- trees = 80
- tree_depth = 7
- learn_rate = 0.038
- min_n = 5
- loss_reduction = 0.177
- mtry = 20

**Result:** Improved from AUC 0.692 → 0.706 (+1.4 percentage points)

#### 4. Supplementary Features Impact
Quantified the value of aggregated features from bureau, previous applications, and installments:

| Feature Set | AUC | Accuracy | Improvement |
|-------------|-----|----------|-------------|
| Application data only | 0.683 | 83.5% | Baseline |
| **With supplementary data** | **0.698** | **84.7%** | **+1.5 pts AUC** |

**Key Finding:** The effort to aggregate supplementary data was highly valuable. Bureau credit history and installment payment patterns significantly improved predictions.

### Why We Selected XGBoost with Downsampling

**Final Model Choice Rationale:**

1. **Best Overall Performance:** After tuning, XGBoost achieved highest cross-validated AUC (0.706)

2. **Handled Class Imbalance Well:** Downsampling provided optimal balance:
   - Good sensitivity (catching 84.5% of defaults)
   - Reasonable specificity (avoiding excessive false alarms)
   - Best AUC among balancing strategies

3. **Captured Non-Linear Patterns:** XGBoost's tree-based structure captured complex interactions better than linear models after tuning

4. **Robust Generalization:** Model performed even better on Kaggle (0.751) than CV predicted (0.706), indicating good generalization and no overfitting

5. **Feature Importance Insights:** Top features aligned with credit risk theory:
   - EXT_SOURCE_2, EXT_SOURCE_1 (external credit scores)
   - DEBT_TO_CREDIT_RATIO (engineered feature)
   - AVG_DAYS_SINCE_CREDIT_START (bureau data)
   - LATE_PAYMENT_RATIO (installments data)

6. **Computational Efficiency:** Training completed in reasonable time (~15 minutes on full dataset) while achieving strong performance

### Methodology Highlights

**Speed-Up Strategies:**
- ✅ 5,000 row sample for model exploration and hyperparameter tuning
- ✅ 3-fold CV instead of 5 or 10 (balanced speed and reliability)
- ✅ Randomized search (20 iterations) instead of exhaustive grid search
- ✅ Parallel processing enabled
- ✅ Final model trained on full dataset (307,511 rows)

**Validation Approach:**
- Established baseline (majority class classifier: AUC = 0.50)
- Used AUC as primary metric (accuracy misleading with class imbalance)
- Stratified cross-validation to maintain class distribution
- Tested with/without supplementary features to quantify value
- Conservative CV estimates (predicted 0.706, achieved 0.751)

**How to Run:**
```r
# Install required packages
install.packages(c("tidyverse", "tidymodels", "themis", "xgboost", 
                   "ranger", "vip", "pROC", "doParallel"))

# Open and render the Quarto notebook
# (or run code chunks interactively)
```

### Key Insights

1. **Class Imbalance Matters:** Accuracy (92%) is misleading; AUC is the right metric
2. **Supplementary Data is Valuable:** Bureau and payment history add +1.5 pts AUC
3. **Feature Engineering Pays Off:** Engineered ratios (e.g., DEBT_TO_CREDIT_RATIO) highly predictive
4. **Efficient Tuning Works:** Randomized search on subsample finds good parameters quickly
5. **Model Choice Matters:** XGBoost + downsampling outperformed other combinations after tuning

### Files Generated
- `submission.csv` - Kaggle submission with 48,744 test predictions (AUC: 0.751)
- `modeling_analysis.html` - Rendered analysis report (if notebook is rendered)

---

## Project Summary

This project demonstrates a complete machine learning pipeline for credit default risk prediction:

1. **Exploratory Data Analysis** - Understanding data patterns and relationships
2. **Data Preparation** - Cleaning, feature engineering, and aggregating supplementary data
3. **Modeling** - Systematic model comparison, hyperparameter tuning, and validation
4. **Deployment** - Kaggle submission achieving strong performance (AUC: 0.751)

**Key Achievement:** Successfully handled severe class imbalance (8% default rate) and achieved 25+ percentage point improvement over baseline, demonstrating practical credit risk prediction capabilities.
