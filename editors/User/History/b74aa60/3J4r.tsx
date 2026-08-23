import SideBar from "./components/SideBar";
import ThemeToggle from "./components/ThemeToggle";
const App = () => {
  return (
    <div className="flex">
      <SideBar />

      <div className="flex-1 min-h-screen bg-white text-black dark:bg-gray-900 dark:text-white transition-colors">
        <div className="p-6">
          <ThemeToggle />
        </div>
      </div>
    </div>
  );
};

export default App;