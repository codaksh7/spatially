import { useEffect, useState } from "react";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { formatDate, getStatusColor } from "../utils/validators";
import { LuMapPin, LuClock, LuCalendarDays, LuCircleX } from "react-icons/lu";

export default function UserMyEvents() {
  const toast = useToast();
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [cancelling, setCancelling] = useState(null);

  useEffect(() => {
    api.get("/api/events/user/registered")
      .then((data) => setEvents(data.events || []))
      .catch((err) => toast(err.message, "error"))
      .finally(() => setLoading(false));
  }, []);

  const handleCancel = async (eventId) => {
    if (!window.confirm("Are you sure you want to cancel your registration?")) return;
    setCancelling(eventId);
    try {
      await api.delete(`/api/events/${eventId}/register`);
      setEvents((prev) => prev.filter((e) => e.id !== eventId));
      toast("Registration cancelled", "success");
    } catch (err) {
      toast(err.message, "error");
    } finally {
      setCancelling(null);
    }
  };

  if (loading) {
    return <div className="loading-screen" style={{ minHeight: "60vh" }}><div className="spinner"></div></div>;
  }

  return (
    <div className="fade-in">
      <div className="page-header">
        <h1>My Events</h1>
      </div>

      {events.length > 0 ? (
        <div className="events-grid">
          {events.map((event) => (
            <div key={event.id} className="event-card">
              <div className="event-card-header">
                <div className="event-card-title">{event.name}</div>
                <span className={`badge ${getStatusColor(event.status)}`}>{event.status}</span>
              </div>
              <div className="event-card-meta">
                <div className="event-card-meta-item"><LuMapPin className="meta-icon" size={14} />{event.venue}</div>
                <div className="event-card-meta-item"><LuClock className="meta-icon" size={14} />{formatDate(event.event_date)}</div>
              </div>
              {event.zones?.length > 0 && (
                <div className="event-card-zones" style={{ marginTop: "10px" }}>
                  {event.zones.map((z) => <span key={z} className="zone-tag">{z}</span>)}
                </div>
              )}
              <div className="event-card-footer">
                <span style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>{event.venue}</span>
                {event.status !== "ended" && (
                  <button
                    className="btn btn-sm btn-ghost"
                    style={{ color: "var(--error)" }}
                    onClick={() => handleCancel(event.id)}
                    disabled={cancelling === event.id}
                  >
                    <LuCircleX size={14} />
                    {cancelling === event.id ? "Cancelling..." : "Cancel"}
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="empty-state">
          <div className="empty-state-icon"><LuCalendarDays /></div>
          <div className="empty-state-title">No registered events</div>
          <div className="empty-state-text">Browse events and register to see them here.</div>
        </div>
      )}
    </div>
  );
}
