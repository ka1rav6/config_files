import SideBar from "./components/SideBar";
import ThemeToggle from "./components/ThemeToggle";

const App = () => {
  return (
    <>
    <div className="min-h-screen bg-white text-black dark:bg-gray-900 dark:text-white transition-colors">
      <div className="p-6">
        <ThemeToggle />

      </div>
    </div>
    <SideBar />
    </>
  );
}

export default App;