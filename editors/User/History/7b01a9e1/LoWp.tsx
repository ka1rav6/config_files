import CourseCard from "../components/CourseCard";
import SideBar from "../components/SideBar";



export function Home() {
    return (
        <div className="min-h-screen bg-white text-black dark:bg-blue-950 dark:text-white">
            <SideBar />



            {/*  TODO: MAKE IT FETCH THE COURSES OF THE STUDENT FROM THE BACKEND  */}



            <main className="ml-64 p-6">
                <h1 className="text-2xl font-bold mb-4">
                    Welcome to the College LMS Dashboard
                </h1>

                <p className="mb-6">
                    Here you can find an overview of your courses.
                </p>

                <CourseCard
                    title="Introduction to Programming"
                    courseCode="CSE101"
                    professor="Shad Akhtar"
                    description="Learn the basics of programming using Python."
                />
                <CourseCard
                    title="Data Structures and Algorithms"
                    courseCode="CSE201"
                    professor="BLA BLA"
                    description="Learn about various data structures and algorithms."
                />
            </main>
        </div>
    );
}