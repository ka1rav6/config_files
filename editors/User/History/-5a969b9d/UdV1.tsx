

type CourseCardProps = {
    title: string;
    courseCode: string;
    professor: string;
    description: string;
};


const CourseCard = ({ title, courseCode, professor, description }: CourseCardProps) => {
    return (
        <div className="bg-gray-100 dark:bg-gray-800 rounded-lg shadow-2xl p-4 mt-2">
            <h3 className="text-lg font-bold mb-2">{title}</h3>
            <p className="text-gray-600 dark:text-white">{description}</p>
            <span className="text-sm text-gray-500">Code: {courseCode}</span>
            <p className="text-sm text-gray-500">Professor: {professor}</p>
            <button className="mt-4 bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"> Go To Course</button>
            <button className="mt-4 ml-2 bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600"> View Assignments</button>
            <button className="mt-4 ml-2 bg-yellow-500 text-white px-4 py-2 rounded hover:bg-yellow-600"> View Grades</button>
            <button className="mt-4 ml-2 bg-red-500 text-white px-4 py-2 rounded hover:bg-red-600"> View Marks Distribution</button>
        </div>
    );
};


export default CourseCard;