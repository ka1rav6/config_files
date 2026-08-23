
from fastapi import APIRouter

router = APIRouter(prefix="/users", tags=["Users"])

@router.post("/register")
def register():
    return {"message": "Register User"}

# app/routers/users.py

from fastapi import APIRouter

router = APIRouter(
    prefix="/users",
    tags=["Users"]
)