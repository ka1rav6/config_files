import streamlit as st
import pandas as pd

st.write("hello world")

df = pd.read_csv("/home/kairav/dev/tries/papa/schedule.xlsx")
st.write(df.describe())
