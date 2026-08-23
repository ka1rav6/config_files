# database.py

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv
load_dotenv()
import os
db_user = os.loadenv
DATABASE_URL = (
    f"postgresql://classroom_user:"
    f"password@localhost/classroom"
)

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)