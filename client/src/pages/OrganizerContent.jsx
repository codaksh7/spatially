import { useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { LuCalendarPlus, LuStore, LuPlus, LuPencil, LuMapPin, LuClock, LuUser } from "react-icons/lu";

export default function OrganizerContent() {
  const { user } = useAuth();
  const toast = useToast();
  const [events, setEvents] = useState([]);
  const [selectedEventId, setSelectedEventId] = useState("");
  const [activeTab, setActiveTab] = useState("booths"); // booths, sessions
  const [booths, setBooths] = useState([]);
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get("/api/events/organizer/mine")
      .then((data) => {
        setEvents(data.events || []);
        if (data.events && data.events.length > 0) {
          const liveEvent = data.events.find(e => e.status === "live");
          if (liveEvent) {
            setSelectedEventId(liveEvent.id);
          } else {
            const upcomingEvent = data.events.find(e => e.status === "upcoming");
            if (upcomingEvent) {
              setSelectedEventId(upcomingEvent.id);
            } else {
              const endedEvents = data.events.filter(e => e.status === "ended");
              setSelectedEventId(endedEvents.length > 0 ? endedEvents[endedEvents.length - 1].id : data.events[0].id);
            }
          }
        } else {
          setLoading(false);
        }
      })
      .catch((err) => {
        toast(err.message, "error");
        setLoading(false);
      });
  }, []);

  useEffect(() => {
    if (!selectedEventId) return;
    fetchContent();
  }, [selectedEventId, activeTab]);

  const fetchContent = () => {
    setLoading(true);
    if (activeTab === "booths") {
      api.get(`/api/organizer/booths/${selectedEventId}`)
        .then((data) => setBooths(data.booths || []))
        .catch((err) => toast(err.message, "error"))
        .finally(() => setLoading(false));
    } else {
      api.get(`/api/organizer/sessions/${selectedEventId}`)
        .then((data) => setSessions(data.sessions || []))
        .catch((err) => toast(err.message, "error"))
        .finally(() => setLoading(false));
    }
  };

  return (
    <div className="fade-in">
      <div className="page-header">
        <div>
          <h1>Agenda & Content</h1>
          <p style={{ color: "var(--text-muted)", marginTop: "4px" }}>
            Manage exhibitors, booths, schedules, and spatial sessions.
          </p>
        </div>
        <div style={{ display: "flex", gap: "12px" }}>
          {events.length > 0 && (
            <select 
              className="form-select" 
              value={selectedEventId} 
              onChange={(e) => setSelectedEventId(e.target.value)}
              style={{ minWidth: "200px" }}
            >
              {events.map(ev => (
                <option key={ev.id} value={ev.id}>{ev.name} ({ev.status})</option>
              ))}
            </select>
          )}
          <button className="btn btn-primary">
            <LuPlus size={16} /> Add {activeTab === "booths" ? "Booth" : "Session"}
          </button>
        </div>
      </div>

      <div className="card">
        <div style={{ display: "flex", gap: "16px", padding: "16px", borderBottom: "1px solid var(--border-default)" }}>
          <button 
            className={`btn ${activeTab === "booths" ? "btn-secondary" : "btn-ghost"}`}
            onClick={() => setActiveTab("booths")}
            style={{ display: "flex", alignItems: "center", gap: "8px" }}
          >
            <LuStore size={16} /> Exhibitor Booths
          </button>
          <button 
            className={`btn ${activeTab === "sessions" ? "btn-secondary" : "btn-ghost"}`}
            onClick={() => setActiveTab("sessions")}
            style={{ display: "flex", alignItems: "center", gap: "8px" }}
          >
            <LuCalendarPlus size={16} /> Schedule & Sessions
          </button>
        </div>

        {loading ? (
          <div style={{ padding: "40px", textAlign: "center" }}>
            <div className="spinner"></div>
          </div>
        ) : activeTab === "booths" ? (
          // BOOTHS VIEW
          booths.length === 0 ? (
            <div className="empty-state">
              <div className="empty-state-icon"><LuStore /></div>
              <div className="empty-state-title">No booths configured</div>
              <div className="empty-state-text">
                Add exhibitor booths to map them to your spatial zones.
              </div>
            </div>
          ) : (
            <div style={{ overflowX: "auto" }}>
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Booth Name</th>
                    <th>Category</th>
                    <th>Booth #</th>
                    <th>Zone</th>
                    <th>Status</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {booths.map(booth => (
                    <tr key={booth.id}>
                      <td>
                        <div style={{ fontWeight: "600", color: "var(--text-primary)" }}>{booth.name}</div>
                        {booth.contact_name && (
                          <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "2px", display: "flex", alignItems: "center", gap: "4px" }}>
                            <LuUser size={12} /> {booth.contact_name}
                          </div>
                        )}
                      </td>
                      <td>
                        {booth.category ? (
                          <span className="badge" style={{ backgroundColor: "var(--bg-elevated)", color: "var(--text-secondary)" }}>{booth.category}</span>
                        ) : (
                          <span style={{ color: "var(--text-muted)", fontSize: "0.85rem" }}>None</span>
                        )}
                      </td>
                      <td>{booth.booth_number || "-"}</td>
                      <td>
                        <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "var(--text-secondary)", fontSize: "0.85rem" }}>
                          <LuMapPin size={14} />
                          {booth.zone_id ? "Assigned" : "Unmapped"}
                        </div>
                      </td>
                      <td>
                        {booth.is_active !== false ? (
                          <span className="badge success">Active</span>
                        ) : (
                          <span className="badge warning">Inactive</span>
                        )}
                      </td>
                      <td>
                        <button className="btn btn-ghost btn-sm"><LuPencil size={14} /></button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )
        ) : (
          // SESSIONS VIEW
          sessions.length === 0 ? (
            <div className="empty-state">
              <div className="empty-state-icon"><LuCalendarPlus /></div>
              <div className="empty-state-title">No sessions scheduled</div>
              <div className="empty-state-text">
                Create your event agenda and assign sessions to zones.
              </div>
            </div>
          ) : (
            <div style={{ overflowX: "auto" }}>
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Session Title</th>
                    <th>Time</th>
                    <th>Speaker</th>
                    <th>Location / Zone</th>
                    <th>Status</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {sessions.map(session => (
                    <tr key={session.id}>
                      <td>
                        <div style={{ fontWeight: "600", color: "var(--text-primary)" }}>{session.title}</div>
                        <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "2px" }}>
                          {session.session_type.toUpperCase()}
                        </div>
                      </td>
                      <td>
                        <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "var(--text-secondary)", fontSize: "0.85rem" }}>
                          <LuClock size={14} />
                          {session.start_time ? new Date(session.start_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : "TBA"}
                        </div>
                      </td>
                      <td>
                        {session.speaker_name ? (
                          <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "var(--text-secondary)", fontSize: "0.85rem" }}>
                            <LuUser size={14} />
                            {session.speaker_name}
                          </div>
                        ) : (
                          <span style={{ color: "var(--text-muted)", fontSize: "0.85rem" }}>TBA</span>
                        )}
                      </td>
                      <td>
                        <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "var(--text-secondary)", fontSize: "0.85rem" }}>
                          <LuMapPin size={14} />
                          {session.location || "TBA"}
                        </div>
                      </td>
                      <td>
                        {session.status === "scheduled" ? (
                          <span className="badge info">Scheduled</span>
                        ) : session.status === "live" ? (
                          <span className="badge success">Live</span>
                        ) : (
                          <span className="badge" style={{ backgroundColor: "var(--bg-elevated)", color: "var(--text-muted)" }}>Ended</span>
                        )}
                      </td>
                      <td>
                        <button className="btn btn-ghost btn-sm"><LuPencil size={14} /></button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )
        )}
      </div>
    </div>
  );
}
