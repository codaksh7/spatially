import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { 
  LuActivity, 
  LuTriangleAlert, 
  LuCircleCheck, 
  LuClock, 
  LuMapPin, 
  LuRadar, 
  LuTicket, 
  LuUsers,
  LuShieldAlert,
  LuTrendingUp,
  LuMessageSquare
} from "react-icons/lu";

export default function OrganizerDashboard() {
  const { user } = useAuth();
  const toast = useToast();
  const [events, setEvents] = useState([]);
  const [selectedEventId, setSelectedEventId] = useState("");
  const [healthData, setHealthData] = useState(null);
  const [loading, setLoading] = useState(true);

  // Fetch events list first
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

  // Fetch health data for selected event
  useEffect(() => {
    if (!selectedEventId) return;
    setLoading(true);
    
    // In production, subscribe to Realtime CDC here
    const fetchHealth = () => {
      api.get(`/api/organizer/health/${selectedEventId}`)
        .then(data => setHealthData(data.health))
        .catch(err => toast(err.message, "error"))
        .finally(() => setLoading(false));
    };

    fetchHealth();
    const interval = setInterval(fetchHealth, 15000); // Poll every 15s as fallback
    return () => clearInterval(interval);
  }, [selectedEventId]);

  if (loading && !healthData) {
    return (
      <div className="loading-screen" style={{ minHeight: "60vh" }}>
        <div className="spinner"></div>
        <div style={{ marginTop: "16px", color: "var(--text-muted)" }}>Initializing Command Center...</div>
      </div>
    );
  }

  return (
    <div className="fade-in">
      <div className="page-header">
        <div>
          <h1 style={{ display: "flex", alignItems: "center", gap: "10px" }}>
            <div style={{ width: "12px", height: "12px", borderRadius: "50%", backgroundColor: "var(--success)", boxShadow: "0 0 10px var(--success)", animation: "pulse 2s infinite" }} />
            Executive Command
          </h1>
          <p style={{ color: "var(--text-muted)", marginTop: "4px" }}>
            Live operational health, incidents, and crowd intelligence.
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

      {!healthData ? (
        <div className="empty-state">
          <div className="empty-state-icon"><LuActivity /></div>
          <div className="empty-state-title">No operational data</div>
          <div className="empty-state-text">
            Start your event to begin tracking operational health.
          </div>
        </div>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
          
          {/* TOP KPI ROW */}
          <div className="stats-grid" style={{ gridTemplateColumns: "repeat(4, 1fr)" }}>
            <div className="stat-card" style={{ borderLeft: "4px solid var(--error)" }}>
              <div className="stat-icon" style={{ color: "var(--error)" }}><LuShieldAlert /></div>
              <div>
                <div className="stat-value" style={{ color: "var(--error)" }}>{healthData.incidents?.active || 0}</div>
                <div className="stat-label">Active Incidents</div>
                <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "4px" }}>
                  {healthData.incidents?.urgent || 0} urgent &middot; {healthData.incidents?.resolved || 0} resolved
                </div>
              </div>
            </div>
            
            <div className="stat-card" style={{ borderLeft: "4px solid var(--info)" }}>
              <div className="stat-icon info"><LuUsers /></div>
              <div>
                <div className="stat-value">{healthData.shifts?.active || 0}</div>
                <div className="stat-label">Active Staff</div>
                <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "4px" }}>
                  {healthData.shifts?.on_break || 0} on break &middot; {healthData.coverage?.pending || 0} requests
                </div>
              </div>
            </div>

            <div className="stat-card" style={{ borderLeft: "4px solid var(--warning)" }}>
              <div className="stat-icon warning"><LuRadar /></div>
              <div>
                <div className="stat-value">{healthData.zones?.reduce((sum, z) => sum + (z.active_count || 0), 0) || 0}</div>
                <div className="stat-label">Detected Devices</div>
                <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "4px" }}>
                  Across {healthData.zones?.filter(z => z.is_monitored)?.length || 0} active zones
                </div>
              </div>
            </div>

            <div className="stat-card" style={{ borderLeft: "4px solid var(--success)" }}>
              <div className="stat-icon success"><LuCircleCheck /></div>
              <div>
                <div className="stat-value">{healthData.tasks?.completed || 0}</div>
                <div className="stat-label">Tasks Completed</div>
                <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "4px" }}>
                  {healthData.tasks?.pending || 0} pending &middot; {healthData.tasks?.in_progress || 0} active
                </div>
              </div>
            </div>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "2fr 1fr", gap: "24px" }}>
            
            {/* ZONE STATUS BOARD */}
            <div className="card">
              <div className="card-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <h3 className="card-title" style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                  <LuMapPin /> Venue Zone Status
                </h3>
                <Link to="/organizer/crowd" className="btn btn-ghost btn-sm">Full Map</Link>
              </div>
              <div style={{ padding: "16px", display: "flex", flexDirection: "column", gap: "12px" }}>
                {healthData.zones?.length === 0 ? (
                  <div style={{ color: "var(--text-muted)", textAlign: "center", padding: "20px" }}>No zones configured</div>
                ) : (
                  healthData.zones?.slice(0, 5).map((zone, idx) => {
                    const capacity = zone.operating_capacity || 0;
                    const ratio = capacity > 0 ? (zone.active_count || 0) / capacity : 0;
                    const isHigh = ratio > 0.85;
                    
                    return (
                      <div key={idx} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "12px", backgroundColor: "var(--bg-secondary)", borderRadius: "8px", borderLeft: isHigh ? "3px solid var(--error)" : "3px solid var(--success)" }}>
                        <div style={{ flex: 1 }}>
                          <div style={{ fontWeight: "600", fontSize: "0.95rem" }}>{zone.zone_name}</div>
                          <div style={{ display: "flex", gap: "16px", fontSize: "0.8rem", color: "var(--text-muted)", marginTop: "4px" }}>
                            <span style={{ display: "flex", alignItems: "center", gap: "4px" }}>
                              <LuUsers size={12} /> {zone.active_staff || 0} Staff
                            </span>
                            {zone.active_incidents > 0 && (
                              <span style={{ display: "flex", alignItems: "center", gap: "4px", color: "var(--error)" }}>
                                <LuTriangleAlert size={12} /> {zone.active_incidents} Incidents
                              </span>
                            )}
                          </div>
                        </div>
                        <div style={{ textAlign: "right" }}>
                          <div style={{ fontSize: "1.2rem", fontWeight: "700", color: isHigh ? "var(--error)" : "var(--text-primary)" }}>
                            {zone.active_count || 0}
                          </div>
                          <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>
                            {capacity > 0 ? `${Math.round(ratio * 100)}% cap` : "devices"}
                          </div>
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </div>

            {/* QUICK ACTIONS & COMMS */}
            <div style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
              <div className="card">
                <div className="card-header">
                  <h3 className="card-title">Quick Dispatch</h3>
                </div>
                <div style={{ padding: "16px", display: "flex", flexDirection: "column", gap: "12px" }}>
                  <Link to="/organizer/incidents" className="btn btn-outline" style={{ justifyContent: "center", borderColor: "var(--error)", color: "var(--error)" }}>
                    <LuShieldAlert size={16} /> Report Emergency
                  </Link>
                  <Link to="/organizer/comms" className="btn btn-outline" style={{ justifyContent: "center", borderColor: "var(--info)", color: "var(--info)" }}>
                    <LuMessageSquare size={16} /> Broadcast Message
                  </Link>
                  <Link to="/organizer/tasks" className="btn btn-outline" style={{ justifyContent: "center" }}>
                    <LuCircleCheck size={16} /> Assign Task
                  </Link>
                </div>
              </div>

              <div className="card">
                <div className="card-header">
                  <h3 className="card-title">Communications</h3>
                </div>
                <div style={{ padding: "16px" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                    <span style={{ color: "var(--text-secondary)" }}>Total Sent</span>
                    <span style={{ fontWeight: "600" }}>{healthData.communications?.total_messages || 0}</span>
                  </div>
                  <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                    <span style={{ color: "var(--text-secondary)" }}>Broadcasts</span>
                    <span style={{ fontWeight: "600" }}>{healthData.communications?.broadcasts || 0}</span>
                  </div>
                  <div style={{ display: "flex", justifyContent: "space-between" }}>
                    <span style={{ color: "var(--text-secondary)" }}>Urgent</span>
                    <span style={{ fontWeight: "600", color: "var(--error)" }}>{healthData.communications?.urgent || 0}</span>
                  </div>
                </div>
              </div>
            </div>
            
          </div>
        </div>
      )}
    </div>
  );
}
