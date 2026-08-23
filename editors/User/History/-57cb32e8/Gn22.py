from enum import Enum, auto

class Role(Enum):
    ADMIN = auto()
    TEACHER = auto()
    TA = auto()
    STUDENT = auto()
    
class BaseUser:
    username:str
    __password:str
    email:str
    role:Role
        
    def __init__(self, username, p) -> None:
        pass