#!/usr/bin/env python
# coding: utf-8

# In[1]:


from sqlalchemy import create_engine, text, MetaData, Table, Column, Integer, String, ForeignKey,inspect
import pandas as pd
from db.db import db, Conversation, Message, SenderType
from flask import Flask


# In[2]:


# Initialize the Flask app and SQLAlchemy
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///conversations.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db.init_app(app)

# Create an application context
app.app_context().push()

# Query all conversations
conversations = Conversation.query.all()

# Access and print the attributes of each conversation
for conversation in conversations:
    print(f"ID: {conversation.id}, User ID: {conversation.user_id}, Created At: {conversation.created_at}")


# In[6]:


# Query all messages
messages = Message.query.all()

for message in messages:
    print(f"ID: {message.id}, Conversation ID: {message.conversation_id}, Sender Type: {message.sender_type}, Content: {message.content}")


# In[5]:


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


# In[7]:


# Write the DataFrame to a SQL table
table_names = ['users', 'stories', 'prompts']
dataframes = [user_df, story_df, prompt_df]
for table_name, df in zip(table_names, dataframes):
    df.to_sql(table_name, con=engine, if_exists='append')


# In[8]:


# Use the inspector to get table information
inspector = inspect(engine)
tables = inspector.get_table_names()
print(tables)


# In[ ]:


connection.close()

