
from fastapi import APIRouter
from sqlalchemy.orm import Session
from fastapi import Depends

from backend.database.database import get_db


router = APIRouter(prefix="/users", tags=["Users"])

@router.post("/register")
def register():
    return {"message": "Register User"}

@router.post("/login")
def login():
    return {"message": "Login user"}

@router.get("/me")
def get_me():
    return {"message": "Current user"}

@router.get("/")
def get_users():
    return {"message": "All users"}

@router.get("/{user_id}")
def get_user(user_id: int):
    return {"user_id": user_id}

@router.get("/{user_id}")
def get_user(
    user_id: int,
    db: Session = Depends(get_db)
):
    user = db.get(User, user_id)

    return user