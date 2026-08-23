import { useState } from "react";


type AssignmentCardProps = {
    title: string;
    marks: number;
    dueDate: string;
    course: string;
    courseCode: string;
    description: string;
};

function checkDueDate(dueDate: string) {   
    return (
            <>
            {new Date() > new Date(dueDate) ? <span className = "text-red-700 font-extrabold">OVERDUE</span> : "Time left: " + Math.ceil((new Date(dueDate).getTime() - new Date().getTime()) / (1000 * 3600 * 24)) + " days and " + Math.ceil(((new Date(dueDate).getTime() - new Date().getTime()) % (1000 * 3600 * 24)) / (1000 * 3600)) + " hours and " + Math.ceil((((new Date(dueDate).getTime() - new Date().getTime()) % (1000 * 3600 * 24)) % (1000 * 3600)) / (1000 * 60)) + " minutes"}
            </>
    );
}

export default function AssignmentCard({ title, dueDate, marks, course, courseCode, description }: AssignmentCardProps) {
    const [time, setTime] = useState(0); // to rerender the date every minute and show the updated time left or overdue status
    setTimeout(() => {
        setTime(time + 1);
    }, 60000);
    const 
    return (
        <div className="bg-gray-100 dark:bg-gray-800 rounded-lg shadow-2xl p-4 mt-2">
            <h3 className="text-lg font-bold mb-2">{title}</h3>
            <p className="text-gray-600 dark:text-white">{description}</p>
            <span className="text-sm text-gray-500">Course: {course} ({courseCode})</span>
            <p className="text-sm text-gray-500">Due Date: {dueDate}</p>
            <p className = "text-sm text-gray-500"> {checkDueDate(dueDate)}</p>
            <p className="text-sm text-gray-500">Marks: {marks}</p>
            <button className="mt-4 bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"> View Details</button>
        </div>
    );
}