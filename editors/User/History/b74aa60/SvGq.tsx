import SideBar from "./components/SideBar";
import ThemeToggle from "./components/ThemeToggle";
const App = () => {
  return (
    <>
    {/* <SideBar /> */}
    <div className="min-h-screen bg-white text-black dark:bg-gray-900 dark:text-white transition-colors">
      <div className="p-6">
        <ThemeToggle />

      </div>
    </div>
    </>
  );
}

export default App;