
import pandas as pd
from datetime import datetime, timedelta
def getRollingSum():
    result = []
    items = sorted(myDict.items())
    for current_time, bla in items:
        cutoff = current_time - timedelta(minutes=INTERVAL)
        total = []
        for ts, val in items:
            if cutoff <= ts <= current_time:
                total.append(val)
        result.append(int(sum(total)))
    return result


INTERVAL = 10
FILE:str = "schedule.xlsx"

df = pd.read_excel("schedule.xlsx", sheet_name="ScheduleForAnalysis", skiprows = 1)

for i in range(len(df)):
    df.loc[i, "SDTD"] = df.loc[i, "SDTD"].to_pydatetime()
    
start_time = df["SDTD"][0].to_pydatetime()
end_time = df["SDTD"][len(df["SDTD"] - 1)].to_pydatetime()

total_interval = end_time - start_time
myDict = {}
for k,v in zip(df["SDTD"], df["NO.OF Y SEATS"]):
    myDict[k] = v

i = start_time
while (i != end_time):
    myDict.setdefault(i + timedelta(minutes=INTERVAL), 0)
  
    

df["rollSum"] = pd.Series(getRollingSum())

import matplotlib.pyplot as plt

newdf = df[["SDTD", "rollSum"]]
print(type(newdf["SDTD"][0]))

# BYPASS THE ERROR: Plot columns manually using matplotlib
plt.figure()
plt.plot(newdf["SDTD"], newdf["rollSum"], label="rollSum")
plt.xlabel("SDTD")
plt.ylabel("Value")
plt.legend()
plt.show()    
