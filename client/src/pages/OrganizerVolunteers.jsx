import { useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { LuUsers, LuUserPlus, LuShield, LuClock, LuMapPin, LuArrowRight } from "react-icons/lu";
import { Link } from "react-router-dom";

export default function OrganizerVolunteers() {
  const { user } = useAuth();
  const toast = useToast();
  const [events, setEvents] = useState([]);
  const [selectedEventId, setSelectedEventId] = useState("");
  const [shifts, setShifts] = useState([]);
  const [assignments, setAssignments] = useState([]);
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
    
    Promise.all([
      api.get(`/api/organizer/shifts/${selectedEventId}`),
      api.get(`/api/organizer/volunteers/${selectedEventId}`)
    ]).then(([shiftData, volData]) => {
      setShifts(shiftData.shifts || []);
      setAssignments(volData.web_assignments || []);
    }).catch(err => {
      toast(err.message, "error");
    }).finally(() => {
      setLoading(false);
    });
  }, [selectedEventId]);

  const activeShifts = shifts.filter(s => s.status === "active");
  const onBreakShifts = shifts.filter(s => s.break_state === "taking_break");

  return (
    <div className="fade-in">
      <div className="page-header">
        <div>
          <h1>Staff & Shifts</h1>
          <p style={{ color: "var(--text-muted)", marginTop: "4px" }}>
            Monitor active coverage, shift handoffs, and roster assignments.
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
          <Link to="/organizer/invite" className="btn btn-primary">
            <LuUserPlus size={16} /> Invite Staff
          </Link>
        </div>
      </div>

      <div className="stats-grid" style={{ marginBottom: "24px" }}>
        <div className="stat-card">
          <div className="stat-icon info"><LuUsers /></div>
          <div>
            <div className="stat-value">{assignments.length}</div>
            <div className="stat-label">Total Assigned</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon green"><LuShield /></div>
          <div>
            <div className="stat-value">{activeShifts.length}</div>
            <div className="stat-label">Active Shifts</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon warning"><LuClock /></div>
          <div>
            <div className="stat-value">{onBreakShifts.length}</div>
            <div className="stat-label">On Break</div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="card-header">
          <h3 className="card-title">Live Duty Roster</h3>
        </div>
        
        {loading ? (
          <div style={{ padding: "40px", textAlign: "center" }}>
            <div className="spinner"></div>
          </div>
        ) : assignments.length === 0 ? (
          <div className="empty-state">
            <div className="empty-state-icon"><LuUsers /></div>
            <div className="empty-state-title">No staff assigned</div>
            <div className="empty-state-text">
              Invite volunteers to this event and assign them to zones.
            </div>
            <Link to="/organizer/invite" className="btn btn-primary" style={{ marginTop: "16px" }}>
              <LuUserPlus size={16} /> Go to Invitations
            </Link>
          </div>
        ) : (
          <div style={{ overflowX: "auto" }}>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Volunteer</th>
                  <th>Role</th>
                  <th>Assigned Zone</th>
                  <th>Current Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {assignments.map(assign => {
                  const shift = activeShifts.find(s => s.volunteer_id === assign.volunteer_user_id);
                  const isBreak = shift?.break_state === "taking_break";
                  
                  return (
                    <tr key={assign.id}>
                      <td>
                        <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                          <div className="avatar">{assign.volunteer_user_id.substring(0, 2).toUpperCase()}</div>
                          <div>
                            <div style={{ fontWeight: "600", color: "var(--text-primary)" }}>{assign.volunteer_user_id}</div>
                            <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>ID: {assign.id.substring(0, 8)}</div>
                          </div>
                        </div>
                      </td>
                      <td>
                        <span className="badge" style={{ backgroundColor: "var(--bg-elevated)", color: "var(--text-secondary)" }}>
                          {assign.role || "Volunteer"}
                        </span>
                      </td>
                      <td>
                        <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "var(--text-secondary)", fontSize: "0.85rem" }}>
                          <LuMapPin size={14} />
                          {assign.zone || "Unassigned"}
                        </div>
                      </td>
                      <td>
                        {shift ? (
                          isBreak ? (
                            <span className="badge warning">On Break</span>
                          ) : (
                            <span className="badge success">Active Shift</span>
                          )
                        ) : (
                          <span className="badge" style={{ backgroundColor: "var(--bg-elevated)", color: "var(--text-muted)" }}>Off Duty</span>
                        )}
                      </td>
                      <td>
                        <button className="btn btn-ghost btn-sm">Message</button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
