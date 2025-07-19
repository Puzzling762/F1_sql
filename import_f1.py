import os
import pandas as pd
import mysql.connector

# ✅ CONFIG: MySQL Login Info
db_config = {
    'host': 'localhost',
    'user': 'root',
    'password': 'root',
    'database': 'f1_analytics'
}

# ✅ All CSV files stored in datasets/
csv_folder = 'datasets'
csv_files = {
    'circuits': 'circuits.csv',
    'constructor_results': 'constructor_results.csv',
    'constructor_standings': 'constructor_standings.csv',
    'constructors': 'constructors.csv',
    'driver_standings': 'driver_standings.csv',
    'drivers': 'drivers.csv',
    'lap_times': 'lap_times.csv',
    'pit_stops': 'pit_stops.csv',
    'qualifying': 'qualifying.csv',
    'races': 'races.csv',
    'results': 'results.csv',
    'seasons': 'seasons.csv',
    'sprint_results': 'sprint_results.csv',
    'status': 'status.csv'
}

# ✅ Connect to MySQL
conn = mysql.connector.connect(**db_config)
cursor = conn.cursor()

# ✅ Function to infer MySQL data types from pandas dtypes
def infer_mysql_dtype(dtype):
    if pd.api.types.is_integer_dtype(dtype):
        return 'INT'
    elif pd.api.types.is_float_dtype(dtype):
        return 'FLOAT'
    elif pd.api.types.is_datetime64_any_dtype(dtype):
        return 'DATETIME'
    else:
        return 'TEXT'

# ✅ Loop over each CSV and import
for table_name, file_name in csv_files.items():
    path = os.path.join(csv_folder, file_name)
    print(f'🚀 Importing `{file_name}` into `{table_name}`...')

    try:
        df = pd.read_csv(path)

        # 🧼 Clean column names
        df.columns = [col.strip().replace(' ', '_').replace('-', '_') for col in df.columns]

        # 🧹 Drop existing table if it exists
        cursor.execute(f"DROP TABLE IF EXISTS `{table_name}`;")

        # 🧱 Build CREATE TABLE query
        columns_def = ', '.join([f"`{col}` {infer_mysql_dtype(df[col])}" for col in df.columns])
        create_query = f"CREATE TABLE `{table_name}` ({columns_def});"
        cursor.execute(create_query)

        # 📥 Insert data row-by-row
        for _, row in df.iterrows():
            placeholders = ', '.join(['%s'] * len(row))
            insert_query = f"INSERT INTO `{table_name}` VALUES ({placeholders});"
            cursor.execute(insert_query, tuple(row))

        conn.commit()
        print(f'✅ Imported {len(df)} rows into `{table_name}`')

    except Exception as e:
        print(f'❌ Failed to import `{file_name}`: {e}')

# 🔒 Close connections
cursor.close()
conn.close()

print('\n🎯 All datasets imported successfully into MySQL!')
