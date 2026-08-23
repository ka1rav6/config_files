from fastapi import FastAPI

from app.config import settings
from app.routers import users

app = FastAPI(
    title=settings.app_name,
    debug=settings.debug,
    version="1.0.0",
)


@app.get("/health")
async def health_check():
    return {"status": "healthy"}


app.include_router(users.router)