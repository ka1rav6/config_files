# models/Assignment.py

from datetime import datetime

from sqlalchemy import String, Float, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, TimeStamp


class Assignment(TimeStamp, Base):
    __tablename__ = "assignments"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    instructions: Mapped[str | None] = mapped_column(String(500), nullable=True)
    marks: Mapped[float] = mapped_column(Float)
    submission_deadline: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    course_id: Mapped[int] = mapped_column(ForeignKey("courses.id"))
    course = relationship("Course")

    def __repr__(self) -> str:
        return f"<Assignment(id={self.id}, name={self.name}, course_id={self.course_id})>"