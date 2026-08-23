

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
        </div>
    );
};


export default CourseCard;