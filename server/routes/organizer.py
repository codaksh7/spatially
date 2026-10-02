from fastapi import APIRouter, HTTPException, Depends, Query
from config import get_supabase
from middleware.auth import get_current_user, require_organizer
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timezone

router = APIRouter(prefix="/api/organizer", tags=["Organizer"])


# ═══════════════════════════════════════════════════════════════
# PYDANTIC MODELS
# ═══════════════════════════════════════════════════════════════

class IncidentCreate(BaseModel):
    event_id: str
    title: str
    description: Optional[str] = ""
    category: str = "other"
    priority: str = "routine"
    zone_name: Optional[str] = None

class IncidentUpdate(BaseModel):
    status: Optional[str] = None
    priority: Optional[str] = None
    assigned_to: Optional[str] = None
    resolution_notes: Optional[str] = None

class TaskCreate(BaseModel):
    event_id: str
    title: str
    description: Optional[str] = ""
    zone_id: Optional[str] = None
    zone_name: Optional[str] = None
    assigned_to: Optional[str] = None
    priority: str = "normal"

class TaskUpdate(BaseModel):
    status: Optional[str] = None
    priority: Optional[str] = None
    assigned_to: Optional[str] = None
    notes: Optional[str] = None

class MessageCreate(BaseModel):
    event_id: str
    content: str
    target_type: str = "broadcast"
    target_id: Optional[str] = None
    priority: str = "routine"
    requires_ack: bool = False

class ZoneCreate(BaseModel):
    event_id: str
    name: str
    code: Optional[str] = None
    floor_level: Optional[int] = 1
    capacity_limit: Optional[int] = None
    operating_capacity: Optional[int] = None
    is_crowd_monitored: bool = True

class ZoneUpdate(BaseModel):
    name: Optional[str] = None
    code: Optional[str] = None
    capacity_limit: Optional[int] = None
    operating_capacity: Optional[int] = None
    is_crowd_monitored: Optional[bool] = None
    is_active: Optional[bool] = None

class BoothCreate(BaseModel):
    event_id: str
    name: str
    description: Optional[str] = ""
    booth_number: Optional[str] = None
    zone_id: Optional[str] = None
    category: Optional[str] = None
    contact_name: Optional[str] = None
    contact_email: Optional[str] = None

class BoothUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    booth_number: Optional[str] = None
    zone_id: Optional[str] = None
    category: Optional[str] = None
    is_active: Optional[bool] = None

class SessionCreate(BaseModel):
    event_id: str
    title: str
    description: Optional[str] = ""
    speaker_name: Optional[str] = None
    zone_id: Optional[str] = None
    location: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    session_type: Optional[str] = "presentation"

class SessionUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    speaker_name: Optional[str] = None
    zone_id: Optional[str] = None
    location: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    status: Optional[str] = None


# ═══════════════════════════════════════════════════════════════
# HELPER: Verify organizer owns event
# ═══════════════════════════════════════════════════════════════

def verify_event_ownership(supabase, event_id: str, user_id: str):
    """Verify the organizer owns this event."""
    event = supabase.table("events").select("id, organizer_id").eq("id", event_id).execute()
    if not event.data:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.data[0].get("organizer_id") != user_id:
        raise HTTPException(status_code=403, detail="You do not own this event")
    return event.data[0]


# ═══════════════════════════════════════════════════════════════
# 1. OPERATIONAL HEALTH
# ═══════════════════════════════════════════════════════════════

@router.get("/health/{event_id}")
async def get_operational_health(event_id: str, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    try:
        result = supabase.rpc("get_event_operational_health", {"p_event_id": event_id}).execute()
        return {"health": result.data}
    except Exception as e:
        # Fallback: compute basic health manually
        return {"health": None, "error": str(e)}


@router.get("/timeline/{event_id}")
async def get_operational_timeline(event_id: str, limit: int = Query(50, ge=1, le=200), current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    try:
        result = supabase.rpc("get_event_operational_timeline", {"p_event_id": event_id, "p_limit": limit}).execute()
        return {"timeline": result.data}
    except Exception as e:
        return {"timeline": [], "error": str(e)}


# ═══════════════════════════════════════════════════════════════
# 2. INCIDENTS
# ═══════════════════════════════════════════════════════════════

@router.get("/incidents/{event_id}")
async def list_incidents(event_id: str, status: Optional[str] = None, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    query = supabase.table("operational_incidents").select("*").eq("event_id", event_id).order("created_at", desc=True)
    if status:
        query = query.eq("status", status)
    result = query.execute()
    return {"incidents": result.data}


@router.post("/incidents")
async def create_incident(data: IncidentCreate, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, data.event_id, current_user["user_id"])
    try:
        result = supabase.rpc("report_operational_incident", {
            "p_event_id": data.event_id,
            "p_title": data.title,
            "p_description": data.description or "",
            "p_category": data.category,
            "p_priority": data.priority,
            "p_zone_name": data.zone_name or ""
        }).execute()
        return {"message": "Incident created", "data": result.data}
    except Exception as e:
        # Fallback: direct insert
        new_incident = {
            "event_id": data.event_id,
            "title": data.title,
            "description": data.description or "",
            "category": data.category,
            "priority": data.priority,
            "venue_zone_name": data.zone_name,
            "status": "reported",
            "reporter_id": current_user.get("id", current_user.get("user_id")),
        }
        result = supabase.table("operational_incidents").insert(new_incident).execute()
        return {"message": "Incident created", "data": result.data}


@router.put("/incidents/{incident_id}")
async def update_incident(incident_id: str, data: IncidentUpdate, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    # Verify incident exists
    existing = supabase.table("operational_incidents").select("*").eq("id", incident_id).execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Incident not found")
    
    updates = {}
    if data.status:
        updates["status"] = data.status
    if data.priority:
        updates["priority"] = data.priority
    if data.assigned_to:
        updates["assigned_to"] = data.assigned_to
    if data.resolution_notes:
        updates["resolution_notes"] = data.resolution_notes
    
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    
    updates["updated_at"] = datetime.now(timezone.utc).isoformat()
    result = supabase.table("operational_incidents").update(updates).eq("id", incident_id).execute()
    return {"message": "Incident updated", "data": result.data}


# ═══════════════════════════════════════════════════════════════
# 3. VOLUNTEER SHIFTS & TEAMS
# ═══════════════════════════════════════════════════════════════

@router.get("/shifts/{event_id}")
async def list_shifts(event_id: str, current_user: dict = Depends(require_organizer)):
    try:
        supabase = get_supabase()
        verify_event_ownership(supabase, event_id, current_user["user_id"])
        shifts = supabase.table("volunteer_shifts").select("*").eq("event_id", event_id).order("created_at", desc=True).execute()
        return {"shifts": shifts.data}
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/teams/{event_id}")
async def list_teams(event_id: str, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    teams = supabase.table("event_teams").select("*").eq("event_id", event_id).execute()
    return {"teams": teams.data}


@router.get("/coverage/{event_id}")
async def list_coverage_requests(event_id: str, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    coverage = supabase.table("coverage_requests").select("*").eq("event_id", event_id).order("created_at", desc=True).execute()
    return {"coverage_requests": coverage.data}


@router.get("/volunteers/{event_id}")
async def list_event_volunteers(event_id: str, current_user: dict = Depends(require_organizer)):
    try:
        supabase = get_supabase()
        verify_event_ownership(supabase, event_id, current_user["user_id"])
        
        # Get from both assignment tables
        web_assignments = supabase.table("web_volunteer_assignments").select("*").eq("event_id", event_id).execute()
        prod_assignments = supabase.table("volunteer_assignments").select("*").eq("event_id", event_id).execute()
        
        return {
            "web_assignments": web_assignments.data,
            "assignments": prod_assignments.data,
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ═══════════════════════════════════════════════════════════════
# 4. TASKS
# ═══════════════════════════════════════════════════════════════

@router.get("/tasks/{event_id}")
async def list_tasks(event_id: str, status: Optional[str] = None, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    query = supabase.table("supervisor_tasks").select("*").eq("event_id", event_id).order("created_at", desc=True)
    if status:
        query = query.eq("status", status)
    result = query.execute()
    return {"tasks": result.data}


@router.post("/tasks")
async def create_task(data: TaskCreate, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, data.event_id, current_user["user_id"])
    new_task = {
        "event_id": data.event_id,
        "title": data.title,
        "description": data.description or "",
        "priority": data.priority,
        "status": "pending",
        "created_by": current_user.get("id", current_user.get("user_id")),
    }
    if data.zone_id:
        new_task["zone_id"] = data.zone_id
    if data.zone_name:
        new_task["zone_name"] = data.zone_name
    if data.assigned_to:
        new_task["assigned_to"] = data.assigned_to
    
    result = supabase.table("supervisor_tasks").insert(new_task).execute()
    return {"message": "Task created", "data": result.data}


@router.put("/tasks/{task_id}")
async def update_task(task_id: str, data: TaskUpdate, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    existing = supabase.table("supervisor_tasks").select("*").eq("id", task_id).execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Task not found")
    
    updates = {}
    if data.status:
        updates["status"] = data.status
    if data.priority:
        updates["priority"] = data.priority
    if data.assigned_to:
        updates["assigned_to"] = data.assigned_to
    if data.notes:
        updates["completion_notes"] = data.notes
    
    if updates:
        updates["updated_at"] = datetime.now(timezone.utc).isoformat()
        result = supabase.table("supervisor_tasks").update(updates).eq("id", task_id).execute()
        return {"message": "Task updated", "data": result.data}
    raise HTTPException(status_code=400, detail="No fields to update")


# ═══════════════════════════════════════════════════════════════
# 5. COMMUNICATIONS
# ═══════════════════════════════════════════════════════════════

@router.get("/comms/{event_id}")
async def list_communications(event_id: str, target_type: Optional[str] = None, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    query = supabase.table("operational_messages").select("*").eq("event_id", event_id).order("created_at", desc=True).limit(100)
    if target_type:
        query = query.eq("target_type", target_type)
    result = query.execute()
    return {"messages": result.data}


@router.post("/comms")
async def send_communication(data: MessageCreate, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, data.event_id, current_user["user_id"])
    new_msg = {
        "event_id": data.event_id,
        "sender_id": current_user.get("id", current_user.get("user_id")),
        "sender_name": current_user.get("full_name", current_user.get("nickname", "Organizer")),
        "content": data.content,
        "target_type": data.target_type,
        "priority": data.priority,
        "requires_acknowledgment": data.requires_ack,
    }
    if data.target_id:
        new_msg["target_id"] = data.target_id
    
    result = supabase.table("operational_messages").insert(new_msg).execute()
    return {"message": "Message sent", "data": result.data}


# ═══════════════════════════════════════════════════════════════
# 6. CROWD MONITORING
# ═══════════════════════════════════════════════════════════════

@router.get("/crowd/{event_id}")
async def get_crowd_data(event_id: str, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    
    # Get live counts
    counts = supabase.table("volunteer_counts").select("*").eq("event_id", event_id).execute()
    
    # Get zones
    zones = supabase.table("event_zones").select("*").eq("event_id", event_id).execute()
    
    # Aggregate per zone
    zone_density = {}
    for z in zones.data:
        zone_name = z.get("name", "Unknown")
        zone_counts = [c for c in counts.data if c.get("zone") == zone_name or c.get("zone_id") == z.get("id")]
        total_active = sum(c.get("active_count", 0) for c in zone_counts)
        zone_density[zone_name] = {
            "active_count": total_active,
            "capacity_limit": z.get("capacity_limit"),
            "operating_capacity": z.get("operating_capacity"),
            "is_monitored": z.get("is_crowd_monitored", True),
            "volunteer_scanners": len(zone_counts),
        }
    
    return {
        "zone_density": zone_density,
        "raw_counts": counts.data,
        "zones": zones.data,
    }


# ═══════════════════════════════════════════════════════════════
# 7. ZONES
# ═══════════════════════════════════════════════════════════════

@router.get("/zones/{event_id}")
async def list_zones(event_id: str, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    result = supabase.table("event_zones").select("*").eq("event_id", event_id).order("sort_order").execute()
    return {"zones": result.data}


@router.post("/zones")
async def create_zone(data: ZoneCreate, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, data.event_id, current_user["user_id"])
    new_zone = {
        "event_id": data.event_id,
        "name": data.name,
        "code": data.code or data.name,
        "floor_level": data.floor_level or 1,
        "is_crowd_monitored": data.is_crowd_monitored,
    }
    if data.capacity_limit:
        new_zone["capacity_limit"] = data.capacity_limit
    if data.operating_capacity:
        new_zone["operating_capacity"] = data.operating_capacity
    
    result = supabase.table("event_zones").insert(new_zone).execute()
    
    # Also sync to events.zones text array
    event = supabase.table("events").select("zones").eq("id", data.event_id).execute()
    if event.data:
        current_zones = event.data[0].get("zones") or []
        if data.name not in current_zones:
            current_zones.append(data.name)
            supabase.table("events").update({"zones": current_zones}).eq("id", data.event_id).execute()
    
    return {"message": "Zone created", "data": result.data}


@router.put("/zones/{zone_id}")
async def update_zone(zone_id: str, data: ZoneUpdate, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    existing = supabase.table("event_zones").select("*").eq("id", zone_id).execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Zone not found")
    
    updates = {k: v for k, v in data.model_dump(exclude_none=True).items()}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    
    result = supabase.table("event_zones").update(updates).eq("id", zone_id).execute()
    return {"message": "Zone updated", "data": result.data}


# ═══════════════════════════════════════════════════════════════
# 8. BOOTHS
# ═══════════════════════════════════════════════════════════════

@router.get("/booths/{event_id}")
async def list_booths(event_id: str, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    result = supabase.table("booths").select("*").eq("event_id", event_id).order("created_at").execute()
    return {"booths": result.data}


@router.post("/booths")
async def create_booth(data: BoothCreate, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, data.event_id, current_user["user_id"])
    new_booth = {
        "event_id": data.event_id,
        "name": data.name,
        "description": data.description or "",
    }
    if data.booth_number:
        new_booth["booth_number"] = data.booth_number
    if data.zone_id:
        new_booth["zone_id"] = data.zone_id
    if data.category:
        new_booth["category"] = data.category
    if data.contact_name:
        new_booth["contact_name"] = data.contact_name
    if data.contact_email:
        new_booth["contact_email"] = data.contact_email
    
    result = supabase.table("booths").insert(new_booth).execute()
    return {"message": "Booth created", "data": result.data}


@router.put("/booths/{booth_id}")
async def update_booth(booth_id: str, data: BoothUpdate, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    existing = supabase.table("booths").select("*").eq("id", booth_id).execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Booth not found")
    
    updates = {k: v for k, v in data.model_dump(exclude_none=True).items()}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    
    result = supabase.table("booths").update(updates).eq("id", booth_id).execute()
    return {"message": "Booth updated", "data": result.data}


@router.delete("/booths/{booth_id}")
async def delete_booth(booth_id: str, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    existing = supabase.table("booths").select("*").eq("id", booth_id).execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Booth not found")
    supabase.table("booths").delete().eq("id", booth_id).execute()
    return {"message": "Booth deleted"}


# ═══════════════════════════════════════════════════════════════
# 9. SESSIONS
# ═══════════════════════════════════════════════════════════════

@router.get("/sessions/{event_id}")
async def list_sessions(event_id: str, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    result = supabase.table("sessions").select("*").eq("event_id", event_id).order("start_time").execute()
    return {"sessions": result.data}


@router.post("/sessions")
async def create_session(data: SessionCreate, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, data.event_id, current_user["user_id"])
    new_session = {
        "event_id": data.event_id,
        "title": data.title,
        "description": data.description or "",
    }
    if data.speaker_name:
        new_session["speaker_name"] = data.speaker_name
    if data.zone_id:
        new_session["zone_id"] = data.zone_id
    if data.location:
        new_session["location"] = data.location
    if data.start_time:
        new_session["start_time"] = data.start_time
    if data.end_time:
        new_session["end_time"] = data.end_time
    if data.session_type:
        new_session["session_type"] = data.session_type
    
    result = supabase.table("sessions").insert(new_session).execute()
    return {"message": "Session created", "data": result.data}


@router.put("/sessions/{session_id}")
async def update_session(session_id: str, data: SessionUpdate, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    existing = supabase.table("sessions").select("*").eq("id", session_id).execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Session not found")
    
    updates = {k: v for k, v in data.model_dump(exclude_none=True).items()}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    
    result = supabase.table("sessions").update(updates).eq("id", session_id).execute()
    return {"message": "Session updated", "data": result.data}


@router.delete("/sessions/{session_id}")
async def delete_session(session_id: str, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    existing = supabase.table("sessions").select("*").eq("id", session_id).execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Session not found")
    supabase.table("sessions").delete().eq("id", session_id).execute()
    return {"message": "Session deleted"}


# ═══════════════════════════════════════════════════════════════
# 10. ASSISTANCE
# ═══════════════════════════════════════════════════════════════

@router.get("/assistance/{event_id}")
async def list_assistance_requests(event_id: str, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    # Assistance requests are stored as incidents with category='assistance'
    result = (
        supabase.table("operational_incidents")
        .select("*")
        .eq("event_id", event_id)
        .eq("category", "assistance")
        .order("created_at", desc=True)
        .execute()
    )
    return {"assistance_requests": result.data}


# ═══════════════════════════════════════════════════════════════
# 11. ANALYTICS
# ═══════════════════════════════════════════════════════════════

@router.get("/analytics/{event_id}")
async def get_event_analytics(event_id: str, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    
    # Tickets
    total_tickets = supabase.table("tickets").select("id", count="exact").eq("event_id", event_id).execute()
    checked_in = supabase.table("tickets").select("id", count="exact").eq("event_id", event_id).eq("status", "checked_in").execute()
    
    # Incidents
    incidents = supabase.table("operational_incidents").select("*").eq("event_id", event_id).execute()
    total_incidents = len(incidents.data)
    resolved_incidents = len([i for i in incidents.data if i.get("status") in ("resolved", "closed")])
    urgent_incidents = len([i for i in incidents.data if i.get("priority") == "urgent"])
    
    # Tasks
    tasks = supabase.table("supervisor_tasks").select("*").eq("event_id", event_id).execute()
    total_tasks = len(tasks.data)
    completed_tasks = len([t for t in tasks.data if t.get("status") == "completed"])
    
    # Shifts
    shifts = supabase.table("volunteer_shifts").select("*").eq("event_id", event_id).execute()
    active_shifts = len([s for s in shifts.data if s.get("status") == "active"])
    
    # Booths
    booths = supabase.table("booths").select("id", count="exact").eq("event_id", event_id).execute()
    
    # Sessions
    sessions = supabase.table("sessions").select("id", count="exact").eq("event_id", event_id).execute()
    
    # Zones
    zones = supabase.table("event_zones").select("*").eq("event_id", event_id).execute()
    
    # Crowd data
    counts = supabase.table("volunteer_counts").select("*").eq("event_id", event_id).execute()
    total_crowd = sum(c.get("active_count", 0) for c in counts.data)
    
    # Messages
    messages = supabase.table("operational_messages").select("id", count="exact").eq("event_id", event_id).execute()
    
    # Incident categories breakdown
    incident_categories = {}
    for inc in incidents.data:
        cat = inc.get("category", "other")
        incident_categories[cat] = incident_categories.get(cat, 0) + 1
    
    # Incident priority breakdown
    incident_priorities = {}
    for inc in incidents.data:
        pri = inc.get("priority", "routine")
        incident_priorities[pri] = incident_priorities.get(pri, 0) + 1
    
    return {
        "attendance": {
            "total_tickets": total_tickets.count or 0,
            "checked_in": checked_in.count or 0,
            "check_in_rate": round((checked_in.count or 0) / max(total_tickets.count or 1, 1) * 100, 1),
        },
        "crowd": {
            "current_total": total_crowd,
            "zones_monitored": len([z for z in zones.data if z.get("is_crowd_monitored")]),
        },
        "incidents": {
            "total": total_incidents,
            "resolved": resolved_incidents,
            "urgent": urgent_incidents,
            "resolution_rate": round(resolved_incidents / max(total_incidents, 1) * 100, 1),
            "by_category": incident_categories,
            "by_priority": incident_priorities,
        },
        "tasks": {
            "total": total_tasks,
            "completed": completed_tasks,
            "completion_rate": round(completed_tasks / max(total_tasks, 1) * 100, 1),
        },
        "volunteers": {
            "active_shifts": active_shifts,
            "total_shifts": len(shifts.data),
        },
        "content": {
            "booths": booths.count or 0,
            "sessions": sessions.count or 0,
            "zones": len(zones.data),
        },
        "communications": {
            "total_messages": messages.count or 0,
        },
    }


# ═══════════════════════════════════════════════════════════════
# 12. EXPORT
# ═══════════════════════════════════════════════════════════════

@router.get("/export/{event_id}")
async def export_event_data(event_id: str, report_type: str = Query("summary"), current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    
    event = supabase.table("events").select("*").eq("id", event_id).execute()
    
    if report_type == "incidents":
        data = supabase.table("operational_incidents").select("*").eq("event_id", event_id).order("created_at").execute()
        return {"report_type": "incidents", "event": event.data[0] if event.data else {}, "data": data.data}
    elif report_type == "attendance":
        data = supabase.table("tickets").select("*").eq("event_id", event_id).execute()
        return {"report_type": "attendance", "event": event.data[0] if event.data else {}, "data": data.data}
    elif report_type == "shifts":
        data = supabase.table("volunteer_shifts").select("*").eq("event_id", event_id).execute()
        return {"report_type": "shifts", "event": event.data[0] if event.data else {}, "data": data.data}
    elif report_type == "tasks":
        data = supabase.table("supervisor_tasks").select("*").eq("event_id", event_id).execute()
        return {"report_type": "tasks", "event": event.data[0] if event.data else {}, "data": data.data}
    else:
        # Summary: return analytics
        analytics = await get_event_analytics(event_id, current_user)
        return {"report_type": "summary", "event": event.data[0] if event.data else {}, "data": analytics}


# ═══════════════════════════════════════════════════════════════
# 13. LOST & FOUND
# ═══════════════════════════════════════════════════════════════

@router.get("/lost-found/{event_id}")
async def list_lost_found(event_id: str, current_user: dict = Depends(require_organizer)):
    supabase = get_supabase()
    verify_event_ownership(supabase, event_id, current_user["user_id"])
    result = supabase.table("lost_found_reports").select("*").eq("event_id", event_id).order("created_at", desc=True).execute()
    return {"items": result.data}
