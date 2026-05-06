# Machine Learning (Python)

## Overview
This folder contains Python code to reproduce the results described in our publications. Currently, it includes the full pipeline for the surgical site infection (SSI) phenotype and postpardum depression (PPD) phenotype. The preeclampsia phenotype is under construction and only contains baseline codes.

## Repository Structure
- `src/`  
  Contains code shared across all phenotypes, including feature selection and model training utilities.

- `ssi/`
  Contains phenotype-specific code for surgical site infection:
  - `notebooks/`: Jupyter notebooks used to reproduce the published results.
  - `preprocess.py`: Data preprocessing logic for SSI.
  - `feature_filter.py`: Feature filtering and selection logic for SSI.

- `ppd/`
  Contains codes for post-partum depression
  - `notebooks/modeling_compare_labeling.ipynb`: Jupyter notebook to reproduce the phenotype comparison table in the published paper.
  - `notebooks/test_feature_selection.ipynb`: Jupyter notebook to generate the model with only 20 features for Epic deployment team.
  - `preprocess.py`: Data preprocessing logic for PPD.
  - `models/`: Contain the random forest model using 20 features as requested.

- `preeclampsia`
  Contains baseline codes for preeclampsia

## Usage

### 1. Data extraction
To extract a snapshot of the database into phenotype-specific parquet files, run:
```bash
python extract.py
```

Before running this script, ensure that your .env file is properly configured with the required database credentials. The extracted parquet files will be saved into the corresponding phenotype directories.

### 2. Reproducing SSI results
For the surgical site infection phenotype:

- The notebooks needed to reproduce the published results are located in ssi/notebooks.
- All preprocessing and feature filtering steps are implemented in ssi/preprocess.py and ssi/feature_filter.py.

You do not need to run the preprocessing scripts manually. The notebooks will automatically execute all required preprocessing steps.

### 3. Reproducing PPD results
- The notebook `modeling_compare_labeling.ipynb` contains codes that reproduces the phenotype comparison table in the published paper. The data are slightly different from the ones used in the paper but the overall trend stays the same. Using F53 + EPDS + PHQ9 is still best combination for phenotype definition
- The notebook `test_feature_selection.ipynb` contains codes to produce a model with 20 features that the Epic team may use later. The `models/` directory contains both the random forest model and metadata for training. The top 20 features can be found in `models/model_metadata.json` 
- `notebooks/comparison_with_without_day.png` compares ROC–AUC for models trained with and without the earliest_day/latest_day features. When a large number of features is used, performance is similar for both models. However, when the number of selected features is restricted, the model without the earliest_day features achieves higher ROC–AUC. Therefore, I suggest replacing the feature list with the new ones in `models/model_metadata.json`.

### 4. Preliminary result for preeclampsia
- The notebook `baseline.ipynb` contains codes for a baseline model.
- We observe that the prevalence rate at WFU is relatively high (~15%). The `rpt_preeclampsia_check_prevalence_rat`e table in the dbt section reports a prevalence rate of 11% when considering only diagnosis codes and magnesium infusion. This may be useful later for investigating potential drivers of the higher overall prevalence rate.