from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from dotenv import load_dotenv

import os

load_dotenv()

DATABASE_URL = (
    f"postgresql+psycopg://"
    f"{os.getenv('DB_USER')}:{os.getenv('DB_PASS')}"
    f"@{os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', 5432)}"
    f"/{os.getenv('DB_NAME', 'classroom')}"
)

engine = create_engine(
    DATABASE_URL, echo=os.getenv("DEBUG", "true").lower() == "true"
)

SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()