import { Routes } from "react-router";
import { Route } from "lucide-react";
import {HomePage as Home} from "./pages/HomePage";
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