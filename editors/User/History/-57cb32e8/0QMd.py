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
    
    
from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase):
    pass
