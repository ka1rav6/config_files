

type CourseCardProps = {
    title: string;
    courseCode: string;
    professor: string;
    description: string;
};


const CourseCard = ({ title, courseCode, professor, description }: CourseCardProps) => {
    return (
        <div className="bg-white rounded-lg shadow-md p-4">
            <h3 className="text-lg font-bold mb-2">{title}</h3>
            <p className="text-gray-600">{description}</p>
            <p className="text-sm text-gray-500">Code: {courseCode}</p>
            <p className="text-sm text-gray-500">Professor: {professor}</p>
        </div>
    );
};


export default CourseCard;