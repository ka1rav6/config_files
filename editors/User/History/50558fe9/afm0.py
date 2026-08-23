import pandas as pd

df = pd.read_excel("schedule.xlsx", sheet_name="RawSchedule")

print(df.head(10))