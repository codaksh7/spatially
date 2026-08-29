import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { getMinDate } from "../utils/validators";
import { LuPlus, LuX, LuLoader } from "react-icons/lu";
import VenueMap from "../components/VenueMap";

export default function CreateEvent() {
  const toast = useToast();
  const navigate = useNavigate();
  const [submitting, setSubmitting] = useState(false);
  const [zoneInput, setZoneInput] = useState("");
  const [form, setForm] = useState({
    name: "",
    venue: "",
    event_date: "",
    start_time: "",
    end_time: "",
    description: "",
    capacity: "",
    location_address: "",
    organizer_name: "",
    zones: [],
  });
  const [errors, setErrors] = useState({});

  const [showModal, setShowModal] = useState(false);
  const [showMap, setShowMap] = useState(false);

  const updateField = (field, value) => {
    setForm((prev) => ({ ...prev, [field]: value }));
    setErrors((prev) => ({ ...prev, [field]: null }));
  };

  const addZone = () => {
    const zone = zoneInput.trim();
    if (!zone) return;
    if (form.zones.includes(zone)) {
      toast("Zone already added", "warning");
      return;
    }
    setForm((prev) => ({ ...prev, zones: [...prev.zones, zone] }));
    setZoneInput("");
  };

  const removeZone = (zone) => {
    setForm((prev) => ({ ...prev, zones: prev.zones.filter((z) => z !== zone) }));
  };

  const getMinStartTime = () => {
    if (!form.event_date) return "";
    const selectedDate = new Date(form.event_date);
    const now = new Date();
    if (selectedDate.toDateString() === now.toDateString()) {
      now.setMinutes(now.getMinutes() + 2);
      return `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
    }
    return "";
  };

  const getMinEndTime = () => {
    if (form.start_time) {
      const [h, m] = form.start_time.split(":").map(Number);
      const minEnd = new Date();
      minEnd.setHours(h, m + 5, 0, 0);
      return `${String(minEnd.getHours()).padStart(2, "0")}:${String(minEnd.getMinutes()).padStart(2, "0")}`;
    }
    if (!form.event_date) return "";
    const selectedDate = new Date(form.event_date);
    const now = new Date();
    if (selectedDate.toDateString() === now.toDateString()) {
      now.setMinutes(now.getMinutes() + 7);
      return `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
    }
    return "";
  };

  const validate = () => {
    const newErrors = {};
    if (!form.name.trim()) newErrors.name = "Event name is required";
    if (!form.organizer_name.trim()) newErrors.organizer_name = "Organizer name is required";
    if (!form.venue.trim()) newErrors.venue = "Venue is required";
    if (!form.event_date) newErrors.event_date = "Date is required";
    if (form.event_date && form.event_date < getMinDate()) {
      newErrors.event_date = "Event date cannot be in the past";
    }

    if (form.start_time) {
      const selectedDate = form.event_date ? new Date(form.event_date) : null;
      const now = new Date();
      if (selectedDate && selectedDate.toDateString() === now.toDateString()) {
        const [startH, startM] = form.start_time.split(":").map(Number);
        const startMinutes = startH * 60 + startM;
        const nowMinutes = now.getHours() * 60 + now.getMinutes();
        if (startMinutes < nowMinutes + 2) {
          newErrors.start_time = "Start time must be at least 2 minutes from now";
        }
      }
    }

    if (form.start_time && form.end_time) {
      const [startH, startM] = form.start_time.split(":").map(Number);
      const [endH, endM] = form.end_time.split(":").map(Number);
      const startMinutes = startH * 60 + startM;
      const endMinutes = endH * 60 + endM;

      if (endMinutes <= startMinutes) {
        newErrors.end_time = "End time must be after start time";
      } else if (endMinutes < startMinutes + 5) {
        newErrors.end_time = "End time must be at least 5 minutes after start time";
      }
    } else if (form.end_time && !form.start_time) {
      const selectedDate = form.event_date ? new Date(form.event_date) : null;
      const now = new Date();
      if (selectedDate && selectedDate.toDateString() === now.toDateString()) {
        const [endH, endM] = form.end_time.split(":").map(Number);
        const endMinutes = endH * 60 + endM;
        const nowMinutes = now.getHours() * 60 + now.getMinutes();
        if (endMinutes < nowMinutes + 7) {
          newErrors.end_time = "End time must be at least 7 minutes from now";
        }
      }
    }
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleInitialSubmit = (e) => {
    e.preventDefault();
    if (!validate()) return;
    
    if (form.zones.length > 0) {
      setShowModal(true);
    } else {
      // If no zones, just create normally
      createEvent(null);
    }
  };

  const createEvent = async (customLayout = null) => {
    setSubmitting(true);
    try {
      const payload = {
        ...form,
        capacity: form.capacity ? parseInt(form.capacity, 10) : 0,
        event_date: form.event_date + "T00:00:00Z",
      };
      
      const res = await api.post("/api/events/", payload);
      const newEventId = res.event.id;

      // If they chose a custom layout, save it now before redirecting
      if (customLayout) {
        await api.post(`/api/venue-map/${newEventId}/layout`, { layout: customLayout });
      }

      toast("Event created successfully!", "success");
      navigate(`/organizer/events/${newEventId}`);
    } catch (err) {
      toast(err.message || "Failed to create event", "error");
    } finally {
      setSubmitting(false);
      setShowModal(false);
      setShowMap(false);
    }
  };

  const handleAutoSetup = () => {
    setShowModal(false);
    createEvent(null); // Passing null will just use the default equal division
  };

  const handleManualSetup = () => {
    setShowModal(false);
    setShowMap(true);
  };

  if (showMap) {
    return (
      <div className="fade-in" style={{ maxWidth: "900px", margin: "0 auto" }}>
        <div className="page-header">
          <h1>Finalize Zone Layout</h1>
        </div>
        <p style={{ color: "var(--text-secondary)", marginBottom: "20px" }}>
          You have chosen to manually size your zones. Once you click "Save & Create Event", this layout will be permanently locked for this event.
        </p>
        
        <div className="card">
          <VenueMap
             eventId={null}
             zones={form.zones}
             mode="create-event"
             onExitEditMode={(layout) => {
               if (layout) createEvent(layout);
               else setShowMap(false); // If they somehow cancel, though we removed cancel button
             }}
          />
        </div>
      </div>
    );
  }

  return (
    <div className="fade-in" style={{ maxWidth: "900px", margin: "0 auto" }}>
      <div className="page-header">
        <h1>Create New Event</h1>
      </div>

      <form onSubmit={handleInitialSubmit} className="create-event-form" noValidate>
        <div className="card" style={{ marginBottom: "20px" }}>
          <h3 className="card-title" style={{ marginBottom: "20px" }}>Event Details</h3>

          <div className="form-group">
            <label className="form-label" htmlFor="event-name">Event Name *</label>
            <input id="event-name" type="text" className={`form-input ${errors.name ? "error" : ""}`} placeholder="Enter Event Name" value={form.name} onChange={(e) => updateField("name", e.target.value)} />
            {errors.name && <p className="form-error">{errors.name}</p>}
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="organizer-name">Organizer Name *</label>
            <input id="organizer-name" type="text" className={`form-input ${errors.organizer_name ? "error" : ""}`} placeholder="Your Name or Organization" value={form.organizer_name} onChange={(e) => updateField("organizer_name", e.target.value)} />
            {errors.organizer_name && <p className="form-error">{errors.organizer_name}</p>}
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="event-desc">Description</label>
            <textarea id="event-desc" className="form-textarea" placeholder="Describe the event, its theme, and what attendees can expect..." value={form.description} onChange={(e) => updateField("description", e.target.value)} />
          </div>

          <div className="form-row">
            <div className="form-group">
              <label className="form-label" htmlFor="event-venue">Venue *</label>
              <input id="event-venue" type="text" className={`form-input ${errors.venue ? "error" : ""}`} placeholder="Convention Center Hall A" value={form.venue} onChange={(e) => updateField("venue", e.target.value)} />
              {errors.venue && <p className="form-error">{errors.venue}</p>}
            </div>
            <div className="form-group">
              <label className="form-label" htmlFor="event-address">Address</label>
              <input id="event-address" type="text" className="form-input" placeholder="123 Main Street, City" value={form.location_address} onChange={(e) => updateField("location_address", e.target.value)} />
            </div>
          </div>
        </div>

        <div className="card" style={{ marginBottom: "20px" }}>
          <h3 className="card-title" style={{ marginBottom: "20px" }}>Schedule</h3>

          <div className="form-group">
            <label className="form-label" htmlFor="event-date">Event Date *</label>
            <input id="event-date" type="date" className={`form-input ${errors.event_date ? "error" : ""}`} min={getMinDate()} value={form.event_date} onChange={(e) => updateField("event_date", e.target.value)} />
            {errors.event_date && <p className="form-error">{errors.event_date}</p>}
          </div>

          <div className="form-row">
            <div className="form-group">
              <label className="form-label" htmlFor="event-start">Start Time</label>
              <input id="event-start" type="time" className={`form-input ${errors.start_time ? "error" : ""}`} min={getMinStartTime()} value={form.start_time} onChange={(e) => updateField("start_time", e.target.value)} />
              {errors.start_time && <p className="form-error">{errors.start_time}</p>}
            </div>
            <div className="form-group">
              <label className="form-label" htmlFor="event-end">End Time</label>
              <input id="event-end" type="time" className={`form-input ${errors.end_time ? "error" : ""}`} min={getMinEndTime()} value={form.end_time} onChange={(e) => updateField("end_time", e.target.value)} />
              {errors.end_time && <p className="form-error">{errors.end_time}</p>}
            </div>
          </div>
        </div>

        <div className="card" style={{ marginBottom: "20px" }}>
          <h3 className="card-title" style={{ marginBottom: "20px" }}>Capacity & Zones</h3>

          <div className="form-group">
            <label className="form-label" htmlFor="event-capacity">Maximum Capacity</label>
            <input id="event-capacity" type="number" className="form-input" placeholder="0 = Unlimited" min="0" value={form.capacity} onChange={(e) => updateField("capacity", e.target.value)} />
          </div>

          <div className="form-group">
            <label className="form-label">Event Zones</label>
            <div className="zones-input-row">
              <input
                type="text"
                className="form-input"
                placeholder="Main Stage, Food Court, VIP Area..."
                value={zoneInput}
                onChange={(e) => setZoneInput(e.target.value)}
                onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); addZone(); } }}
              />
              <button type="button" className="btn btn-secondary" onClick={addZone}>
                <LuPlus size={16} />
              </button>
            </div>
            {form.zones.length > 0 && (
              <div className="zones-list">
                {form.zones.map((zone) => (
                  <span key={zone} className="zone-chip">
                    {zone}
                    <button type="button" onClick={() => removeZone(zone)} aria-label={`Remove ${zone} zone`}>
                      <LuX size={14} />
                    </button>
                  </span>
                ))}
              </div>
            )}
          </div>
        </div>

        <div style={{ display: "flex", gap: "12px" }}>
          <button type="submit" className="btn btn-primary btn-lg" disabled={submitting}>
            {submitting ? <><LuLoader style={{ animation: "spin 0.8s linear infinite" }} /> Creating...</> : "Create Event"}
          </button>
          <button type="button" className="btn btn-secondary btn-lg" onClick={() => navigate("/organizer/events")}>
            Cancel
          </button>
        </div>
      </form>

      {/* Setup Zones Modal */}
      {showModal && (
        <div className="modal-overlay fade-in" style={{ display: "flex", alignItems: "center", justifyContent: "center" }}>
          <div className="modal" style={{ background: "var(--bg-elevated)", padding: "24px", borderRadius: "12px", maxWidth: "500px", width: "100%", border: "1px solid var(--border-light)" }}>
            <h2 style={{ marginBottom: "16px", color: "var(--text-primary)" }}>Setup Venue Zones</h2>
            <p style={{ color: "var(--text-secondary)", marginBottom: "24px", lineHeight: "1.5" }}>
              You have added zones to this event. How would you like them mapped out in the stadium? 
              <br /><br />
              <strong>Note: Once created, zone layouts cannot be altered later.</strong>
            </p>
            <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
              <button className="btn btn-primary btn-lg" onClick={handleAutoSetup}>
                Automatic (Divide Equally)
              </button>
              <button className="btn btn-secondary btn-lg" onClick={handleManualSetup}>
                Manually Edit Zones
              </button>
            </div>
            <button className="btn btn-ghost" style={{ marginTop: "16px", width: "100%" }} onClick={() => setShowModal(false)}>
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
