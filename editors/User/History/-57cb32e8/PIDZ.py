from enum import Enum, auto
from pydantic import EmailStr
class Role(Enum):
    ADMIN = auto()
    TEACHER = auto()
    TA = auto()
    STUDENT = auto()
    
class BaseUser:
    username:str
    __password:str
    email:EmailStr
    role:Role
        
    def __init__(self, username:str, password:str|None = None, email:EmailStr|None = None, role:Role = Role.STUDENT) -> None:
        