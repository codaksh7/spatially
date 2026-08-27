from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from contextlib import asynccontextmanager
import bcrypt

load_dotenv()

from config import get_supabase, FRONTEND_URL
from routes import auth, events, volunteers, dashboard


def hash_password(password: str) -> str:
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")


async def seed_database():
    """Seed initial user accounts if they do not already exist."""
    supabase = get_supabase()

    seed_users = [
        {
            "user_id": "O1",
            "email": "dakshthakkar296@gmail.com",
            "password": "Daksh@123",
            "user_type": "organizer",
            "full_name": "Daksh Thakkar",
            "nickname": "daksh",
        },
        {
            "user_id": "V1",
            "email": "crce.10283.ceb@gmail.com",
            "password": "Daksh@123",
            "user_type": "volunteer",
            "full_name": "Daksh Thakkar",
            "nickname": "daksh_vol",
        },
        {
            "user_id": "V2",
            "email": "crce.10275.ceb@gmail.com",
            "password": "Blaise#26",
            "user_type": "volunteer",
            "full_name": "Blaise Rodrigues",
            "nickname": "blaise",
        },
        {
            "user_id": "U1",
            "email": "aryanverma1750@gmail.com",
            "password": "Aryan@09a",
            "user_type": "user",
            "full_name": "Aryan Verma",
            "nickname": "aryan",
        },
    ]

    for user_data in seed_users:
        existing = (
            supabase.table("web_users")
            .select("user_id")
            .eq("email", user_data["email"])
            .execute()
        )

        if existing.data:
            print(f"[SEED] User {user_data['user_id']} ({user_data['email']}) already exists, skipping")
            continue

        password = user_data.pop("password")
        user_data["password_hash"] = hash_password(password)
        user_data["is_verified"] = True
        user_data["verification_token"] = None

        try:
            supabase.table("web_users").insert(user_data).execute()
            print(f"[SEED] Created {user_data['user_type']} account: {user_data['user_id']} ({user_data['email']})")
        except Exception as e:
            print(f"[SEED] Failed to create {user_data['user_id']}: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("[STARTUP] Spatially API starting...")
    try:
        await seed_database()
        print("[STARTUP] Database seed complete")
    except Exception as e:
        print(f"[STARTUP] Seed failed (database may not be configured): {e}")
    yield
    print("[SHUTDOWN] Spatially API shutting down...")


app = FastAPI(
    title="Spatially API",
    description="Backend API for Spatially — BLE-based crowd intelligence platform",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        FRONTEND_URL,
        "http://localhost:5173",
        "http://127.0.0.1:5173",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(events.router)
app.include_router(volunteers.router)
app.include_router(dashboard.router)


@app.get("/")
def health_check():
    return {"status": "ok", "service": "Spatially API", "version": "1.0.0"}
