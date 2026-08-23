from fastapi import FastAPI
from .routers import router
from pydantic_settings import BaseSettings, SettingsConfigDict

############### CONFIG ###############
class Settings(BaseSettings):
    app_name: str = "IIITD LMS"
    debug: bool = True
    DATABASE_URL: str # TODO
    model_config = SettingsConfigDict(env_file=".env")

settings = Settings()
app = FastAPI(
    title=settings.app_name,
    debug=settings.debug,
    version="1.0.0",
)


@app.get("/health")
async def health_check():
    return {"status": "healthy"}


app.include_router(router)