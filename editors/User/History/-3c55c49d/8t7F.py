import streamlit as st
import pandas as pd

st.write("hello world")
st.title("Hello")

df = pd.read_excel("/home/kairav/dev/tries/papa/schedule.xlsx", sheet_name="ScheduleForAnalysis")
st.write(df.describe())
st.write(df.head(10))
