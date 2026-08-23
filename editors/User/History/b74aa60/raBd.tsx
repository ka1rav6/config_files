import ThemeToggle from "./components/ThemeToggle";

function App() {
  return (
    <div className="min-h-screen bg-white text-black dark:bg-gray-900 dark:text-white transition-colors">
      <div className="p-6">
        <ThemeToggle />

        <h1 className="mt-6 text-3xl font-bold">
          React + Tailwind Theme Switcher
        </h1>
      <div className="bg-white dark:bg-red-500 min-h-screen light:bg-gray-200 dark:text-white p-4 mt-4 rounded">
        TEST
      </div>
        <p className="mt-2 text-gray-600 dark:text-gray-300">
          This theme changes automatically.
        </p>
      </div>
    </div>
  );
}

export default App;