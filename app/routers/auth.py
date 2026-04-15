from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from app.auth import hash_password, verify_password, create_access_token, get_current_user
from app.database import get_session
from app.models import User
from app.schemas import RegisterRequest, LoginRequest, TokenResponse, UserResponse

router = APIRouter()


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(req: RegisterRequest, session: Session = Depends(get_session)):
    """Register a new user with name and password."""
    name = req.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Name is required")
    if len(req.password) < 4:
        raise HTTPException(status_code=400, detail="Password must be at least 4 characters")

    existing = session.exec(select(User).where(User.name == name)).first()
    if existing:
        raise HTTPException(status_code=409, detail="Name already taken")

    user = User(name=name, password_hash=hash_password(req.password))
    session.add(user)
    session.commit()
    session.refresh(user)

    token = create_access_token(user.id, user.name)
    return TokenResponse(access_token=token, user_id=user.id, name=user.name)


@router.post("/login", response_model=TokenResponse)
async def login(req: LoginRequest, session: Session = Depends(get_session)):
    """Login with name and password."""
    user = session.exec(select(User).where(User.name == req.name.strip())).first()
    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid name or password")

    token = create_access_token(user.id, user.name)
    return TokenResponse(access_token=token, user_id=user.id, name=user.name)


@router.get("/me", response_model=UserResponse)
async def get_me(user: User = Depends(get_current_user)):
    """Get current authenticated user info."""
    return UserResponse(id=user.id, name=user.name, created_at=user.created_at)
