import AssignmentCard from "../components/AssignmentCard";

export function Assignments() {
    return (
        <div  className="ml-64 p-6">
            <div className="p-4">
                <h1 className="text-2xl font-bold mb-4">Assignments</h1>
            </div>
            <AssignmentCard
                title="Assignment 1: Introduction to Programming"
                course="Introduction to Programming"
                courseCode="CSE101"
                dueDate= {new Date("2025-11-15").toLocaleDateString()}
                marks={100}
                description="Create Metro Project."
            />
            <AssignmentCard
                title="Assignment 2: Computer Organization"
                course="Computer Organization"
                courseCode="CSE211"
                dueDate= {new Date("2026-02-06").toLocaleDateString()}
                marks={100}
                description="Create Assembler and Simulator for RISC-V Instruction Set Architecture."
            />
        </div>
    );
}