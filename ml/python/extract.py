# extract the entire table from the datamart into a parquet file

import sqlalchemy
import os
from dotenv import load_dotenv
import pandas as pd

load_dotenv('.env', override=True)

if (__name__ == "__main__"):
    # this assumes using windows authentication
    # if you have pyodbc, use this
    connection_string = f"mssql+pyodbc://@{os.getenv('HOSTNAME')}/{os.getenv('DATABASE')}?trusted_connection=yes&driver=ODBC+Driver+17+for+SQL+Server"
    # if you have pymssql, use this
    # connection_string = f"mssql+pymssql://@{os.getenv('HOSTNAME')}/{os.getenv('DATABASE')}"
    engine = sqlalchemy.create_engine(connection_string)

    reports = {
        # 'rpt_preeclampsia': 'preeclampsia/preeclampsia_all_features.parquet',
        # 'rpt_depression': 'ppd/depression_all_features.parquet',
        'rpt_surgical_site_infection': 'ssi/ssi_all_features.parquet',
        # 'rpt_surgical_site_infection_30_days': 'ssi/ssi_all_features_30_days.parquet',
        # 'int_ssi__unique_raw_dx_to_cmqcc': 'ssi/raw_dx_cmqcc_mapping.parquet',
        # 'rpt_ssi__check_diabetes': 'ssi/ssi_check_diabetes.parquet'
    }

    for report_table, output_parquet_file in reports.items():
        sql_string = f'''
        select
          *
        from {os.getenv('DATABASE')}.{os.getenv('SCHEMA')}.{report_table}
        '''
        print(f"transfering {report_table} from database")
        dat = pd.read_sql(sql_string, con=engine)
        print(f"dat shape: {dat.shape}")
        dat.to_parquet(output_parquet_file, index=False)
