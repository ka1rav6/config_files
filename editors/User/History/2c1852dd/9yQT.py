"""Integration tests for bookmarks: toggle, state, and the Saved page."""
import asyncio

import pytest

from app.models.post import Post
from app.models.user import User, UserRole
from app.repositories.bookmarks import BookmarkRepository
from tests.helpers import auth_headers


def _publish_post(client, headers: dict, title: str = "Bookmark me") -> str:
    """Create a draft via the API and publish it; return its public_id."""
    created = client.post(
        "/api/v1/posts", json={"title": title, "content": "Body"}, headers=headers
    ).json()
    client.put(f"/api/v1/posts/{created['public_id']}/publish", headers=headers)
    return created["public_id"]


# --- toggling ----------------------------------------------------------------


def test_anonymous_cannot_bookmark(client, session_factory):
    _, author_headers = auth_headers(
        session_factory, role=UserRole.AUTHOR, username="author", email="author@x.com"
    )
    pid = _publish_post(client, author_headers)
    assert client.put(f"/api/v1/posts/{pid}/bookmark").status_code == 401


def test_bookmark_toggle_on_and_off(client, session_factory):
    _, author_headers = auth_headers(
        session_factory, role=UserRole.AUTHOR, username="author", email="author@x.com"
    )
    pid = _publish_post(client, author_headers)

    _, headers = auth_headers(
        session_factory, role=UserRole.USER, username="reader", email="reader@x.com"
    )
    on = client.put(f"/api/v1/posts/{pid}/bookmark", headers=headers)
    assert on.status_code == 200
    assert on.json() == {"bookmarked": True}

    # A second toggle removes the bookmark.
    off = client.put(f"/api/v1/posts/{pid}/bookmark", headers=headers)
    assert off.json() == {"bookmarked": False}


def test_bookmark_state_endpoint(client, session_factory):
    _, author_headers = auth_headers(
        session_factory, role=UserRole.AUTHOR, username="author", email="author@x.com"
    )
    pid = _publish_post(client, author_headers)

    _, headers = auth_headers(
        session_factory, role=UserRole.USER, username="reader", email="reader@x.com"
    )
    assert client.get(f"/api/v1/posts/{pid}/bookmark", headers=headers).json() == {
        "bookmarked": False
    }
    client.put(f"/api/v1/posts/{pid}/bookmark", headers=headers)
    assert client.get(f"/api/v1/posts/{pid}/bookmark", headers=headers).json() == {
        "bookmarked": True
    }


def test_cannot_bookmark_a_private_draft(client, session_factory):
    _, author_headers = auth_headers(
        session_factory, role=UserRole.AUTHOR, username="author", email="author@x.com"
    )
    draft = client.post("/api/v1/posts", json={"title": "Secret"}, headers=author_headers).json()

    _, headers = auth_headers(
        session_factory, role=UserRole.USER, username="reader", email="reader@x.com"
    )
    response = client.put(f"/api/v1/posts/{draft['public_id']}/bookmark", headers=headers)
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_bookmark_upsert_is_atomic(session_factory):
    """Simulate concurrent toggles and ensure at most one insertion occurs."""
    async with session_factory() as session:
        user = User(username="raceuser", email="race@x.com", password_hash="x", role=UserRole.USER)
        session.add(user)
        await session.commit()
        await session.refresh(user)

        post = Post(title="Race", author_id=user.id)
        session.add(post)
        await session.commit()
        await session.refresh(post)

    async def toggle_bookmark() -> bool:
        async with session_factory() as session:
            repo = BookmarkRepository(session)
            return await repo.upsert(user.id, post.id)

    results = await asyncio.gather(*(toggle_bookmark() for _ in range(8)))

    # Exactly one of the concurrent attempts should create the bookmark.
    assert sum(1 for r in results if r) == 1


# --- the Saved page ----------------------------------------------------------


def test_my_bookmarks_lists_saved_posts_newest_first(client, session_factory):
    _, author_headers = auth_headers(
        session_factory, role=UserRole.AUTHOR, username="author", email="author@x.com"
    )
    first = _publish_post(client, author_headers, "First post")
    second = _publish_post(client, author_headers, "Second post")

    _, headers = auth_headers(
        session_factory, role=UserRole.USER, username="reader", email="reader@x.com"
    )
    # Save both; the second save happens later, so it sorts first.
    client.put(f"/api/v1/posts/{first}/bookmark", headers=headers)
    client.put(f"/api/v1/posts/{second}/bookmark", headers=headers)

    page = client.get("/api/v1/users/me/bookmarks", headers=headers)
    assert page.status_code == 200
    body = page.json()
    assert body["total"] == 2
    assert [p["title"] for p in body["items"]] == ["Second post", "First post"]
    # List items do not leak article content.
    assert "content" not in body["items"][0]


def test_my_bookmarks_ignores_posts_that_were_unsaved(client, session_factory):
    _, author_headers = auth_headers(
        session_factory, role=UserRole.AUTHOR, username="author", email="author@x.com"
    )
    pid = _publish_post(client, author_headers)

    _, headers = auth_headers(
        session_factory, role=UserRole.USER, username="reader", email="reader@x.com"
    )
    client.put(f"/api/v1/posts/{pid}/bookmark", headers=headers)
    client.put(f"/api/v1/posts/{pid}/bookmark", headers=headers)  # unsave

    page = client.get("/api/v1/users/me/bookmarks", headers=headers).json()
    assert page["total"] == 0
    assert page["items"] == []


def test_my_bookmarks_is_private_to_the_user(client, session_factory):
    _, author_headers = auth_headers(
        session_factory, role=UserRole.AUTHOR, username="author", email="author@x.com"
    )
    pid = _publish_post(client, author_headers)

    _, alice_headers = auth_headers(
        session_factory, role=UserRole.USER, username="alice", email="alice@x.com"
    )
    client.put(f"/api/v1/posts/{pid}/bookmark", headers=alice_headers)

    # Bob's saved page does not show Alice's bookmarks.
    _, bob_headers = auth_headers(
        session_factory, role=UserRole.USER, username="bob", email="bob@x.com"
    )
    page = client.get("/api/v1/users/me/bookmarks", headers=bob_headers).json()
    assert page["total"] == 0
