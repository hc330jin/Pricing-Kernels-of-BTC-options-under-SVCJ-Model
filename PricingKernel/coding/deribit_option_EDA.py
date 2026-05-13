import sys
from collections import deque
import pandas as pd
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
folder_path = os.path.join(BASE_DIR, '..', 'data')

file_path = os.path.join(folder_path, 'Deribit_20220101_20220131.csv')

df = pd.read_csv(file_path)

print(df.tail())

print(df.head())