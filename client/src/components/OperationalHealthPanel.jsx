import { useState, useEffect } from "react";
import { supabase } from "../utils/supabaseClient";
import { LuActivity, LuTriangleAlert, LuUsers, LuSquareCheck, LuHeartPulse, LuRadioReceiver } from "react-icons/lu";

export default function OperationalHealthPanel({ eventId }) {
  const [healthData, setHealthData] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchHealth = async () => {
    try {
      const { data, error } = await supabase.rpc("get_event_operational_health", {
        p_event_id: eventId
      });
      if (error) throw error;
      setHealthData(data);
    } catch (err) {
      console.error("Failed to fetch operational health", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchHealth();

    // Subscribe to incidents to auto-refresh health stats
    const incidentSub = supabase.channel(`health_incidents_${eventId}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "operational_incidents", filter: `event_id=eq.${eventId}` }, fetchHealth)
      .on("postgres_changes", { event: "*", schema: "public", table: "volunteer_counts", filter: `event_id=eq.${eventId}` }, fetchHealth)
      .on("postgres_changes", { event: "*", schema: "public", table: "volunteer_shifts", filter: `event_id=eq.${eventId}` }, fetchHealth)
      .subscribe();

    return () => {
      supabase.removeChannel(incidentSub);
    };
  }, [eventId]);

  if (loading) {
    return (
      <div className="card" style={{ display: "flex", justifyContent: "center", padding: "40px" }}>
        <div className="spinner spinner-sm"></div>
      </div>
    );
  }

  if (!healthData) return null;

  const getStatusColor = (index) => {
    if (index === "good") return "var(--green-500)";
    if (index === "warning") return "var(--warning)";
    if (index === "critical") return "var(--error)";
    return "var(--text-muted)";
  };

  const statusColor = getStatusColor(healthData.summary?.health_index || "good");

  return (
    <div className="card" style={{ marginBottom: "28px" }}>
      <div className="section-header">
        <h3 className="section-title" style={{ display: "flex", alignItems: "center", gap: "8px" }}>
          <LuHeartPulse size={18} color={statusColor} />
          Operational Health
          <span className="badge" style={{ backgroundColor: statusColor, color: "#fff", marginLeft: "8px", textTransform: "uppercase" }}>
            {healthData.summary?.health_index || "Unknown"}
          </span>
        </h3>
      </div>

      <div className="stats-grid" style={{ gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))", gap: "16px", marginBottom: "24px" }}>
        <div className="stat-card" style={{ padding: "16px" }}>
          <div className="stat-icon error"><LuTriangleAlert /></div>
          <div>
            <div className="stat-value">{healthData.incidents?.active || 0}</div>
            <div className="stat-label">Active Incidents</div>
          </div>
        </div>

        <div className="stat-card" style={{ padding: "16px" }}>
          <div className="stat-icon info"><LuUsers /></div>
          <div>
            <div className="stat-value">{healthData.shifts?.active || 0}</div>
            <div className="stat-label">Active Shifts</div>
          </div>
        </div>

        <div className="stat-card" style={{ padding: "16px" }}>
          <div className="stat-icon success"><LuSquareCheck /></div>
          <div>
            <div className="stat-value">{healthData.tasks?.pending || 0}</div>
            <div className="stat-label">Pending Tasks</div>
          </div>
        </div>

        <div className="stat-card" style={{ padding: "16px" }}>
          <div className="stat-icon warning"><LuRadioReceiver /></div>
          <div>
            <div className="stat-value">{healthData.communications?.urgent || 0}</div>
            <div className="stat-label">Urgent Broadcasts</div>
          </div>
        </div>
      </div>

      {healthData.zones && healthData.zones.length > 0 && (
        <div>
          <h4 style={{ fontSize: "0.9rem", color: "var(--text-secondary)", marginBottom: "12px", textTransform: "uppercase", fontWeight: "600" }}>Zone Status Overview</h4>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: "12px" }}>
            {healthData.zones.map((zone) => (
              <div key={zone.zone_id} style={{ padding: "12px", border: "1px solid var(--border-light)", borderRadius: "var(--radius-md)", background: "var(--bg-primary)" }}>
                <div style={{ fontWeight: "600", marginBottom: "4px", color: "var(--text-primary)" }}>{zone.zone_name}</div>
                <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.8rem", color: "var(--text-secondary)" }}>
                  <span>Staff: {zone.active_staff}</span>
                  <span>Density: <strong style={{ color: getStatusColor(zone.current_density === 'high' ? 'critical' : zone.current_density === 'medium' ? 'warning' : 'good') }}>{zone.current_density}</strong></span>
                </div>
                {zone.active_incidents > 0 && (
                  <div style={{ marginTop: "6px", fontSize: "0.75rem", color: "var(--error)", fontWeight: "500" }}>
                    {zone.active_incidents} Active Incident{zone.active_incidents > 1 ? 's' : ''}
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
