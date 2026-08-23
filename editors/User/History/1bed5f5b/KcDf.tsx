import { useTheme } from "../context/ThemeContext";

export default function ThemeToggle() {
  const { theme, toggleTheme } = useTheme();

  return (
    <button
      onClick={toggleTheme}
      className="rounded px-30 py-2 bg-gray-200 dark:bg-gray-900 dark:text-white cursor-pointer"> 
      {theme === "light" ? "🌙 Dark" : "☀️ Light"}
    </button>
  );
}