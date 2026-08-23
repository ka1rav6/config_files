import { Routes, Route } from "react-router-dom";
import { Home } from "./pages/Home";
// import ThemeToggle from "./components/ThemeToggle";
import SideBar from "./components/SideBar";

const App = () => {
  return (
    <>
      <div className="min-h-screen bg-white text-black dark:bg-blue-950 dark:text-white">
        {/* <SideBar /> */}
    
      <Routes>
      <Route path="/" element={<Home />} />

      </Routes>
      </div>
    </>
  );
};

export default App;