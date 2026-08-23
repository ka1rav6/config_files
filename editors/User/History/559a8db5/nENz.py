"""Data access for comment reports and unique report tracking."""
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.comment_report import CommentReport


class CommentReportRepository:
    """Wraps report persistence logic for comments."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def add_report(self, comment_id: int, reporter_id: int) -> bool:
        """Insert a report record if none exists already.

        Returns True if the report was created, False if the user already
        reported this comment.
        """
        stmt = (
            pg_insert(CommentReport)
            .values(comment_id=comment_id, reporter_id=reporter_id)
            .on_conflict_do_nothing(index_elements=["comment_id", "reporter_id"])
        )
        result = await self._session.execute(stmt)
        return result.rowcount == 1
