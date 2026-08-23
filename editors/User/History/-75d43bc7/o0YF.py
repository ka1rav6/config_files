
from fastapi import APIRouter
from sqlalchemy.orm import Session
from fastapi import Depends
from backend.database.database import get_db
from backend.models.User import User


router = APIRouter(prefix="/users", tags=["Users"])

@router.post("/register")
def register(username: str, email: str, password: str, db: Session = Depends(get_db)):
    user = User(
        username=username,
        email=email,
        password_hash=password
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return user

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
    db: Session = Depends(get_db)):
    user = db.get(User, user_id)
    return user
