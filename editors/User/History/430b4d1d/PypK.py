# models/Lecture.py
from datetime import datetime
from sqlalchemy import String, ForeignKey, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from .base import Base


class Submission(Base):
    __tablename__ = "submissions"
    id: Mapped[int] = mapped_column(primary_key=True)
    assignment_id: Mapped[int] = mapped_column(ForeignKey("assignments.id"))
    student_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    submitted_at: Mapped[datetime]
    grade: Mapped[float | None]
    feedback: Mapped[str | None]
    files = relationship("SubmissionFile", back_populates="submission", cascade="all, delete-orphan")

class SubmissionFile(Base):
    __tablename__ = "submission_files"

    id: Mapped[int] = mapped_column(primary_key=True)

    submission_id: Mapped[int] = mapped_column(
        ForeignKey("submissions.id")
    )

    file_name: Mapped[str]

    file_path: Mapped[str]

    submission = relationship(
        "Submission",
        back_populates="files"
    )