# database.py

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv
import os

load_dotenv()

db_user = os.getenv("DB_USER")
db_pass = os.getenv("DB_PASS")

DATABASE_URL = (
    f"postgresql+psycopg://"
    f"{db_user}:{db_pass}"
    "@localhost/classroom"
)

engine = create_engine(
    DATABASE_URL,
    echo=True,  # shows generated SQL
)

SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False
)

