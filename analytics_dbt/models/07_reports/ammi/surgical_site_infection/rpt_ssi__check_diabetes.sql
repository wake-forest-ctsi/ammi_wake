select
    *
from {{ ref('int_ssi__phenotype') }}

union all

select
    *
from {{ ref('int_ssi__glucose') }}