"""Bookmark data access — the saved-posts list and toggle state."""
from sqlalchemy import delete, func, select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.bookmark import Bookmark
from app.models.post import Post

# Relations to load on the bookmarked posts so the list response schema can
# render author/tags/category without extra queries (same set as PostRepository).
_RELATIONS = (
    selectinload(Post.tags),
    selectinload(Post.category),
    selectinload(Post.author),
)


class BookmarkRepository:
    """Thin wrapper over an async session for bookmark queries."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, user_id: int, post_id: int) -> Bookmark | None:
        """Return the bookmark row for a (user, post) pair, if it exists."""
        stmt = select(Bookmark).where(
            Bookmark.user_id == user_id, Bookmark.post_id == post_id
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def upsert(self, user_id: int, post_id: int) -> bool:
        """Insert a bookmark if it doesn't exist; delete if it does.

        Returns True when the bookmark was created, False when it was removed.
        This atomic operation avoids the check-then-act race condition.
        """
        # Use a single SQL statement (CTE) that inserts when absent or deletes
        # when present. Doing it in one statement avoids cross-transaction
        # races where one request inserts while another deletes.
        sql = text(
            """
            WITH ins AS (
              INSERT INTO bookmarks (user_id, post_id)
              VALUES (:user_id, :post_id)
              ON CONFLICT DO NOTHING
              RETURNING 1 AS created
            ), del AS (
              DELETE FROM bookmarks
              WHERE user_id = :user_id AND post_id = :post_id
              AND NOT EXISTS (SELECT 1 FROM ins)
              RETURNING 0 AS created
            )
            SELECT COALESCE((SELECT created FROM ins LIMIT 1), (SELECT created FROM del LIMIT 1)) AS created
            """
        )
        result = await self._session.execute(sql, {"user_id": user_id, "post_id": post_id})
        created = result.scalar_one()
        await self._session.commit()
        return bool(created)

    async def saved_posts(
        self, user_id: int, *, page: int, size: int
    ) -> tuple[list[Post], int]:
        """Return the reader's saved posts (newest bookmark first) plus total.

        The list is ordered by when the reader *saved* the post (Bookmark
        created_at), not by the post's own publish date — "Saved" pages should
        feel like a personal queue.
        """
        total = (
            await self._session.execute(
                select(func.count()).select_from(Bookmark).where(Bookmark.user_id == user_id)
            )
        ).scalar_one()

        stmt = (
            select(Post)
            .join(Bookmark, Bookmark.post_id == Post.id)
            .where(Bookmark.user_id == user_id)
            .options(*_RELATIONS)
            .order_by(Bookmark.created_at.desc(), Post.id.desc())
            .offset((page - 1) * size)
            .limit(size)
        )
        items = list((await self._session.execute(stmt)).scalars().all())
        return items, total
