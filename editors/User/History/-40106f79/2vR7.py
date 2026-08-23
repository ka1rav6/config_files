# models/Lecture.py

from datetime import datetime

from sqlalchemy import String, ForeignKey, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base


class Lecture(Base):
    __tablename__ = "lectures"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(100))
    description: Mapped[str | None] = mapped_column(String(500))
    uploaded_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    course_id: Mapped[int] = mapped_column(ForeignKey("courses.id"))
    uploaded_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    file_path: Mapped[str] = mapped_column(String(500))
    course = relationship("Course")
    uploader = relationship("User")