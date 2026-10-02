import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { formatDate } from "../utils/validators";
import { 
  LuRadar, 
  LuSearch,
  LuFilter,
  LuPlus,
  LuTriangleAlert,
  LuCircleCheck,
  LuClock,
  LuMapPin,
  LuUser
} from "react-icons/lu";

export default function OrganizerIncidents() {
  const { user } = useAuth();
  const toast = useToast();
  const [events, setEvents] = useState([]);
  const [selectedEventId, setSelectedEventId] = useState("");
  const [incidents, setIncidents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState("all"); // all, active, resolved

  // Fetch organizer events
  useEffect(() => {
    api.get("/api/events/organizer/mine")
      .then((data) => {
        setEvents(data.events || []);
        if (data.events && data.events.length > 0) {
          // Find live event, else first upcoming, else first
          const liveEvent = data.events.find(e => e.status === "live");
          const upcomingEvent = data.events.find(e => e.status === "upcoming");
          setSelectedEventId(liveEvent?.id || upcomingEvent?.id || data.events[0].id);
        } else {
          setLoading(false);
        }
      })
      .catch((err) => {
        toast(err.message, "error");
        setLoading(false);
      });
  }, []);

  // Fetch incidents for selected event
  useEffect(() => {
    if (!selectedEventId) return;
    setLoading(true);
    
    // In a real app, we'd also subscribe to Supabase Realtime here
    
    api.get(`/api/organizer/incidents/${selectedEventId}`)
      .then((data) => setIncidents(data.incidents || []))
      .catch((err) => toast(err.message, "error"))
      .finally(() => setLoading(false));
  }, [selectedEventId]);

  const filteredIncidents = incidents.filter(inc => {
    if (filter === "active") return ["reported", "acknowledged", "assigned", "in_progress"].includes(inc.status);
    if (filter === "resolved") return ["resolved", "closed"].includes(inc.status);
    return true;
  });

  const getPriorityColor = (priority) => {
    switch(priority) {
      case "urgent": return "var(--error)";
      case "important": return "var(--warning)";
      default: return "var(--info)";
    }
  };

  const getStatusBadge = (status) => {
    switch(status) {
      case "reported": return <span className="badge" style={{ backgroundColor: "var(--bg-elevated)", border: "1px solid var(--border-default)", color: "var(--text-secondary)" }}>Reported</span>;
      case "acknowledged": return <span className="badge warning">Acknowledged</span>;
      case "assigned": return <span className="badge info">Assigned</span>;
      case "in_progress": return <span className="badge info">In Progress</span>;
      case "resolved": return <span className="badge success">Resolved</span>;
      case "closed": return <span className="badge" style={{ backgroundColor: "var(--bg-elevated)", color: "var(--text-muted)" }}>Closed</span>;
      default: return <span className="badge">{status}</span>;
    }
  };

  return (
    <div className="fade-in">
      <div className="page-header">
        <div>
          <h1>Incident Command</h1>
          <p style={{ color: "var(--text-muted)", marginTop: "4px" }}>
            Real-time triage and emergency dispatch
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
            <LuPlus size={16} /> New Incident
          </button>
        </div>
      </div>

      <div className="card" style={{ marginBottom: "24px" }}>
        <div style={{ display: "flex", gap: "16px", padding: "16px", borderBottom: "1px solid var(--border-default)" }}>
          <button 
            className={`btn ${filter === "all" ? "btn-secondary" : "btn-ghost"}`}
            onClick={() => setFilter("all")}
          >
            All Incidents
          </button>
          <button 
            className={`btn ${filter === "active" ? "btn-secondary" : "btn-ghost"}`}
            onClick={() => setFilter("active")}
          >
            Active
          </button>
          <button 
            className={`btn ${filter === "resolved" ? "btn-secondary" : "btn-ghost"}`}
            onClick={() => setFilter("resolved")}
          >
            Resolved
          </button>
        </div>

        {loading ? (
          <div style={{ padding: "40px", textAlign: "center" }}>
            <div className="spinner"></div>
          </div>
        ) : filteredIncidents.length === 0 ? (
          <div className="empty-state">
            <div className="empty-state-icon"><LuCircleCheck color="var(--success)" /></div>
            <div className="empty-state-title">No incidents found</div>
            <div className="empty-state-text">
              The operational zone is clear. No incidents match your current filter.
            </div>
          </div>
        ) : (
          <div style={{ overflowX: "auto" }}>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Incident</th>
                  <th>Status</th>
                  <th>Location / Zone</th>
                  <th>Reported</th>
                  <th>Assigned To</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredIncidents.map(inc => (
                  <tr key={inc.id}>
                    <td>
                      <div style={{ display: "flex", alignItems: "flex-start", gap: "12px" }}>
                        <div style={{ 
                          width: "8px", 
                          height: "8px", 
                          borderRadius: "50%", 
                          backgroundColor: getPriorityColor(inc.priority),
                          marginTop: "6px"
                        }} />
                        <div>
                          <div style={{ fontWeight: "600", color: "var(--text-primary)" }}>{inc.title}</div>
                          <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "2px" }}>
                            {inc.category.toUpperCase()} &middot; {inc.priority.toUpperCase()}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td>{getStatusBadge(inc.status)}</td>
                    <td>
                      <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "var(--text-secondary)", fontSize: "0.85rem" }}>
                        <LuMapPin size={14} />
                        {inc.venue_zone_name || "Unknown"}
                      </div>
                    </td>
                    <td>
                      <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "var(--text-secondary)", fontSize: "0.85rem" }}>
                        <LuClock size={14} />
                        {new Date(inc.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </div>
                    </td>
                    <td>
                      {inc.assigned_to ? (
                        <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "var(--text-secondary)", fontSize: "0.85rem" }}>
                          <LuUser size={14} />
                          {inc.assigned_to.substring(0, 8)}...
                        </div>
                      ) : (
                        <span style={{ color: "var(--text-muted)", fontSize: "0.85rem" }}>Unassigned</span>
                      )}
                    </td>
                    <td>
                      <button className="btn btn-ghost btn-sm">Manage</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
