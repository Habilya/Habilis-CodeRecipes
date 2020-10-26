-- This script finds all tables where referenced column name was used
select 
TABLE_NAME, 
COLUMN_NAME, 
ORDINAL_POSITION, 
IS_NULLABLE, 
DATA_TYPE, 
CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, DOMAIN_NAME 
from INFORMATION_SCHEMA.COLUMNS  
where left(table_name,3) <> 'Tab' and left(table_name,3) <> 'TCV' 
and COLUMN_NAME = 'COLUMN_NAME'
order by TABLE_NAME