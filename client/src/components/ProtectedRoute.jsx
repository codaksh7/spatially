import { Navigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export default function ProtectedRoute({ children, allowedRoles }) {
  const { user, loading, isAuthenticated } = useAuth();

  if (loading) {
    return (
      <div className="loading-screen">
        <div className="spinner spinner-lg"></div>
        <p>Loading your session...</p>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  if (allowedRoles && !allowedRoles.includes(user.user_type)) {
    const redirectMap = {
      user: "/user/dashboard",
      volunteer: "/volunteer/dashboard",
      organizer: "/organizer/dashboard",
    };
    return <Navigate to={redirectMap[user.user_type] || "/login"} replace />;
  }

  return children;
}
