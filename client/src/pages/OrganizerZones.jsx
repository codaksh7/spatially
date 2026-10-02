import { useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { LuMap, LuPlus, LuPencil, LuTrash, LuUsers } from "react-icons/lu";

export default function OrganizerZones() {
  const { user } = useAuth();
  const toast = useToast();
  const [events, setEvents] = useState([]);
  const [selectedEventId, setSelectedEventId] = useState("");
  const [zones, setZones] = useState([]);
  const [loading, setLoading] = useState(true);

  // Form state
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingZone, setEditingZone] = useState(null);
  const [formData, setFormData] = useState({
    name: "",
    code: "",
    capacity_limit: "",
    operating_capacity: "",
    is_crowd_monitored: true,
  });

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
    fetchZones();
  }, [selectedEventId]);

  const fetchZones = () => {
    setLoading(true);
    api.get(`/api/organizer/zones/${selectedEventId}`)
      .then((data) => setZones(data.zones || []))
      .catch((err) => toast(err.message, "error"))
      .finally(() => setLoading(false));
  };

  const handleOpenCreate = () => {
    setEditingZone(null);
    setFormData({
      name: "",
      code: "",
      capacity_limit: "",
      operating_capacity: "",
      is_crowd_monitored: true,
    });
    setIsModalOpen(true);
  };

  const handleOpenEdit = (zone) => {
    setEditingZone(zone);
    setFormData({
      name: zone.name || "",
      code: zone.code || "",
      capacity_limit: zone.capacity_limit || "",
      operating_capacity: zone.operating_capacity || "",
      is_crowd_monitored: zone.is_crowd_monitored ?? true,
    });
    setIsModalOpen(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      const payload = {
        ...formData,
        capacity_limit: formData.capacity_limit ? parseInt(formData.capacity_limit) : null,
        operating_capacity: formData.operating_capacity ? parseInt(formData.operating_capacity) : null,
      };

      if (editingZone) {
        await api.put(`/api/organizer/zones/${editingZone.id}`, payload);
        toast("Zone updated successfully", "success");
      } else {
        await api.post("/api/organizer/zones", {
          ...payload,
          event_id: selectedEventId,
        });
        toast("Zone created successfully", "success");
      }
      setIsModalOpen(false);
      fetchZones();
    } catch (err) {
      toast(err.message, "error");
    }
  };

  return (
    <div className="fade-in">
      <div className="page-header">
        <div>
          <h1>Zone Capacity Editor</h1>
          <p style={{ color: "var(--text-muted)", marginTop: "4px" }}>
            Configure spatial zones, floor plans, and operating capacities.
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
          <button className="btn btn-primary" onClick={handleOpenCreate}>
            <LuPlus size={16} /> Add Zone
          </button>
        </div>
      </div>

      <div className="card">
        {loading ? (
          <div style={{ padding: "40px", textAlign: "center" }}>
            <div className="spinner"></div>
          </div>
        ) : zones.length === 0 ? (
          <div className="empty-state">
            <div className="empty-state-icon"><LuMap /></div>
            <div className="empty-state-title">No zones defined</div>
            <div className="empty-state-text">
              Create spatial zones to track crowd density and assign volunteers.
            </div>
            <button className="btn btn-primary" style={{ marginTop: "16px" }} onClick={handleOpenCreate}>
              <LuPlus size={16} /> Create Zone
            </button>
          </div>
        ) : (
          <div style={{ overflowX: "auto" }}>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Zone Name / Code</th>
                  <th>Legal Capacity Limit</th>
                  <th>Operating Capacity</th>
                  <th>Crowd Monitored</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {zones.map(zone => (
                  <tr key={zone.id}>
                    <td>
                      <div style={{ fontWeight: "600", color: "var(--text-primary)" }}>{zone.name}</div>
                      <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "2px" }}>
                        Code: {zone.code || 'N/A'}
                      </div>
                    </td>
                    <td>{zone.capacity_limit || '∞'}</td>
                    <td>
                      <span style={{ color: "var(--warning)", fontWeight: "600" }}>
                        {zone.operating_capacity || 'Not Set'}
                      </span>
                    </td>
                    <td>
                      {zone.is_crowd_monitored ? (
                        <span className="badge info">Enabled</span>
                      ) : (
                        <span className="badge" style={{ backgroundColor: "var(--bg-elevated)", color: "var(--text-muted)" }}>Disabled</span>
                      )}
                    </td>
                    <td>
                      <div style={{ display: "flex", gap: "8px" }}>
                        <button className="btn btn-ghost btn-sm" onClick={() => handleOpenEdit(zone)}>
                          <LuPencil size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Modal */}
      {isModalOpen && (
        <div className="modal-backdrop fade-in" onClick={() => setIsModalOpen(false)}>
          <div className="modal-content" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>{editingZone ? "Edit Zone" : "Create Zone"}</h3>
              <button className="btn btn-ghost" onClick={() => setIsModalOpen(false)}>&times;</button>
            </div>
            <div className="modal-body">
              <form onSubmit={handleSubmit}>
                <div className="form-group">
                  <label className="form-label">Zone Name</label>
                  <input 
                    type="text" 
                    className="form-select" 
                    placeholder="e.g. Main Hall"
                    value={formData.name}
                    onChange={e => setFormData({...formData, name: e.target.value})}
                    required 
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Short Code (Optional)</label>
                  <input 
                    type="text" 
                    className="form-select" 
                    placeholder="e.g. MH1"
                    value={formData.code}
                    onChange={e => setFormData({...formData, code: e.target.value})}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Legal Fire/Capacity Limit</label>
                  <input 
                    type="number" 
                    className="form-select" 
                    placeholder="e.g. 1000"
                    value={formData.capacity_limit}
                    onChange={e => setFormData({...formData, capacity_limit: e.target.value})}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Soft Operating Capacity (Trigger warnings)</label>
                  <input 
                    type="number" 
                    className="form-select" 
                    placeholder="e.g. 850"
                    value={formData.operating_capacity}
                    onChange={e => setFormData({...formData, operating_capacity: e.target.value})}
                  />
                </div>
                <div className="form-group">
                  <label style={{ display: "flex", alignItems: "center", gap: "8px", cursor: "pointer" }}>
                    <input 
                      type="checkbox" 
                      checked={formData.is_crowd_monitored}
                      onChange={e => setFormData({...formData, is_crowd_monitored: e.target.checked})}
                    />
                    Enable real-time BLE crowd monitoring for this zone
                  </label>
                </div>
                <div style={{ display: "flex", justifyContent: "flex-end", gap: "12px", marginTop: "24px" }}>
                  <button type="button" className="btn btn-ghost" onClick={() => setIsModalOpen(false)}>Cancel</button>
                  <button type="submit" className="btn btn-primary">{editingZone ? "Save Changes" : "Create Zone"}</button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
