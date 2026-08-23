# database.py

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv
load_dotenv()
import os
db_user = os.getenv("DB_USER")
db_pass = os.getenv("DB_PASS")
DATABASE_URL = (
    f"postgresql://{db_user}:"
    f"{db_pass}@localhost/classroom"
)

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)