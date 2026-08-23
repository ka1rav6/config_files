import numpy as np
import scipy.optimize as so
import pandas as pd


def generate_random_marks():
    return np.random.randint(0, 100)


if __name__ == "__main__":
    STUDENT_NUM = 100
    df = pd.DataFrame()
    df["student_id"] = list(range(0, 500))
    