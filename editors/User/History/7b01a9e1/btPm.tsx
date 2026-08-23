import CourseCard from "../components/CourseCard";
import SideBar from "../components/SideBar";



export function Home(){
    return (
        <>
        <SideBar />
            <div className="ml-64 p-4 ml-64 min-h-screen bg-white text-black dark:bg-gray-900 dark:text-white transition-colors">
                <h1 className="text-2xl font-bold mb-4">Welcome to the College LMS Dashboard</h1>
                <p className="text-gray-600">Here you can find an overview of your courses, assignments, and grades.</p>
            </div>
            <div>
                <CourseCard title="Introduction to Programming" courseCode="CS101" professor="Shad Akhtar" description="Learn the basics of programming using Python." />
            </div>
        
        </>
    );
}