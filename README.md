# AMMI Analytics and Machine Learning Repository

## Overview

This repository contains code to transform data and build machine learning models in support of research for the **Analytics and Machine‑learning for Maternal‑health Interventions (AMMI)** initiative.

AMMI is a collaborative effort among researchers at UNC‑Chapel Hill, Duke University, and Wake Forest University. The initiative aims to address persistent gaps in maternal health outcomes by developing a machine learning–enhanced health technology framework to help reduce downstream risk of maternal mortality in African‑American women.

This repository supports that goal by:
- Producing reproducible, well‑tested analytic feature datasets
- Training and evaluating predictive machine learning models built on those features
- Enabling transparent, auditable, and reusable research workflows

---

## Repository Structure

The repository is organized into two primary components for data transformations and machine learning modeling.  Each section has a README.md with specific instructions for that component.

### `analytics_dbt/` — Feature Data Model Construction

The [analytics_dbt](analytics_dbt) folder contains a dbt project responsible for transforming raw and intermediate data into curated, research‑ready feature datasets.  This component must be run prior to the machine learning code described in the next component.

This includes:
- Data cleaning and standardization
- Feature derivation using SQL‑based transformations
- Data quality tests and documentation
- Creation of feature marts intended for downstream modeling

---

### `ml/` — Machine Learning Model Development

The [ml](ml) folder contains code to build, train, and evaluate predictive machine learning models using the feature datasets produced by the dbt project.

This includes:
- Feature ingestion from dbt‑produced tables or exports
- Model training and evaluation pipelines

---

## License and Acknowledgments

Unless otherwise noted, the code in this repository is licensed under the MIT License.  See the [LICENSE](LICENSE) for details.

Funding and institutional acknowledgments are detailed in the [NOTICE](NOTICE) file.

Third‑party dependencies are licensed under their respective terms.
