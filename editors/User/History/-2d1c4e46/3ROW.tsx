import AssignmentCard from "../components/AssignmentCard";

export default function Assignments() {
    return (
        <>
            <div className="p-4">
                <h1 className="text-2xl font-bold mb-4">Assignments</h1>
            </div>
            <AssignmentCard
                title="Assignment 1: Introduction to Programming"
                course="Introduction to Programming"
                courseCode="CSE101"
                dueDate="2024-07-15"
                marks={100}
                description="This assignment covers the basics of programming using Python. You will be required to write simple programs to demonstrate your understanding of variables, data types, and control structures."
            />
            <AssignmentCard
                title="Assignment 2: Data Structures"
                course="Data Structures and Algorithms"
                courseCode="CSE201"
                dueDate="2024-07-22"
                marks={100}
                description="This assignment focuses on implementing various data structures such as linked lists, stacks, and queues. You will also be required to analyze the time complexity of your implementations."
            />
        </>
    );
}