from sqlalchemy import create_engine
import pandas as pd

# Create the engine
engine = create_engine('sqlite:///conversations.db')

# Test the connection (optional)
try:
    connection = engine.connect()
    print("Connection successful!")
except Exception as e:
    print(f"Connection failed: {e}")

# Create a df in pandas to write to SQL the schema of the tables we need to store the data
user_data = {
    'userId':[],
    'username':[],
    'age':[]
}

story_request_data = {
    'userId':[],
    'storyId':[],
    'title':[],
    'prompt':[],
    'vocabulary':[]
}

meta_prompting_data = {
    'storyId':[],
    'meta_prompt':[],
    'novel_prompt':[]
}

user_df = pd.DataFrame(user_data)
story_df = pd.DataFrame(story_request_data)
prompt_df = pd.DataFrame(meta_prompting_data)

# Write the DataFrame to a SQL table
table_names = ['users', 'stories', 'prompts']
dataframes = [user_df, story_df, prompt_df]
for table_name, df in zip(table_names, dataframes):
    df.to_sql(table_name, con=engine, if_exists='replace')