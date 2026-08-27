import { useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { formatDate, getStatusColor } from "../utils/validators";
import { LuRadar, LuCalendarDays, LuEye, LuMail, LuMapPin, LuClock } from "react-icons/lu";

export default function VolunteerDashboard() {
  const { user } = useAuth();
  const toast = useToast();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get("/api/dashboard/volunteer")
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
          <h1>Welcome, {user?.nickname || user?.full_name || "Volunteer"}</h1>
          <p style={{ color: "var(--text-muted)", marginTop: "4px" }}>
            {user?.user_id} &middot; Your volunteer command center
          </p>
        </div>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon green"><LuCalendarDays /></div>
          <div>
            <div className="stat-value">{stats.total_assignments || 0}</div>
            <div className="stat-label">Total Assignments</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon olive"><LuRadar /></div>
          <div>
            <div className="stat-value">{stats.live_events || 0}</div>
            <div className="stat-label">Live Events</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon info"><LuEye /></div>
          <div>
            <div className="stat-value">{stats.total_observations || 0}</div>
            <div className="stat-label">Total Observations</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon warning"><LuMail /></div>
          <div>
            <div className="stat-value">{stats.pending_invitations || 0}</div>
            <div className="stat-label">Pending Invitations</div>
          </div>
        </div>
      </div>

      {data?.pending_invitations?.length > 0 && (
        <div style={{ marginBottom: "32px" }}>
          <h3 className="section-title" style={{ marginBottom: "16px" }}>Pending Invitations</h3>
          <div className="events-grid">
            {data.pending_invitations.map((inv) => (
              <div key={inv.id} className="event-card" style={{ borderColor: "var(--warning)" }}>
                <div className="event-card-header">
                  <div className="event-card-title">Event Invitation</div>
                  <span className="badge badge-pending">Pending</span>
                </div>
                <p style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginBottom: "16px" }}>
                  You have been invited to volunteer at this event. Accept or decline from the Invitations page.
                </p>
                <div className="event-card-footer">
                  <span style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>
                    Invited by {inv.invited_by}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <div>
        <h3 className="section-title" style={{ marginBottom: "16px" }}>My Assigned Events</h3>
        {data?.assigned_events?.length > 0 ? (
          <div className="events-grid">
            {data.assigned_events.map((event) => {
              const assignment = data.assignments?.find((a) => a.event_id === event.id);
              return (
                <div key={event.id} className="event-card">
                  <div className="event-card-header">
                    <div className="event-card-title">{event.name}</div>
                    <span className={`badge ${getStatusColor(event.status)}`}>{event.status}</span>
                  </div>
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
                  {assignment?.zone && (
                    <div style={{ marginTop: "8px" }}>
                      <span className="zone-tag" style={{ borderColor: "var(--green-700)" }}>
                        Zone: {assignment.zone}
                      </span>
                    </div>
                  )}
                  {event.zones?.length > 0 && (
                    <div className="event-card-zones" style={{ marginTop: "8px" }}>
                      {event.zones.map((z) => <span key={z} className="zone-tag">{z}</span>)}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        ) : (
          <div className="empty-state">
            <div className="empty-state-icon"><LuCalendarDays /></div>
            <div className="empty-state-title">No assignments yet</div>
            <div className="empty-state-text">
              You will see your event assignments here once an organizer invites you.
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
