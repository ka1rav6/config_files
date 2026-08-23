

export default function SideBar() {
    return (
        <div className="fixed top-0 left-0 h-full w-64 bg-gray-800 text-white p-4">
            <h2 className="text-2xl font-bold mb-6">College LMS</h2>
            <nav>
                <ul>    
                    <li className="mb-4">
                        <a href="#" className="block py-2 px-4 rounded hover:bg-gray-700">Dashboard</a>
                    </li>
                    <li className="mb-4">
                        <a href="#" className="block py-2 px-4 rounded hover:bg-gray-700">Courses</a>
                    </li>
                    <li className="mb-4">
                        <a href="#" className="block py-2 px-4 rounded hover:bg-gray-700">Assignments</a>
                    </li>
                    <li className="mb-4">
                        <a href="#" className="block py-2 px-4 rounded hover:bg-gray-700">Grades</a>
                    </li>
                    <li className="mb-4">
                        <a href="#" className="block py-2 px-4 rounded hover:bg-gray-700">Profile</a>
                    </li>
                </ul>
            </nav>
        </div>
    );
}