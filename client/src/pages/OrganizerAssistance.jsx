import { useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { LuUsers, LuUser, LuClock, LuMapPin, LuCircleCheck } from "react-icons/lu";

export default function OrganizerAssistance() {
  const { user } = useAuth();
  const toast = useToast();
  const [events, setEvents] = useState([]);
  const [selectedEventId, setSelectedEventId] = useState("");
  const [requests, setRequests] = useState([]);
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
    setLoading(true);
    
    api.get(`/api/organizer/assistance/${selectedEventId}`)
      .then((data) => setRequests(data.assistance_requests || []))
      .catch((err) => toast(err.message, "error"))
      .finally(() => setLoading(false));
  }, [selectedEventId]);

  const getStatusBadge = (status) => {
    switch(status) {
      case "reported": return <span className="badge" style={{ backgroundColor: "var(--bg-elevated)", border: "1px solid var(--border-default)", color: "var(--text-secondary)" }}>Pending</span>;
      case "acknowledged": return <span className="badge warning">Acknowledged</span>;
      case "assigned": return <span className="badge info">Assigned</span>;
      case "in_progress": return <span className="badge info">Assisting</span>;
      case "resolved": return <span className="badge success">Resolved</span>;
      case "closed": return <span className="badge" style={{ backgroundColor: "var(--bg-elevated)", color: "var(--text-muted)" }}>Closed</span>;
      default: return <span className="badge">{status}</span>;
    }
  };

  const getPriorityColor = (priority) => {
    switch(priority) {
      case "urgent": return "var(--error)";
      case "important": return "var(--warning)";
      default: return "var(--info)";
    }
  };

  return (
    <div className="fade-in">
      <div className="page-header">
        <div>
          <h1>Attendee Assistance Desk</h1>
          <p style={{ color: "var(--text-muted)", marginTop: "4px" }}>
            Triage help requests, lost & found, and ADA assistance.
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
        </div>
      </div>

      <div className="card">
        <div className="card-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <h3 className="card-title">Live Assistance Queue</h3>
          <span className="badge">{requests.filter(r => !["resolved", "closed"].includes(r.status)).length} Active</span>
        </div>
        
        {loading ? (
          <div style={{ padding: "40px", textAlign: "center" }}>
            <div className="spinner"></div>
          </div>
        ) : requests.length === 0 ? (
          <div className="empty-state">
            <div className="empty-state-icon"><LuCircleCheck color="var(--success)" /></div>
            <div className="empty-state-title">No pending requests</div>
            <div className="empty-state-text">
              There are no attendee assistance requests for this event.
            </div>
          </div>
        ) : (
          <div style={{ overflowX: "auto" }}>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Request Details</th>
                  <th>Status</th>
                  <th>Location / Zone</th>
                  <th>Requested At</th>
                  <th>Assigned Staff</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {requests.map(req => (
                  <tr key={req.id}>
                    <td>
                      <div style={{ display: "flex", alignItems: "flex-start", gap: "12px" }}>
                        <div style={{ 
                          width: "8px", 
                          height: "8px", 
                          borderRadius: "50%", 
                          backgroundColor: getPriorityColor(req.priority),
                          marginTop: "6px"
                        }} />
                        <div>
                          <div style={{ fontWeight: "600", color: "var(--text-primary)" }}>{req.title}</div>
                          {req.description && (
                            <div style={{ fontSize: "0.8rem", color: "var(--text-muted)", marginTop: "2px", display: "-webkit-box", WebkitLineClamp: 1, WebkitBoxOrient: "vertical", overflow: "hidden" }}>
                              {req.description}
                            </div>
                          )}
                        </div>
                      </div>
                    </td>
                    <td>{getStatusBadge(req.status)}</td>
                    <td>
                      <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "var(--text-secondary)", fontSize: "0.85rem" }}>
                        <LuMapPin size={14} />
                        {req.venue_zone_name || "Unknown"}
                      </div>
                    </td>
                    <td>
                      <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "var(--text-secondary)", fontSize: "0.85rem" }}>
                        <LuClock size={14} />
                        {new Date(req.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </div>
                    </td>
                    <td>
                      {req.assigned_to ? (
                        <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "var(--text-secondary)", fontSize: "0.85rem" }}>
                          <LuUser size={14} />
                          {req.assigned_to.substring(0, 8)}...
                        </div>
                      ) : (
                        <span style={{ color: "var(--text-muted)", fontSize: "0.85rem" }}>Unassigned</span>
                      )}
                    </td>
                    <td>
                      <button className="btn btn-ghost btn-sm">Dispatch</button>
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
