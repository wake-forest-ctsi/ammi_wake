# Analytics

## Overview

This dbt project builds a semantic layer over top of an existing [PCORnet](https://pcornet.org/data/common-data-model/) data model to support downstream machine learning tasks.  The feature models are organized around clinical phenotypes such as preeclampsia, postpartum depression, and surgical site infection.

The grain of each feature model is the birthid and the feature name in a "long" table format to support the training of models with a large number of candidate features.

## Configuration

### Install DBT

Unless already installed, you will need to [install dbt](https://docs.getdbt.com/docs/local/install-dbt) and an [adapter](https://docs.getdbt.com/docs/supported-data-platforms) that supports your target database.  Unless you are using dbt fusion, it is highly recommended to activate a local virtual environment in this folder 

```bash
python3 -m venv .venv
source .venv/bin/activate
```

### Install dbt package dependencies

This project uses several [dbt packages](https://docs.getdbt.com/docs/build/packages) in the [packages.yml](packages.yml) which must be installed before the tables can be built.

```bash
dbt deps
```

### Create a Connection

DBT runs sql on a target database where the user has permissions to create new tables and can read from the necessary source tables.  Before you can connect to your database, you must set up a target in your [profiles.yml](https://docs.getdbt.com/docs/local/profiles.yml) for the ammi profile.

```bash
ammi:  # Profile name (matches dbt_project.yml)
  target: dev  # Default target to use
  outputs:
    dev: # Development environment
      type: adapter_type # Required: snowflake, bigquery, databricks, redshift, postgres, etc
      # Connection identifiers (placeholder examples, see adapter-specific pages for supported configs)
      account: abc123  
      database: docs_team 
      schema: dev_schema       
      # Authentication (adapter-specific)
      auth_method: username_password  
      username: username
      password_credentials: password
      # Execution settings (common across adapters)
      threads: 4   # Number of parallel threads
```

Test that you connection is working by running the debug command and look for a successful output message.

```bash
dbt debug
```

## Build the Data Models

To build every phenotype and run any accompanying tests on the data model, run the build command.

```bash
dbt build
```

If you only wish to build a specific phenotype you can select that phenotype to have dbt build it and any models it depends on.

```bash
dbt build --select "+models/07_reports/depression/+"
```

### View the Feature Models
Connect to your target database and select from your phenotype of interest.  The feature models are prefixed with `_rpt` and materialized as tables by default.

```sql
select * from rpt_preeclampsia;
```


## Additional Resources

- **[dbt Documentation](https://docs.getdbt.com/docs/introduction)**: Official documentation for dbt.
