import { Routes } from "react-router";
import { Route } from "lucide-react";
import { Home } from "./pages/Home";
// import ThemeToggle from "./components/ThemeToggle";


const App = () => {
  return (
    <>
      <Routes>
      <Route path="/" element={<Home />} />

      </Routes>
    </>
  );
};

export default App;