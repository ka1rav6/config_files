from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .routers import router
from pydantic_settings import BaseSettings, SettingsConfigDict


############### CONFIG ###############
class Settings(BaseSettings):
    app_name: str = "IIITD LMS"
    debug: bool = True
    DB_NAME: str
    DB_USER: str
    DB_PASS: str
    DB_PORT: int
    DB_HOST: str
    SECRET_KEY: str = "change-this-secret-key-LATER"
    model_config = SettingsConfigDict(env_file=".env")

settings = Settings() #type: ignore

app = FastAPI(
    title=settings.app_name,
    debug=settings.debug,
    version="1.0.0",
)

# ---- CORS ----
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://localhost:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health_check():
    return {"status": "healthy"}
## localhost:5050/health
app.include_router(router)