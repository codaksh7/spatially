import { useEffect, useState, useRef } from "react";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { validateEmail } from "../utils/validators";
import { LuSend, LuMail, LuSearch, LuLoader, LuX, LuRotateCw, LuUsers } from "react-icons/lu";

export default function InviteVolunteer() {
  const toast = useToast();
  const [events, setEvents] = useState([]);
  const [selectedEvent, setSelectedEvent] = useState("");
  
  // Bulk Invite State
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState([]);
  const [selectedVolunteers, setSelectedVolunteers] = useState([]);
  const [isSearching, setIsSearching] = useState(false);
  const [showDropdown, setShowDropdown] = useState(false);
  const searchRef = useRef(null);

  const [volunteerEmail, setVolunteerEmail] = useState("");
  const [errors, setErrors] = useState({});
  const [submittingBulk, setSubmittingBulk] = useState(false);
  const [submittingEmail, setSubmittingEmail] = useState(false);
  const [loading, setLoading] = useState(true);

  // Roster state
  const [roster, setRoster] = useState([]);
  const [loadingRoster, setLoadingRoster] = useState(false);
  const [resendingId, setResendingId] = useState(null);

  useEffect(() => {
    api.get("/api/events/organizer/mine")
      .then((data) => setEvents(data.events || []))
      .catch((err) => toast(err.message, "error"))
      .finally(() => setLoading(false));
  }, []);

  const fetchRoster = async (eventId) => {
    setLoadingRoster(true);
    try {
      const data = await api.get(`/api/volunteers/event/${eventId}/assignments`);
      const combined = [];
      
      const vols = data.volunteers || [];
      const invs = data.invitations || [];
      const asgs = data.assignments || [];

      vols.forEach(v => {
        const isAssigned = asgs.some(a => a.volunteer_user_id === v.user_id);
        const invite = invs.find(i => i.volunteer_user_id === v.user_id);
        
        let status = "pending";
        if (isAssigned) status = "accepted";
        else if (invite) status = invite.status;
        // else they might be manually assigned without an invite, consider accepted if assigned.
        else if (asgs.some(a => a.volunteer_user_id === v.user_id)) status = "accepted";

        combined.push({
          user_id: v.user_id,
          email: v.email,
          full_name: v.full_name,
          status,
          is_email_only: false
        });
      });

      invs.forEach(i => {
        if (!i.volunteer_user_id && !combined.find(r => r.email === i.volunteer_email)) {
          combined.push({
            user_id: null,
            email: i.volunteer_email,
            full_name: "Pending Sign-up",
            status: i.status,
            is_email_only: true
          });
        }
      });

      setRoster(combined);
    } catch (err) {
      toast(err.message, "error");
    } finally {
      setLoadingRoster(false);
    }
  };

  useEffect(() => {
    if (selectedEvent) {
      fetchRoster(selectedEvent);
    } else {
      setRoster([]);
    }
  }, [selectedEvent]);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (searchRef.current && !searchRef.current.contains(event.target)) {
        setShowDropdown(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  // Debounced search
  useEffect(() => {
    if (!searchQuery.trim()) {
      setSearchResults([]);
      return;
    }
    
    const timeoutId = setTimeout(async () => {
      setIsSearching(true);
      try {
        const data = await api.get(`/api/volunteers/search?q=${encodeURIComponent(searchQuery)}`);
        // Filter out already selected volunteers
        const filtered = (data.volunteers || []).filter(
          v => !selectedVolunteers.find(s => s.user_id === v.user_id)
        );
        setSearchResults(filtered);
      } catch (err) {
        console.error("Search error", err);
      } finally {
        setIsSearching(false);
      }
    }, 300);
    
    return () => clearTimeout(timeoutId);
  }, [searchQuery, selectedVolunteers]);

  const addVolunteer = (vol) => {
    if (!selectedVolunteers.find(s => s.user_id === vol.user_id)) {
      setSelectedVolunteers([...selectedVolunteers, vol]);
    }
    setSearchQuery("");
    setShowDropdown(false);
    setErrors((p) => ({ ...p, bulk: null }));
  };

  const removeVolunteer = (userId) => {
    setSelectedVolunteers(selectedVolunteers.filter(v => v.user_id !== userId));
  };

  const handleInviteBulk = async (e) => {
    e.preventDefault();
    const newErrors = {};
    if (!selectedEvent) newErrors.event = "Select an event";
    if (selectedVolunteers.length === 0) newErrors.bulk = "Select at least one volunteer";
    setErrors(newErrors);
    
    if (Object.keys(newErrors).length > 0) return;

    setSubmittingBulk(true);
    try {
      const data = await api.post("/api/volunteers/invite-bulk", {
        event_id: selectedEvent,
        volunteer_ids: selectedVolunteers.map(v => v.user_id),
      });
      
      const { success, failed } = data.results;
      if (failed.length === 0) {
        toast(`Successfully sent invitations to ${success.length} volunteer(s)!`, "success");
        setSelectedVolunteers([]);
      } else if (success.length === 0) {
        toast(`Failed to invite: ${failed.map(f => `${f.id} (${f.reason})`).join(", ")}`, "error");
      } else {
        toast(`Invited ${success.length} volunteer(s). Failed: ${failed.length}`, "warning");
        const failedIds = failed.map(f => f.id);
        setSelectedVolunteers(selectedVolunteers.filter(v => failedIds.includes(v.user_id)));
      }
      
      fetchRoster(selectedEvent); // Refresh roster
    } catch (err) {
      toast(err.message, "error");
    } finally {
      setSubmittingBulk(false);
    }
  };

  const handleInviteByEmail = async (e) => {
    e.preventDefault();
    const newErrors = {};
    if (!selectedEvent) newErrors.event = "Select an event";
    const emailErr = validateEmail(volunteerEmail);
    if (emailErr) newErrors.volunteerEmail = emailErr;
    setErrors(newErrors);
    
    if (Object.keys(newErrors).length > 0) return;

    setSubmittingEmail(true);
    try {
      const data = await api.post("/api/volunteers/invite-by-email", {
        event_id: selectedEvent,
        email: volunteerEmail,
      });
      toast(data.message, "success");
      setVolunteerEmail("");
      fetchRoster(selectedEvent); // Refresh roster
    } catch (err) {
      toast(err.message, "error");
    } finally {
      setSubmittingEmail(false);
    }
  };

  const handleResend = async (vol) => {
    setResendingId(vol.user_id || vol.email);
    try {
      if (vol.is_email_only) {
        await api.post("/api/volunteers/invite-by-email", {
          event_id: selectedEvent,
          email: vol.email
        });
      } else {
        await api.post("/api/volunteers/invite-bulk", {
          event_id: selectedEvent,
          volunteer_ids: [vol.user_id]
        });
      }
      toast(`Invitation resent to ${vol.full_name || vol.email}`, "success");
      fetchRoster(selectedEvent);
    } catch (err) {
      toast(err.message, "error");
    } finally {
      setResendingId(null);
    }
  };

  if (loading) {
    return <div className="loading-screen" style={{ minHeight: "60vh" }}><div className="spinner"></div></div>;
  }

  return (
    <div className="fade-in">
      <div className="page-header">
        <h1>Invite Volunteers</h1>
      </div>

      <div className="form-group" style={{ maxWidth: "400px", marginBottom: "28px" }}>
        <label className="form-label">Select Event</label>
        <select
          className={`form-select ${errors.event ? "error" : ""}`}
          value={selectedEvent}
          onChange={(e) => { setSelectedEvent(e.target.value); setErrors((p) => ({ ...p, event: null })); }}
        >
          <option value="">Choose an event...</option>
          {events.map((ev) => (
            <option key={ev.id} value={ev.id}>{ev.name} ({ev.status})</option>
          ))}
        </select>
        {errors.event && <p className="form-error">{errors.event}</p>}
      </div>

      {selectedEvent && (
        <div style={{ marginBottom: "32px" }}>
          <div className="section-header">
            <h3 className="section-title"><LuUsers style={{ verticalAlign: "middle", marginRight: "8px" }} /> Event Roster & Invitations</h3>
          </div>
          <div className="card">
            {loadingRoster ? (
              <div style={{ display: "flex", justifyContent: "center", padding: "20px" }}>
                <div className="spinner spinner-sm"></div>
              </div>
            ) : roster.length > 0 ? (
              <div className="table-container">
                <table className="table">
                  <thead>
                    <tr>
                      <th>Volunteer</th>
                      <th>Email</th>
                      <th>Status</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {roster.map((r, i) => (
                      <tr key={i}>
                        <td>
                          <div style={{ fontWeight: 500, color: "var(--text-primary)" }}>{r.full_name}</div>
                          {r.user_id && <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>{r.user_id}</div>}
                        </td>
                        <td>{r.email}</td>
                        <td>
                          {r.status === "accepted" && <span className="badge badge-success">Assigned</span>}
                          {r.status === "pending" && <span className="badge badge-pending">Pending</span>}
                          {r.status === "declined" && <span className="badge badge-error">Declined</span>}
                        </td>
                        <td>
                          {r.status === "declined" && (
                            <button
                              className="btn btn-secondary btn-sm"
                              onClick={() => handleResend(r)}
                              disabled={resendingId === (r.user_id || r.email)}
                            >
                              {resendingId === (r.user_id || r.email) ? (
                                <LuLoader style={{ animation: "spin 0.8s linear infinite" }} />
                              ) : (
                                <><LuRotateCw size={14} /> Resend</>
                              )}
                            </button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="empty-state">
                <div className="empty-state-text">No volunteers have been assigned or invited to this event yet.</div>
              </div>
            )}
          </div>
        </div>
      )}

      <div className="invite-section">
        <div className="invite-card">
          <h3><LuSearch size={18} style={{ verticalAlign: "middle", marginRight: "8px" }} />Invite Existing Volunteers</h3>
          <p className="invite-desc">Search by Volunteer ID or Name to assign them directly to this event.</p>

          <form onSubmit={handleInviteBulk} noValidate>
            <div className="form-group" ref={searchRef}>
              <label className="form-label">Search Volunteers</label>
              
              <div className="zone-chips" style={{ marginBottom: selectedVolunteers.length ? "10px" : "0" }}>
                {selectedVolunteers.map(vol => (
                  <span key={vol.user_id} className="zone-chip">
                    {vol.full_name || vol.email} ({vol.user_id})
                    <button type="button" className="zone-chip-remove" onClick={() => removeVolunteer(vol.user_id)}>
                      <LuX size={14} />
                    </button>
                  </span>
                ))}
              </div>

              <div style={{ position: "relative" }}>
                <input
                  type="text"
                  className={`form-input ${errors.bulk ? "error" : ""}`}
                  placeholder="Type name or ID (e.g. V1)..."
                  value={searchQuery}
                  onChange={(e) => {
                    setSearchQuery(e.target.value);
                    setShowDropdown(true);
                  }}
                  onFocus={() => setShowDropdown(true)}
                  disabled={!selectedEvent}
                />
                
                {showDropdown && searchQuery.trim() && (
                  <div className="autocomplete-dropdown">
                    {isSearching ? (
                      <div className="autocomplete-item text-muted">Searching...</div>
                    ) : searchResults.length > 0 ? (
                      searchResults.map(vol => (
                        <div 
                          key={vol.user_id} 
                          className="autocomplete-item"
                          onClick={() => addVolunteer(vol)}
                        >
                          <div style={{ fontWeight: 500 }}>{vol.full_name || "No Name"}</div>
                          <div style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>
                            {vol.user_id} &bull; {vol.email}
                          </div>
                        </div>
                      ))
                    ) : (
                      <div className="autocomplete-item text-muted">No volunteers found</div>
                    )}
                  </div>
                )}
              </div>
              {errors.bulk && <p className="form-error">{errors.bulk}</p>}
            </div>

            <button type="submit" className="btn btn-primary" disabled={submittingBulk || selectedVolunteers.length === 0 || !selectedEvent}>
              {submittingBulk ? <LuLoader style={{ animation: "spin 0.8s linear infinite" }} /> : <LuSend size={14} />}
              Send Invite{selectedVolunteers.length !== 1 ? "s" : ""}
            </button>
          </form>
        </div>

        <div className="invite-card">
          <h3><LuMail size={18} style={{ verticalAlign: "middle", marginRight: "8px" }} />Invite New Volunteer by Email</h3>
          <p className="invite-desc">
            If the volunteer does not have an account, send them an invitation email to sign up and join the event.
          </p>

          <form onSubmit={handleInviteByEmail} noValidate>
            <div className="form-group">
              <label className="form-label" htmlFor="vol-email-input">Volunteer Email</label>
              <input
                id="vol-email-input"
                type="email"
                className={`form-input ${errors.volunteerEmail ? "error" : ""}`}
                placeholder="volunteer@example.com"
                value={volunteerEmail}
                onChange={(e) => { setVolunteerEmail(e.target.value); setErrors((p) => ({ ...p, volunteerEmail: null })); }}
                spellCheck="false"
                disabled={!selectedEvent}
              />
              {errors.volunteerEmail && <p className="form-error">{errors.volunteerEmail}</p>}
            </div>
            <button type="submit" className="btn btn-primary" disabled={submittingEmail || !selectedEvent}>
              {submittingEmail ? <LuLoader style={{ animation: "spin 0.8s linear infinite" }} /> : <LuMail size={14} />}
              Send Invitation Email
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
