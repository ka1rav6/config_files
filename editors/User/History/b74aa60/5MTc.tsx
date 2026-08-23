import { Routes, Route } from "react-router-dom";
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