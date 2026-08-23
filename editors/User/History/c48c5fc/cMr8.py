# Course.py

from sqlalchemy import String
from sqlalchemy import Integer
from sqlalchemy import ForeignKey
from sqlalchemy import Enum as SQLEnum

from sqlalchemy.orm import Mapped
from sqlalchemy.orm import mapped_column
from sqlalchemy.orm import relationship

from .base import Base
from .base import Semester


class Course(Base):
    __tablename__ = "courses"

    id: Mapped[int] = mapped_column( primary_key=True)

    code: Mapped[str] = mapped_column( String(20))

    name: Mapped[str] = mapped_column( String(100))

    credits: Mapped[int] = mapped_column( Integer)

    semester: Mapped[Semester] = mapped_column( SQLEnum(Semester))

    teacher_id: Mapped[int] = mapped_column( ForeignKey("users.id"))

    teacher = relationship( "User")