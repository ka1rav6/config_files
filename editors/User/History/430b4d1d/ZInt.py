
class Submission(Base):
    __tablename__ = "submissions"

    id: Mapped[int] = mapped_column(primary_key=True)

    assignment_id: Mapped[int] = mapped_column(
        ForeignKey("assignments.id")
    )

    student_id: Mapped[int] = mapped_column(
        ForeignKey("users.id")
    )

    submitted_at: Mapped[datetime]

    grade: Mapped[float | None]

    feedback: Mapped[str | None]

    files = relationship(
        "SubmissionFile",
        back_populates="submission",
        cascade="all, delete-orphan"
    )