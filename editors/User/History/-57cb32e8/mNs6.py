from enum import Enum

from sqlalchemy.orm import DeclarativeBase


class Role(str, Enum):
    ADMIN = "admin"
    TEACHER = "teacher"
    TA = "ta"
    STUDENT = "student"


class Semester(str, Enum):
    MONSOON = "monsoon"
    SUMMER = "summer"
    WINTER = "winter"

iveBase):
    pass
class Base(Declarat