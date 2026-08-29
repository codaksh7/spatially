from fastapi import APIRouter, HTTPException, Depends
from models import AssignPositionRequest, UpdatePositionRequest, SwitchPositionRequest, ZoneLayoutRequest
from config import get_supabase
from middleware.auth import get_current_user, require_organizer, require_volunteer
import json
import os

router = APIRouter(prefix="/api/venue-map", tags=["Venue Map"])

LAYOUTS_FILE = os.path.join(os.path.dirname(__file__), "..", "data", "venue_layouts.json")

def read_layouts():
    if not os.path.exists(LAYOUTS_FILE):
        return {}
    try:
        with open(LAYOUTS_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return {}

def write_layouts(layouts):
    with open(LAYOUTS_FILE, "w") as f:
        json.dump(layouts, f)



@router.get("/{event_id}/density")
async def get_zone_density(event_id: str, current_user: dict = Depends(get_current_user)):
    """Get crowd density per zone from BLE crowd_data table."""
    supabase = get_supabase()

    # Verify event exists
    event = supabase.table("events").select("id, zones").eq("id", event_id).execute()
    if not event.data:
        raise HTTPException(status_code=404, detail="Event not found")

    zones = event.data[0].get("zones", [])

    # Try to read crowd_data from mobile BLE pipeline
    density = {}
    try:
        crowd = (
            supabase.table("crowd_data")
            .select("zone, device_count")
            .eq("event_id", event_id)
            .execute()
        )
        for row in crowd.data:
            zone = row.get("zone", "unknown")
            count = row.get("device_count", 0)
            density[zone] = density.get(zone, 0) + count
    except Exception:
        # crowd_data table may not exist yet — return empty densities
        pass

    # Ensure all configured zones appear in the response
    for z in zones:
        if z not in density:
            density[z] = 0

    return {"event_id": event_id, "zones": zones, "density": density}


@router.get("/{event_id}/volunteers")
async def get_volunteer_positions(event_id: str, current_user: dict = Depends(get_current_user)):
    """Get all volunteer positions on the map for this event."""
    supabase = get_supabase()

    positions = (
        supabase.table("volunteer_map_positions")
        .select("*")
        .eq("event_id", event_id)
        .execute()
    )

    # Enrich with volunteer names
    vol_ids = list(set(p["volunteer_user_id"] for p in positions.data))
    volunteers = []
    if vol_ids:
        vols = (
            supabase.table("web_users")
            .select("user_id, full_name, nickname")
            .in_("user_id", vol_ids)
            .execute()
        )
        volunteers = vols.data

    vol_map = {v["user_id"]: v for v in volunteers}

    enriched = []
    for pos in positions.data:
        pos["volunteer_name"] = vol_map.get(pos["volunteer_user_id"], {}).get("full_name", "Unknown")
        enriched.append(pos)

    return {"positions": enriched}


@router.post("/{event_id}/assign-position")
async def assign_volunteer_position(
    event_id: str, data: AssignPositionRequest, current_user: dict = Depends(require_organizer)
):
    """Organizer assigns a volunteer to a zone + position on the map."""
    supabase = get_supabase()

    # Verify event ownership
    event = supabase.table("events").select("id, organizer_id, zones").eq("id", event_id).execute()
    if not event.data:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.data[0].get("organizer_id") != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="You can only manage your own events")

    # Verify zone is valid for this event
    zones = event.data[0].get("zones", [])
    if zones and data.zone not in zones:
        raise HTTPException(status_code=400, detail=f"Zone '{data.zone}' is not configured for this event")

    # Verify volunteer is assigned to this event
    assignment = (
        supabase.table("web_volunteer_assignments")
        .select("id")
        .eq("event_id", event_id)
        .eq("volunteer_user_id", data.volunteer_user_id)
        .execute()
    )
    if not assignment.data:
        raise HTTPException(status_code=400, detail="Volunteer is not assigned to this event")

    # Upsert position
    existing = (
        supabase.table("volunteer_map_positions")
        .select("id")
        .eq("event_id", event_id)
        .eq("volunteer_user_id", data.volunteer_user_id)
        .execute()
    )

    position_data = {
        "event_id": event_id,
        "volunteer_user_id": data.volunteer_user_id,
        "zone": data.zone,
        "pos_x": data.pos_x,
        "pos_y": data.pos_y,
        "assigned_by": current_user["user_id"],
    }

    if existing.data:
        supabase.table("volunteer_map_positions").update(position_data).eq(
            "id", existing.data[0]["id"]
        ).execute()
    else:
        supabase.table("volunteer_map_positions").insert(position_data).execute()

    try:
        supabase.table("event_activity_logs").insert({
            "event_id": event_id,
            "action_type": "placement",
            "description": f"Placed volunteer {data.volunteer_user_id} in zone {data.zone}",
            "actor_id": current_user["user_id"]
        }).execute()
    except Exception:
        pass

    return {"message": f"Volunteer {data.volunteer_user_id} placed in zone {data.zone}"}


@router.put("/{event_id}/update-position")
async def update_volunteer_position(
    event_id: str, data: UpdatePositionRequest, current_user: dict = Depends(require_organizer)
):
    """Organizer moves a volunteer's position (drag-and-drop)."""
    supabase = get_supabase()

    event = supabase.table("events").select("id, organizer_id").eq("id", event_id).execute()
    if not event.data:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.data[0].get("organizer_id") != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="You can only manage your own events")

    existing = (
        supabase.table("volunteer_map_positions")
        .select("id")
        .eq("event_id", event_id)
        .eq("volunteer_user_id", data.volunteer_user_id)
        .execute()
    )

    if not existing.data:
        raise HTTPException(status_code=404, detail="Volunteer position not found on map")

    supabase.table("volunteer_map_positions").update({
        "zone": data.zone,
        "pos_x": data.pos_x,
        "pos_y": data.pos_y,
    }).eq("id", existing.data[0]["id"]).execute()

    try:
        supabase.table("event_activity_logs").insert({
            "event_id": event_id,
            "action_type": "move",
            "description": f"Moved volunteer {data.volunteer_user_id} to zone {data.zone}",
            "actor_id": current_user["user_id"]
        }).execute()
    except Exception:
        pass

    return {"message": "Position updated"}


@router.delete("/{event_id}/remove-position/{volunteer_id}")
async def remove_volunteer_position(
    event_id: str, volunteer_id: str, current_user: dict = Depends(require_organizer)
):
    """Organizer removes a volunteer from the map (unassigns position)."""
    supabase = get_supabase()

    event = supabase.table("events").select("id, organizer_id").eq("id", event_id).execute()
    if not event.data:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.data[0].get("organizer_id") != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="You can only manage your own events")

    existing = (
        supabase.table("volunteer_map_positions")
        .select("id")
        .eq("event_id", event_id)
        .eq("volunteer_user_id", volunteer_id)
        .execute()
    )

    if not existing.data:
        raise HTTPException(status_code=404, detail="Volunteer position not found on map")

    supabase.table("volunteer_map_positions").delete().eq("id", existing.data[0]["id"]).execute()

    try:
        supabase.table("event_activity_logs").insert({
            "event_id": event_id,
            "action_type": "move",
            "description": f"Removed volunteer {volunteer_id} from map",
            "actor_id": current_user["user_id"]
        }).execute()
    except Exception:
        pass

    return {"message": "Position removed"}


@router.post("/{event_id}/switch-request")
async def create_switch_request(
    event_id: str, data: SwitchPositionRequest, current_user: dict = Depends(require_volunteer)
):
    """Volunteer requests to switch positions with another volunteer."""
    supabase = get_supabase()

    if current_user["user_id"] == data.target_volunteer_id:
        raise HTTPException(status_code=400, detail="Cannot switch with yourself")

    # Verify both volunteers are positioned on this event's map
    requester_pos = (
        supabase.table("volunteer_map_positions")
        .select("id")
        .eq("event_id", event_id)
        .eq("volunteer_user_id", current_user["user_id"])
        .execute()
    )
    target_pos = (
        supabase.table("volunteer_map_positions")
        .select("id")
        .eq("event_id", event_id)
        .eq("volunteer_user_id", data.target_volunteer_id)
        .execute()
    )

    if not requester_pos.data:
        raise HTTPException(status_code=400, detail="You don't have an assigned position on this map")
    if not target_pos.data:
        raise HTTPException(status_code=400, detail="Target volunteer doesn't have a position on this map")

    # Check for existing pending request
    existing = (
        supabase.table("volunteer_switch_requests")
        .select("id")
        .eq("event_id", event_id)
        .eq("requester_id", current_user["user_id"])
        .eq("target_id", data.target_volunteer_id)
        .eq("status", "pending")
        .execute()
    )

    if existing.data:
        raise HTTPException(status_code=409, detail="You already have a pending switch request with this volunteer")

    supabase.table("volunteer_switch_requests").insert({
        "event_id": event_id,
        "requester_id": current_user["user_id"],
        "target_id": data.target_volunteer_id,
        "status": "pending",
    }).execute()

    return {"message": f"Switch request sent to {data.target_volunteer_id}"}


@router.get("/my-switch-requests")
async def get_my_switch_requests(current_user: dict = Depends(require_volunteer)):
    """Get all pending switch requests involving this volunteer."""
    supabase = get_supabase()

    # Incoming (where I'm the target)
    incoming = (
        supabase.table("volunteer_switch_requests")
        .select("*")
        .eq("target_id", current_user["user_id"])
        .eq("status", "pending")
        .execute()
    )

    # Outgoing (where I'm the requester)
    outgoing = (
        supabase.table("volunteer_switch_requests")
        .select("*")
        .eq("requester_id", current_user["user_id"])
        .eq("status", "pending")
        .execute()
    )

    # Enrich with names
    all_ids = set()
    for r in incoming.data + outgoing.data:
        all_ids.add(r["requester_id"])
        all_ids.add(r["target_id"])

    vol_names = {}
    if all_ids:
        vols = (
            supabase.table("web_users")
            .select("user_id, full_name")
            .in_("user_id", list(all_ids))
            .execute()
        )
        vol_names = {v["user_id"]: v["full_name"] for v in vols.data}

    for r in incoming.data:
        r["requester_name"] = vol_names.get(r["requester_id"], r["requester_id"])
    for r in outgoing.data:
        r["target_name"] = vol_names.get(r["target_id"], r["target_id"])

    # Enrich with event names
    event_ids = set(r["event_id"] for r in incoming.data + outgoing.data)
    event_names = {}
    if event_ids:
        evts = (
            supabase.table("events")
            .select("id, name")
            .in_("id", list(event_ids))
            .execute()
        )
        event_names = {e["id"]: e["name"] for e in evts.data}

    for r in incoming.data + outgoing.data:
        r["event_name"] = event_names.get(r["event_id"], "Unknown Event")

    return {"incoming": incoming.data, "outgoing": outgoing.data}


@router.post("/switch-request/{request_id}/accept")
async def accept_switch_request(request_id: str, current_user: dict = Depends(require_volunteer)):
    """Accept a switch request — swaps both volunteers' positions."""
    supabase = get_supabase()

    req = (
        supabase.table("volunteer_switch_requests")
        .select("*")
        .eq("id", request_id)
        .eq("target_id", current_user["user_id"])
        .eq("status", "pending")
        .execute()
    )

    if not req.data:
        raise HTTPException(status_code=404, detail="Switch request not found or already processed")

    switch_req = req.data[0]

    # Get both positions
    requester_pos = (
        supabase.table("volunteer_map_positions")
        .select("*")
        .eq("event_id", switch_req["event_id"])
        .eq("volunteer_user_id", switch_req["requester_id"])
        .execute()
    )
    target_pos = (
        supabase.table("volunteer_map_positions")
        .select("*")
        .eq("event_id", switch_req["event_id"])
        .eq("volunteer_user_id", switch_req["target_id"])
        .execute()
    )

    if not requester_pos.data or not target_pos.data:
        raise HTTPException(status_code=400, detail="One or both positions no longer exist")

    rp = requester_pos.data[0]
    tp = target_pos.data[0]

    # Swap positions
    supabase.table("volunteer_map_positions").update({
        "zone": tp["zone"], "pos_x": tp["pos_x"], "pos_y": tp["pos_y"]
    }).eq("id", rp["id"]).execute()

    supabase.table("volunteer_map_positions").update({
        "zone": rp["zone"], "pos_x": rp["pos_x"], "pos_y": rp["pos_y"]
    }).eq("id", tp["id"]).execute()

    # Mark request as accepted
    supabase.table("volunteer_switch_requests").update(
        {"status": "accepted"}
    ).eq("id", request_id).execute()

    try:
        supabase.table("event_activity_logs").insert({
            "event_id": switch_req["event_id"],
            "action_type": "switch",
            "description": f"Volunteer {switch_req['requester_id']} and {switch_req['target_id']} switched positions",
            "actor_id": current_user["user_id"]
        }).execute()
    except Exception:
        pass

    return {"message": "Positions switched successfully"}


@router.post("/switch-request/{request_id}/decline")
async def decline_switch_request(request_id: str, current_user: dict = Depends(require_volunteer)):
    """Decline a switch request."""
    supabase = get_supabase()

    req = (
        supabase.table("volunteer_switch_requests")
        .select("id")
        .eq("id", request_id)
        .eq("target_id", current_user["user_id"])
        .eq("status", "pending")
        .execute()
    )

    if not req.data:
        raise HTTPException(status_code=404, detail="Switch request not found or already processed")

    supabase.table("volunteer_switch_requests").update(
        {"status": "declined"}
    ).eq("id", request_id).execute()

    return {"message": "Switch request declined"}

@router.get("/{event_id}/layout")
async def get_zone_layout(event_id: str):
    """Get custom manual zone layout if exists."""
    layouts = read_layouts()
    return {"layout": layouts.get(event_id, [])}

@router.post("/{event_id}/layout")
async def save_zone_layout(event_id: str, data: ZoneLayoutRequest, current_user: dict = Depends(require_organizer)):
    """Save custom manual zone layout."""
    supabase = get_supabase()
    event = supabase.table("events").select("id, organizer_id").eq("id", event_id).execute()
    if not event.data or event.data[0].get("organizer_id") != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="Not authorized to edit zones for this event")
        
    layouts = read_layouts()
    layouts[event_id] = [item.model_dump() for item in data.layout]
    write_layouts(layouts)
    return {"message": "Layout saved successfully"}
