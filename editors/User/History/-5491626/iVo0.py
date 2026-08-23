import streamlit as st
import pandas as pd

st.write("hello world")

df = pd.read_excel("/home/kairav/dev/tries/papa/schedule.xlsx", sheet_name="Re")
st.write(df.describe())
