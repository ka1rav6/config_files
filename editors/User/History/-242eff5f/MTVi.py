import numpy as np
import pandas as pd

STUDENT_NUM = 500

df = pd.DataFrame({
    "student_id": np.arange(STUDENT_NUM),
    "marks": np.random.randint(0, 100, size=STUDENT_NUM)
})

df.to_csv("students.csv", index=False)
print(df.head())
