# User.py

from sqlalchemy import String
from sqlalchemy import Enum as SQLEnum

from sqlalchemy.orm import Mapped
from sqlalchemy.orm import mapped_column

from .base import Base
from .base import Role


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column( primary_key=True)
    
    firstName: Mapped[str] = mapped_column(String(255))
    lastName: Mapped[str] = mapped_column(String(255))
    
    username: Mapped[str] = mapped_column( String(50),unique=True)
    email: Mapped[str] = mapped_column( String(255),unique=True)
    password_hash: Mapped[str] = mapped_column( String(255))
    role: Mapped[Role] = mapped_column( SQLEnum(Role))