
import pandas as pd
from datetime import datetime, timedelta

def getRollingSum():
    result = {}
    items = sorted(myDict.items())
    for current_time, bla in items:
        cutoff = current_time - timedelta(minutes=INTERVAL)
        total = []
        for ts, val in items:
            if cutoff <= ts <= current_time:
                total.append(val)
        result[ts] = (int(sum(total)))
    return result


INTERVAL = 10
FILE:str = "schedule.xlsx"

df = pd.read_excel("schedule.xlsx", sheet_name="ScheduleForAnalysis", skiprows = 1)

df["SDTD"] = pd.to_datetime(df["SDTD"])


start_time = df["SDTD"].iloc[0]
end_time = df["SDTD"].iloc[-1]


total_interval = end_time - start_time
myDict = {}
for k,v in zip(df["SDTD"], df["NO.OF Y SEATS"]):
    myDict[k] = v

i = start_time
while (i < end_time):
    i+= timedelta(minutes=INTERVAL)
    myDict.setdefault(i , 0)
  
    

rolledSum = pd.Series(getRollingSum())

import matplotlib.pyplot as plt

# BYPASS THE ERROR: Plot columns manually using matplotlib
plt.figure()
plt.plot(rolledSum.keys(), rolledSum.values(), label="rollSum")
plt.xlabel("SDTD")
plt.ylabel("Value")
plt.legend()
plt.show()    
