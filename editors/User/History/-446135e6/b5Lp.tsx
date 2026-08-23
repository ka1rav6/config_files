import { Link } from "react-router-dom";
import ThemeToggle from "./ThemeToggle";


export default function SideBar() {
    return (
        <div className="fixed top-0 left-0 h-full w-64 bg-gray-800 text-white p-4">
            <img src = "src/assets/logo.png" alt="IIITD" className="w-full h-auto mb-6" />
            <ThemeToggle />




                {/* TODO: Find a way to load courses from the backend and display them here */}





            <nav className="mt-10">
                <ul>    
                    <li className="mb-4">
                        <Link to="/" className="block py-2 px-4 rounded hover:bg-gray-700">Dashboard</Link>
                    </li>
                    <li className="mb-4">
                        <Link to="/courses" className="block py-2 px-4 rounded hover:bg-gray-700">Courses</Link>
                    </li>
                    <li className="mb-4">
                        <Link to="/assignments" className="block py-2 px-4 rounded hover:bg-gray-700">Assignments</Link>
                    </li>
                    <li className="mb-4">
                        <Link to="/grades" className="block py-2 px-4 rounded hover:bg-gray-700">Grades</Link>
                    </li>
                    <li className="mb-4">
                        <Link to="/profile" className="block py-2 px-4 rounded hover:bg-gray-700">Profile</Link>
                    </li>
                </ul>
            </nav>
        </div>
    );
}