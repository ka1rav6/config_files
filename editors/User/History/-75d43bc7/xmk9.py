
from fastapi import APIRouter

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
