from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError, ExpiredSignatureError
from config import JWT_SECRET, JWT_ALGORITHM, get_supabase

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    token = credentials.credentials
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid authentication token")

    if payload.get("type") != "access":
        raise HTTPException(status_code=401, detail="Invalid token type")

    user_id = payload.get("user_id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Malformed token payload")

    supabase = get_supabase()
    result = supabase.table("web_users").select("*").eq("user_id", user_id).execute()

    if not result.data:
        raise HTTPException(status_code=401, detail="Account not found")

    return result.data[0]


async def require_organizer(
    current_user: dict = Depends(get_current_user),
):
    if current_user.get("user_type") != "organizer":
        raise HTTPException(status_code=403, detail="Organizer access required")
    return current_user


async def require_volunteer(
    current_user: dict = Depends(get_current_user),
):
    if current_user.get("user_type") != "volunteer":
        raise HTTPException(status_code=403, detail="Volunteer access required")
    return current_user


async def require_user(
    current_user: dict = Depends(get_current_user),
):
    if current_user.get("user_type") != "user":
        raise HTTPException(status_code=403, detail="User access required")
    return current_user
