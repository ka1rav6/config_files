


async function getCourses(){
    const response = await fetch('/api/courses');
    const courses = await response.json();
    return courses;
};

export default async function SideBar() {
    const courses = await getCourses();
    if (!courses) {
        return (<div className="w-64 h-screen bg-white dark:bg-gray-800 dark: text-white p-4 text=black">
            <h2 className="text-xl font-bold mb-4">Courses</h2>
            <p>Loading...</p>
        </div>);
    }
    return (
        <div className="w-64 h-screen bg-gray-800 text-white p-4">
            <h2 className="text-xl font-bold mb-4">Courses</h2>
            <ul>
                {courses.map((course: { id: string; name: string }) => (
                    <li key={course.id} className="mb-2">
                        {course.name}
                    </li>
                ))}
            </ul>
        </div>
    );
}