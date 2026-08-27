import { useEffect, useState } from "react";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { formatDate, getStatusColor } from "../utils/validators";
import { LuMapPin, LuClock, LuCalendarDays, LuTicket } from "react-icons/lu";

export default function UserEvents() {
  const toast = useToast();
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [registering, setRegistering] = useState(null);

  useEffect(() => {
    api.get("/api/events/public")
      .then((data) => setEvents(data.events || []))
      .catch((err) => toast(err.message, "error"))
      .finally(() => setLoading(false));
  }, []);

  const handleRegister = async (eventId) => {
    setRegistering(eventId);
    try {
      await api.post(`/api/events/${eventId}/register`);
      toast("Successfully registered for the event!", "success");
    } catch (err) {
      toast(err.message, "error");
    } finally {
      setRegistering(null);
    }
  };

  if (loading) {
    return <div className="loading-screen" style={{ minHeight: "60vh" }}><div className="spinner"></div></div>;
  }

  return (
    <div className="fade-in">
      <div className="page-header">
        <h1>Browse Events</h1>
      </div>

      {events.length > 0 ? (
        <div className="events-grid">
          {events.map((event) => (
            <div key={event.id} className="event-card">
              <div className="event-card-header">
                <div className="event-card-title">{event.name}</div>
                <span className={`badge ${getStatusColor(event.status)}`}>{event.status}</span>
              </div>
              {event.organizer_name && (
                <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginBottom: "8px" }}>
                  By {event.organizer_name}
                </div>
              )}
              {event.description && (
                <p style={{ fontSize: "0.8rem", color: "var(--text-muted)", marginBottom: "12px" }}>
                  {event.description.slice(0, 140)}{event.description.length > 140 ? "..." : ""}
                </p>
              )}
              <div className="event-card-meta">
                <div className="event-card-meta-item"><LuMapPin className="meta-icon" size={14} />{event.venue || "Venue TBD"}</div>
                <div className="event-card-meta-item"><LuClock className="meta-icon" size={14} />{formatDate(event.event_date)}</div>
              </div>
              {event.zones?.length > 0 && (
                <div className="event-card-zones" style={{ marginTop: "10px" }}>
                  {event.zones.map((z) => <span key={z} className="zone-tag">{z}</span>)}
                </div>
              )}
              <div className="event-card-footer">
                <span style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>
                  {event.capacity > 0 ? `${event.capacity} spots` : "Open event"}
                </span>
                <button
                  className="btn btn-primary btn-sm"
                  onClick={() => handleRegister(event.id)}
                  disabled={registering === event.id}
                >
                  {registering === event.id ? "Registering..." : "Register"}
                </button>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="empty-state">
          <div className="empty-state-icon"><LuCalendarDays /></div>
          <div className="empty-state-title">No events available</div>
          <div className="empty-state-text">Check back later for upcoming events.</div>
        </div>
      )}
    </div>
  );
}
