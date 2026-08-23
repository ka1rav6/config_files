import { useEffect, useState } from "react";

type AssignmentCardProps = {
    title: string;
    marks: number;
    dueDate: string;
    course: string;
    courseCode: string;
    description: string;
};

function checkDueDate(dueDate: string, now: number) {
    const diff = new Date(dueDate).getTime() - now;

    if (diff <= 0) {
        return (
            <span className="text-red-700 font-extrabold">
                OVERDUE
            </span>
        );
    }

    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    const hours = Math.floor(
        (diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60)
    );
    const minutes = Math.floor(
        (diff % (1000 * 60 * 60)) / (1000 * 60)
    );

    return `Time left: ${days} days ${hours} hours ${minutes} minutes`;
}

export default function AssignmentCard({
    title,
    dueDate,
    marks,
    course,
    courseCode,
    description,rror: Cannot call impure function during render
    
    `Date.now` is an impure function. Calling an impure function can produce unstable results that update unpredictably when the component happens to re-render. (https://react.dev/reference/rules/components-and-hooks-must-be-pure#components-and-hooks-must-be-idempotent).
    
    /home/kairav/dev/byld/college-lms/mvp/frontend/src/components/AssignmentCard.tsx:42:36
      40 |     description,
      41 | }: AssignmentCardProps) {
    > 42 |     const [now, setNow] = useState(Date.now());
}: AssignmentCardProps) {
    const [now, setNow] = useState(Date.now());

    useEffect(() => {
        const interval = setInterval(() => {
            setNow(Date.now());
        }, 60000); // update every minute

        return () => clearInterval(interval);
    }, []);

    return (
        <div className="bg-gray-100 dark:bg-gray-800 rounded-lg shadow-2xl p-4 mt-2">
            <h3 className="text-lg font-bold mb-2">{title}</h3>

            <p className="text-gray-600 dark:text-white">
                {description}
            </p>

            <p className="text-sm text-gray-500">
                Course: {course} ({courseCode})
            </p>

            <p className="text-sm text-gray-500">
                Due Date: {dueDate}
            </p>

            <p className="text-sm text-gray-500">
                {checkDueDate(dueDate, now)}
            </p>

            <p className="text-sm text-gray-500">
                Marks: {marks}
            </p>

            <button className="mt-4 bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">
                View Details
            </button>
        </div>
    );
}