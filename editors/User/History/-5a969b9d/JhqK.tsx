

type CourseCardProps = {
    title: string;
    courseCode: string;
    professor: string;
    description: string;
};


const CourseCard = ({ title, courseCode, professor, description }: CourseCardProps) => {
    return (
        <div className="bg-gray-100 dark:bg-gray-800 rounded-lg shadow-md p-4">
            <h3 className="text-lg font-bold mb-2">{title}</h3>
            <span className="text-gray-600 dark:text-white">{description}</span>
            <span className="text-sm text-gray-500">Code: {courseCode}</span>
            <p className="text-sm text-gray-500">Professor: {professor}</p>
            <button className="mt-4 bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600">View </button>
        </div>
    );
};


export default CourseCard;