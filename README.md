## Project Summary

This project demonstrates a complete machine learning pipeline for credit default risk prediction:

1. **Exploratory Data Analysis** - Understanding data patterns and relationships
2. **Data Preparation** - Cleaning, feature engineering, and aggregating supplementary data
3. **Modeling** - Systematic model comparison, hyperparameter tuning, and validation
4. **Deployment** - Kaggle submission achieving strong performance (AUC: 0.751)

# Home Credit Default Risk Project  
**Erin Bednarik (U6062992)**

---

## Project Overview

This project develops a complete machine learning pipeline to predict credit default risk using the Home Credit dataset. The work includes exploratory data analysis (EDA), data preparation, feature engineering, and predictive modeling.

The primary objective is to build a model that accurately distinguishes between borrowers who are likely to default and those who are not, while addressing challenges such as class imbalance and high-dimensional data.

---

## Exploratory Data Analysis (EDA)

- HTML Report: [Exploratory Data Analysis](https://u6062992.github.io/home-credit-project/eda_home_credit_train.html)

The EDA investigates the structure, quality, and relationships within the dataset. Key visualizations and summaries are used to:

- Identify missing data patterns and data quality issues  
- Examine relationships between features and the target variable  
- Understand distributions of key financial and demographic variables  

**Key Insights:**
- The dataset contains substantial missingness, particularly in building-related features, which informed feature removal decisions  
- Strong predictors include external credit scores (EXT_SOURCE variables) and financial ratios  
- Class imbalance is significant (~8% default), requiring specialized modeling strategies  

All visualizations are interpreted within the report to explain how they inform downstream modeling decisions.

---

## Data Preparation

### Script: [data_preparation.R](data_preparation.R)

### Purpose

This script implements a comprehensive data preparation pipeline that cleans raw data, engineers features, and produces modeling-ready datasets. The goal is to ensure consistency, reproducibility, and strong predictive signal.

### Key Components

**1. Data Loading**  
The script imports five primary datasets:
- Application (train and test)  
- Bureau records  
- Previous applications  
- Installment payments  

**2. Data Cleaning**  
Several data quality issues are addressed:
- Corrects anomalous employment values (e.g., 365243 → 0) and creates indicator variables  
- Handles missing values in key predictors (e.g., EXT_SOURCE variables) using imputation and missingness flags  
- Standardizes categorical variables (e.g., OCCUPATION_TYPE)  
- Removes highly sparse features (60–70% missingness)  

**3. Feature Engineering**  
More than 50 features are created to improve predictive performance:
- Demographic transformations (e.g., age and employment duration in years)  
- Log transformations for skewed financial variables  
- Financial ratios (e.g., debt-to-income, credit-to-income)  
- Interaction terms capturing relationships between variables  
- Behavioral indicators (e.g., document counts, contact methods)  

**4. Data Aggregation**  
Supplementary datasets are aggregated to the customer level:
- Bureau data: credit history and debt metrics  
- Previous applications: approval rates and loan characteristics  
- Installments: payment behavior and delinquency patterns  

**5. Data Integration and Imputation**  
- Aggregated features are merged into the main datasets  
- Missing values are imputed using training-set statistics to ensure consistency between train and test data  

**6. Output Generation**  
The script produces:
- `train_prepared.csv`  
- `test_prepared.csv`  
- `imputation_stats.rds`  

### Reproducibility

```r
install.packages(c("tidyverse", "lubridate"))
source("data_preparation.R")
```

**Key Achievement:** Successfully handled severe class imbalance (8% default rate) and achieved 25+ percentage point improvement over baseline, demonstrating practical credit risk prediction capabilities.

## Modeling

### Notebook: [modeling_analysis.qmd](modeling_analysis.qmd)

### Purpose

This notebook develops and evaluates predictive models for credit default risk. It emphasizes best practices for imbalanced classification, including appropriate metrics, resampling strategies, and validation techniques.

All code is introduced and explained throughout the notebook, with detailed comments describing each modeling step.

---

## Modeling Results

### Final Model Performance

- **Algorithm:** XGBoost with downsampling  
- **Kaggle Public Leaderboard AUC:** 0.751  
- **Cross-Validated AUC:** 0.706 ± 0.014  
- **Accuracy:** 84.7%  

**Interpretation:**  
The model substantially outperforms random guessing (AUC = 0.50), achieving a 25 percentage point improvement. The higher Kaggle score relative to cross-validation suggests strong generalization without evidence of overfitting.

---

## Model Development Process

### 1. Baseline Model Comparison

Three models were evaluated using cross-validation:

| Model | AUC | Accuracy |
|-------|-----|----------|
| Logistic Regression | 0.703 | 90.9% |
| XGBoost | 0.677 | 91.2% |
| Random Forest | 0.654 | 91.3% |

**Interpretation:**  
Logistic regression performed best initially, indicating that the engineered features captured meaningful linear relationships. However, this also suggested potential gains from models capable of capturing non-linear interactions.

---

### 2. Addressing Class Imbalance

Given the severe imbalance (~8% defaults), multiple strategies were tested:

| Strategy | AUC | Sensitivity | Specificity |
|----------|-----|-------------|-------------|
| Downsampling | 0.692 | 0.845 | 0.405 |
| Upsampling | 0.689 | 0.962 | 0.132 |
| SMOTE | 0.666 | 0.993 | 0.006 |

**Interpretation:**  
Downsampling provided the best balance between identifying defaults (sensitivity) and avoiding false positives (specificity), leading to the strongest overall AUC.

---

### 3. Hyperparameter Tuning

A randomized search strategy was used to efficiently tune XGBoost parameters.

**Outcome:**  
AUC improved from 0.692 to 0.706.

**Interpretation:**  
Even limited tuning on a subset of the data produced measurable gains, demonstrating that model performance is sensitive to parameter selection.

---

### 4. Impact of Supplementary Data

| Feature Set | AUC |
|-------------|-----|
| Application data only | 0.683 |
| With supplementary data | 0.698 |

**Interpretation:**  
Aggregated external data (bureau, previous applications, installments) significantly improved predictive performance, confirming their value in capturing borrower behavior.

---

## Final Model Justification

XGBoost with downsampling was selected because it:

- Achieved the highest cross-validated AUC  
- Effectively handled class imbalance  
- Captured non-linear feature interactions  
- Demonstrated strong generalization on unseen data  
- Provided interpretable feature importance aligned with credit risk theory  

---

## Methodology Highlights

- Subsampling (5,000 rows) used for efficient experimentation  
- Stratified cross-validation to preserve class distribution  
- AUC used as the primary evaluation metric due to imbalance  
- Randomized search for efficient hyperparameter tuning  
- Final model trained on full dataset  

---

## Key Insights

- Accuracy is not an appropriate metric for imbalanced classification; AUC provides a more reliable measure  
- Feature engineering significantly improves model performance  
- External data sources add meaningful predictive value  
- Proper handling of class imbalance is critical for real-world performance  

---

## Outputs

- `submission.csv`: Final predictions for Kaggle submission  
- `modeling_analysis.html`: Rendered notebook with full analysis and visualizations  

---

## Conclusion

This project demonstrates an end-to-end machine learning workflow, from raw data to a validated predictive model. The final model achieves strong performance in a challenging, imbalanced classification setting and highlights the importance of feature engineering, data integration, and thoughtful evaluation.
