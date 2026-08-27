import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { formatDate, formatTime, getStatusColor } from "../utils/validators";
import { LuPlus, LuMapPin, LuClock, LuUsers, LuTicket, LuTrash2, LuCalendarDays } from "react-icons/lu";

export default function OrganizerEvents() {
  const toast = useToast();
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState("all");

  useEffect(() => {
    api.get("/api/events/organizer/mine")
      .then((data) => setEvents(data.events || []))
      .catch((err) => toast(err.message, "error"))
      .finally(() => setLoading(false));
  }, []);

  const handleStatusChange = async (eventId, newStatus) => {
    try {
      await api.put(`/api/events/${eventId}`, { status: newStatus });
      setEvents((prev) => prev.map((e) => e.id === eventId ? { ...e, status: newStatus } : e));
      toast(`Event marked as ${newStatus}`, "success");
    } catch (err) {
      toast(err.message, "error");
    }
  };

  const handleDelete = async (eventId, eventName) => {
    if (!window.confirm(`Are you sure you want to delete "${eventName}"? This action cannot be undone.`)) return;
    try {
      await api.delete(`/api/events/${eventId}`);
      setEvents((prev) => prev.filter((e) => e.id !== eventId));
      toast("Event deleted", "success");
    } catch (err) {
      toast(err.message, "error");
    }
  };

  const filtered = filter === "all" ? events : events.filter((e) => e.status === filter);

  if (loading) {
    return <div className="loading-screen" style={{ minHeight: "60vh" }}><div className="spinner"></div></div>;
  }

  return (
    <div className="fade-in">
      <div className="page-header">
        <div>
          <h1>Events</h1>
          <p style={{ color: "var(--text-muted)", marginTop: "4px" }}>Manage your event portfolio</p>
        </div>
        <Link to="/organizer/create-event" className="btn btn-primary">
          <LuPlus size={16} /> New Event
        </Link>
      </div>

      <div style={{ display: "flex", gap: "8px", marginBottom: "24px", flexWrap: "wrap" }}>
        {["all", "upcoming", "live", "ended"].map((f) => (
          <button
            key={f}
            className={`btn btn-sm ${filter === f ? "btn-primary" : "btn-secondary"}`}
            onClick={() => setFilter(f)}
          >
            {f.charAt(0).toUpperCase() + f.slice(1)} {f !== "all" && `(${events.filter((e) => e.status === f).length})`}
            {f === "all" && ` (${events.length})`}
          </button>
        ))}
      </div>

      {filtered.length > 0 ? (
        <div className="events-grid">
          {filtered.map((event) => (
            <div key={event.id} className="event-card">
              <div className="event-card-header">
                <div className="event-card-title">{event.name}</div>
                <span className={`badge ${getStatusColor(event.status)}`}>{event.status}</span>
              </div>
              {event.description && (
                <p style={{ fontSize: "0.8rem", color: "var(--text-muted)", marginBottom: "12px" }}>
                  {event.description.slice(0, 100)}{event.description.length > 100 ? "..." : ""}
                </p>
              )}
              <div className="event-card-meta">
                <div className="event-card-meta-item"><LuMapPin className="meta-icon" size={14} />{event.venue}</div>
                <div className="event-card-meta-item"><LuClock className="meta-icon" size={14} />{formatDate(event.event_date)}{event.start_time ? ` · ${formatTime(event.start_time)}` : ""}</div>
                {event.capacity > 0 && (
                  <div className="event-card-meta-item"><LuUsers className="meta-icon" size={14} />Capacity: {event.capacity}</div>
                )}
              </div>
              {event.zones?.length > 0 && (
                <div className="event-card-zones" style={{ marginTop: "12px" }}>
                  {event.zones.map((z) => <span key={z} className="zone-tag">{z}</span>)}
                </div>
              )}
              <div className="event-card-footer">
                <div style={{ display: "flex", gap: "6px" }}>
                  {event.status === "upcoming" && (
                    <button className="btn btn-sm btn-primary" onClick={() => handleStatusChange(event.id, "live")}>Go Live</button>
                  )}
                  {event.status === "live" && (
                    <button className="btn btn-sm btn-secondary" onClick={() => handleStatusChange(event.id, "ended")}>End Event</button>
                  )}
                </div>
                <button className="btn btn-sm btn-ghost" onClick={() => handleDelete(event.id, event.name)} style={{ color: "var(--error)" }}>
                  <LuTrash2 size={14} />
                </button>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="empty-state">
          <div className="empty-state-icon"><LuCalendarDays /></div>
          <div className="empty-state-title">{filter === "all" ? "No events yet" : `No ${filter} events`}</div>
          <div className="empty-state-text">
            {filter === "all" ? "Create your first event to get started." : "Change the filter to see other events."}
          </div>
        </div>
      )}
    </div>
  );
}
