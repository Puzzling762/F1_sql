import mysql.connector
from mysql.connector import Error
import os

def create_all_f1_views():
    try:
        # Database connection parameters
        connection = mysql.connector.connect(
            host='localhost',  # Change as needed
            database='f1_analytics',
            user='root',  # Change to your username
            password='root'  # Change to your password
        )
        
        if connection.is_connected():
            cursor = connection.cursor()
            
            # Read the SQL file
            with open('f1_views.sql', 'r') as file:
                sql_script = file.read()
            
            # Split the script into individual statements
            statements = sql_script.split(';')
            
            # Execute each statement
            for i, statement in enumerate(statements):
                if statement.strip():
                    try:
                        cursor.execute(statement)
                        print(f"✓ Statement {i+1} executed successfully")
                    except Error as e:
                        print(f"✗ Error in statement {i+1}: {e}")
                        continue
            
            # Commit changes
            connection.commit()
            
            # Verify views were created
            cursor.execute("""
                SELECT TABLE_NAME 
                FROM information_schema.TABLES 
                WHERE TABLE_SCHEMA = 'f1_analytics' 
                    AND TABLE_TYPE = 'VIEW'
                ORDER BY TABLE_NAME
            """)
            
            views = cursor.fetchall()
            print(f"\n✓ Successfully created {len(views)} views:")
            for view in views:
                print(f"  - {view[0]}")
                
    except Error as e:
        print(f"Error while connecting to MySQL: {e}")
    
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()
            print("\n✓ MySQL connection closed")

if __name__ == "__main__":
    create_all_f1_views()