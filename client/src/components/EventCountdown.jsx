import { useState, useEffect } from "react";
import { LuClock } from "react-icons/lu";

export default function EventCountdown({ eventDate, startTime, onComplete }) {
  const [timeLeft, setTimeLeft] = useState("");
  const [isLive, setIsLive] = useState(false);

  useEffect(() => {
    if (!eventDate) return;

    // Ensure we only take the YYYY-MM-DD part if eventDate contains time
    let datePart = eventDate.includes("T") ? eventDate.split("T")[0] : eventDate;
    
    let targetDateStr = datePart;
    if (startTime) {
      // Ensure startTime has seconds for better cross-browser parsing (e.g. Safari)
      const timePart = startTime.split(":").length === 2 ? `${startTime}:00` : startTime;
      targetDateStr += `T${timePart}`;
    } else {
      targetDateStr += `T00:00:00`;
    }
    
    // Fallback parsing to replace dashes with slashes for older iOS versions
    const safeDateStr = targetDateStr.replace(/-/g, "/").replace("T", " ");
    let target = new Date(targetDateStr).getTime();
    
    if (isNaN(target)) {
       target = new Date(safeDateStr).getTime();
    }

    const updateTimer = () => {
      const now = new Date().getTime();
      const diff = target - now;

      if (diff <= 0) {
        setIsLive(true);
        if (onComplete) onComplete();
        return true; // Stop timer
      }

      // Calculate time components
      const seconds = Math.floor((diff / 1000) % 60);
      const minutes = Math.floor((diff / 1000 / 60) % 60);
      const hours = Math.floor((diff / (1000 * 60 * 60)) % 24);
      const days = Math.floor(diff / (1000 * 60 * 60 * 24));
      
      // Approximation for months (30 days)
      const months = Math.floor(days / 30);
      const remainingDays = days % 30;

      // Formatting based on requirements
      const pad = (num) => String(num).padStart(2, '0');
      
      if (days >= 30) {
        setTimeLeft(`${months}m : ${pad(remainingDays)}d : ${pad(hours)}h`);
      } else if (days >= 2) {
        setTimeLeft(`${days}d : ${pad(hours)}h : ${pad(minutes)}m : ${pad(seconds)}s`);
      } else {
        const totalHours = Math.floor(diff / (1000 * 60 * 60));
        setTimeLeft(`${pad(totalHours)}h : ${pad(minutes)}m : ${pad(seconds)}s`);
      }
      
      return false; // Continue timer
    };

    // Run immediately once
    const finished = updateTimer();
    if (finished) return;

    const interval = setInterval(() => {
      if (updateTimer()) {
        clearInterval(interval);
      }
    }, 1000);

    return () => clearInterval(interval);
  }, [eventDate, startTime, onComplete]);

  if (isLive) {
    return (
      <div className="countdown-container live pulse-animation">
        <span className="badge badge-success" style={{ fontSize: "0.9rem", padding: "4px 10px" }}>
          Live Now
        </span>
      </div>
    );
  }

  return (
    <div className="countdown-container">
      <LuClock className="countdown-icon" />
      <span className="countdown-text" style={{ fontVariantNumeric: "tabular-nums", fontWeight: "600" }}>
        {timeLeft || "Calculating..."}
      </span>
    </div>
  );
}
