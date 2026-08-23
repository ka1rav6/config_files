


async function getCourses(){
    const response = await fetch('/api/courses');
    const courses = await response.json();
    return courses;
};