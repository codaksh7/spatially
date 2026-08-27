import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { formatDate, getStatusColor } from "../utils/validators";
import { LuCalendarDays, LuTicket, LuRadar, LuArrowRight, LuMapPin, LuClock } from "react-icons/lu";

export default function UserDashboard() {
  const { user } = useAuth();
  const toast = useToast();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get("/api/dashboard/user")
      .then(setData)
      .catch((err) => toast(err.message, "error"))
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="loading-screen" style={{ minHeight: "60vh" }}>
        <div className="spinner"></div>
      </div>
    );
  }

  const stats = data?.stats || {};

  return (
    <div className="fade-in">
      <div className="page-header">
        <div>
          <h1>Welcome, {user?.full_name || "User"}</h1>
          <p style={{ color: "var(--text-muted)", marginTop: "4px" }}>
            {user?.user_id} &middot; Browse and register for upcoming events
          </p>
        </div>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon green"><LuTicket /></div>
          <div>
            <div className="stat-value">{stats.total_registered || 0}</div>
            <div className="stat-label">Registered Events</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon olive"><LuRadar /></div>
          <div>
            <div className="stat-value">{stats.live_events || 0}</div>
            <div className="stat-label">Live Right Now</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon info"><LuCalendarDays /></div>
          <div>
            <div className="stat-value">{stats.upcoming_events || 0}</div>
            <div className="stat-label">Upcoming Events</div>
          </div>
        </div>
      </div>

      {data?.registered_events?.length > 0 && (
        <div style={{ marginBottom: "32px" }}>
          <div className="section-header">
            <h3 className="section-title">My Registered Events</h3>
            <Link to="/user/my-events" className="btn btn-ghost btn-sm">
              View All <LuArrowRight size={14} />
            </Link>
          </div>
          <div className="events-grid">
            {data.registered_events.slice(0, 3).map((event) => (
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
                <div className="event-card-meta">
                  <div className="event-card-meta-item">
                    <LuMapPin className="meta-icon" size={14} />
                    {event.venue || "Venue TBD"}
                  </div>
                  <div className="event-card-meta-item">
                    <LuClock className="meta-icon" size={14} />
                    {formatDate(event.event_date)}
                  </div>
                </div>
                {event.zones?.length > 0 && (
                  <div className="event-card-zones">
                    {event.zones.map((z) => <span key={z} className="zone-tag">{z}</span>)}
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      <div>
        <div className="section-header">
          <h3 className="section-title">Upcoming Events</h3>
          <Link to="/user/events" className="btn btn-ghost btn-sm">
            Browse All <LuArrowRight size={14} />
          </Link>
        </div>
        {data?.upcoming_events?.length > 0 ? (
          <div className="events-grid">
            {data.upcoming_events.slice(0, 6).map((event) => (
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
                <div className="event-card-meta">
                  <div className="event-card-meta-item">
                    <LuMapPin className="meta-icon" size={14} />
                    {event.venue || "Venue TBD"}
                  </div>
                  <div className="event-card-meta-item">
                    <LuClock className="meta-icon" size={14} />
                    {formatDate(event.event_date)}
                  </div>
                </div>
                {event.description && (
                  <p style={{ fontSize: "0.8rem", color: "var(--text-muted)", margin: "8px 0 0" }}>
                    {event.description.slice(0, 120)}{event.description.length > 120 ? "..." : ""}
                  </p>
                )}
              </div>
            ))}
          </div>
        ) : (
          <div className="empty-state">
            <div className="empty-state-icon">
              <LuCalendarDays />
            </div>
            <div className="empty-state-title">No upcoming events</div>
            <div className="empty-state-text">
              Check back later for new events to register for.
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
