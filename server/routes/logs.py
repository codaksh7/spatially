from fastapi import APIRouter, HTTPException, Depends
from config import get_supabase
from middleware.auth import get_current_user, require_organizer

router = APIRouter(prefix="/api/logs", tags=["Activity Logs"])

@router.get("/{event_id}")
async def get_event_logs(
    event_id: str, limit: int = 50, current_user: dict = Depends(require_organizer)
):
    """Get activity logs for a specific event."""
    supabase = get_supabase()

    # Verify event exists and user is organizer
    event = supabase.table("events").select("organizer_id").eq("id", event_id).execute()
    if not event.data:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.data[0]["organizer_id"] != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="Not authorized to view logs for this event")

    # Fetch logs
    logs = (
        supabase.table("event_activity_logs")
        .select("*")
        .eq("event_id", event_id)
        .order("created_at", desc=True)
        .limit(limit)
        .execute()
    )

    return {"logs": logs.data}
