from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError, ExpiredSignatureError
from config import JWT_SECRET, JWT_ALGORITHM, get_supabase

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    token = credentials.credentials
    supabase = get_supabase()
    
    try:
        response = supabase.auth.get_user(token)
        user = response.user
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid authentication token")

    if not user:
        raise HTTPException(status_code=401, detail="Account not found in Supabase Auth")

    # Check if they exist in web_users (migrated users or web signups)
    result = supabase.table("web_users").select("*").eq("id", user.id).execute()

    if not result.data:
        # User exists in Supabase Auth but not web_users (e.g., signed up via mobile app)
        metadata = user.user_metadata or {}
        return {
            "id": user.id,
            "user_id": metadata.get("user_id", "MOBILE_USER"),
            "email": user.email,
            "user_type": metadata.get("user_type", "volunteer"),
            "full_name": metadata.get("full_name", ""),
            "nickname": metadata.get("nickname", ""),
        }

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
