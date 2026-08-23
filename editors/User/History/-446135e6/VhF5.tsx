import { useEffect, useState } from "react";

export default function SideBar() {
  const [courses, setCourses] = useState([]);

  useEffect(() => {
    async function getCourses() {
  try {
    const response = await fetch('/api/courses');

    if (!response.ok) {
      return [];
    }

    return await response.json();
  } catch (error) {
    console.error(error);
    return [];
  }
}

    fetchCourses();
  }, []);

  return (
    <div className="w-64 h-screen bg-gray-800 text-white p-4">
      <h2 className="text-xl font-bold mb-4">Courses</h2>

      {courses.length === 0 ? (
        <p>Loading...</p>
      ) : (
        <ul>
          {courses.map((course: { id: string; name: string }) => (
            <li key={course.id}>{course.name}</li>
          ))}
        </ul>
      )}
    </div>
  );
}