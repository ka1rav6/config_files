from enum import Enum, auto
from pydantic import EmailStr, validate_email
class Role(Enum):
    ADMIN = auto()
    TEACHER = auto()
    TA = auto()
    STUDENT = auto()
    
class BaseUser:
    username:str
    __password:str | None
    email:EmailStr | None # treating it as a UID too
    role:Role
        
    def __init__(self, username:str, password:str|None = None, email:EmailStr|None = None, role:Role = Role.STUDENT) -> None:
        self.username = username
        self.__password = password
        validate_email(email)
        self.email = email
        self.role = role
    def changePassword(self, newPassword:str) -> None:
        self.__password = newPassword
        
        ########## UPDATE IN THE DATABASE ############
    
    def viewDocument(self, docName:str):
        pass
    def downloadDocument(self, docName:str):
        pass

class Semester(Enum):
    MONSOON = auto()
    SUMMER = auto()
    WINTER = auto()
    
    
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