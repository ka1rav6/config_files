import pandas as pd
df1 = pd.read_csv("data1.csv")
df2 = pd.read_csv("data2.csv")
df = df1 + df2
print(df)