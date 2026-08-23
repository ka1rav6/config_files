# models/Course.py

from sqlalchemy import String, Integer, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, Semester, TimestampMixin


class Course(TimestampMixin, Base):
    __tablename__ = "courses"
    id: Mapped[int] = mapped_column(primary_key=True)
    code: Mapped[str] = mapped_column(String(20))
    name: Mapped[str] = mapped_column(String(100))
    credits: Mapped[int] = mapped_column(Integer)
    semester: Mapped[Semester] = mapped_column(SQLEnum(Semester))
    teacher_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    teacher = relationship("User")

    def __repr__(self) -> str:
        return f"<Course(id={self.id}, code={self.code}, name={self.name})>"