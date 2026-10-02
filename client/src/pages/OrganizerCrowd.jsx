import { useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { LuRadar, LuMapPin, LuTrendingUp, LuTriangleAlert, LuUsers } from "react-icons/lu";
import { Link } from "react-router-dom";

export default function OrganizerCrowd() {
  const { user } = useAuth();
  const toast = useToast();
  const [events, setEvents] = useState([]);
  const [selectedEventId, setSelectedEventId] = useState("");
  const [crowdData, setCrowdData] = useState(null);
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
    fetchCrowdData();
    // Refresh every 10 seconds
    const interval = setInterval(fetchCrowdData, 10000);
    return () => clearInterval(interval);
  }, [selectedEventId]);

  const fetchCrowdData = () => {
    api.get(`/api/organizer/crowd/${selectedEventId}`)
      .then((data) => {
        setCrowdData(data);
        setLoading(false);
      })
      .catch((err) => {
        toast(err.message, "error");
        setLoading(false);
      });
  };

  const getDensityColor = (current, capacity) => {
    if (!capacity) return "var(--info)";
    const ratio = current / capacity;
    if (ratio > 0.9) return "var(--error)";
    if (ratio > 0.75) return "var(--warning)";
    return "var(--success)";
  };

  const totalCrowd = crowdData?.zone_density ? Object.values(crowdData.zone_density).reduce((sum, zone) => sum + zone.active_count, 0) : 0;
  const totalCapacity = crowdData?.zone_density ? Object.values(crowdData.zone_density).reduce((sum, zone) => sum + (zone.operating_capacity || 0), 0) : 0;

  return (
    <div className="fade-in">
      <div className="page-header">
        <div>
          <h1 style={{ display: "flex", alignItems: "center", gap: "10px" }}>
            <div style={{ width: "12px", height: "12px", borderRadius: "50%", backgroundColor: "var(--error)", boxShadow: "0 0 10px var(--error)", animation: "pulse 2s infinite" }} />
            Live Crowd Feed
          </h1>
          <p style={{ color: "var(--text-muted)", marginTop: "4px" }}>
            Real-time BLE telemetry from volunteer devices across zones.
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

      {loading ? (
        <div style={{ padding: "40px", textAlign: "center" }}>
          <div className="spinner"></div>
        </div>
      ) : !crowdData ? (
        <div className="empty-state">
          <div className="empty-state-icon"><LuRadar /></div>
          <div className="empty-state-title">No telemetry data</div>
          <div className="empty-state-text">
            Start the event and assign volunteers to zones to begin collecting BLE presence data.
          </div>
        </div>
      ) : (
        <>
          <div className="stats-grid" style={{ marginBottom: "24px" }}>
            <div className="stat-card">
              <div className="stat-icon info"><LuUsers /></div>
              <div>
                <div className="stat-value">{totalCrowd}</div>
                <div className="stat-label">Total Unique Devices</div>
              </div>
            </div>
            <div className="stat-card">
              <div className="stat-icon" style={{ color: getDensityColor(totalCrowd, totalCapacity) }}><LuTrendingUp /></div>
              <div>
                <div className="stat-value">{totalCapacity > 0 ? Math.round((totalCrowd / totalCapacity) * 100) : 0}%</div>
                <div className="stat-label">Overall Venue Utilization</div>
              </div>
            </div>
            <div className="stat-card">
              <div className="stat-icon warning"><LuRadar /></div>
              <div>
                <div className="stat-value">{crowdData.raw_counts?.length || 0}</div>
                <div className="stat-label">Active Scanners</div>
              </div>
            </div>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(300px, 1fr))", gap: "20px" }}>
            {Object.entries(crowdData.zone_density || {}).map(([zoneName, data]) => {
              const capacity = data.operating_capacity || 0;
              const ratio = capacity > 0 ? data.active_count / capacity : 0;
              const densityColor = getDensityColor(data.active_count, capacity);
              const isOvercrowded = ratio > 0.9;
              
              return (
                <div key={zoneName} className="card" style={{ padding: "20px", border: isOvercrowded ? "1px solid var(--error)" : undefined }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "16px" }}>
                    <div>
                      <h3 style={{ fontSize: "1.1rem", fontWeight: "600", display: "flex", alignItems: "center", gap: "6px" }}>
                        <LuMapPin size={16} color="var(--text-muted)" />
                        {zoneName}
                      </h3>
                      <div style={{ fontSize: "0.8rem", color: "var(--text-muted)", marginTop: "4px" }}>
                        {data.volunteer_scanners} active scanner(s)
                      </div>
                    </div>
                    {isOvercrowded && (
                      <div className="badge" style={{ backgroundColor: "var(--error)", color: "#fff", display: "flex", alignItems: "center", gap: "4px" }}>
                        <LuTriangleAlert size={12} /> Over Capacity
                      </div>
                    )}
                  </div>
                  
                  <div style={{ display: "flex", alignItems: "flex-end", gap: "8px", marginBottom: "12px" }}>
                    <div style={{ fontSize: "2.5rem", fontWeight: "700", lineHeight: "1", color: densityColor }}>
                      {data.active_count}
                    </div>
                    <div style={{ fontSize: "0.9rem", color: "var(--text-muted)", paddingBottom: "4px" }}>
                      / {capacity > 0 ? capacity : "∞"} devices
                    </div>
                  </div>
                  
                  {capacity > 0 && (
                    <div style={{ width: "100%", height: "8px", backgroundColor: "var(--bg-secondary)", borderRadius: "4px", overflow: "hidden" }}>
                      <div style={{ 
                        height: "100%", 
                        width: `${Math.min(ratio * 100, 100)}%`, 
                        backgroundColor: densityColor,
                        transition: "width 1s ease-in-out"
                      }} />
                    </div>
                  )}
                  
                  {isOvercrowded && (
                    <div style={{ marginTop: "16px", paddingTop: "16px", borderTop: "1px solid var(--border-default)" }}>
                      <button className="btn btn-outline" style={{ width: "100%", borderColor: "var(--error)", color: "var(--error)" }}>
                        Dispatch Crowd Control
                      </button>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}
