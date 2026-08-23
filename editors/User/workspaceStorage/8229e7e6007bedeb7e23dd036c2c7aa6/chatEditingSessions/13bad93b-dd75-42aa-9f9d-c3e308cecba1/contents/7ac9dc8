use crate::categories::{self, NewCategory};
use crate::db::{self, Pool};
use anyhow::{Context, Result};
use mlua::{Lua, Table, Value};
use std::cell::RefCell;
use std::path::PathBuf;
use std::rc::Rc;
use serde::Serialize;

const BUNDLED_DEFAULT: &str = include_str!("../../../config/default.lua");

#[derive(Debug, Clone, Serialize, Default)]
pub struct Preferences {
    pub theme: serde_json::Value,
    pub keybindings: serde_json::Value,
    pub workspace: String,
}

pub fn user_config_path() -> PathBuf {
    directories::ProjectDirs::from("dev", "hyprtodo", "hyprtodo")
        .map(|d| d.config_dir().join("config.lua"))
        .unwrap_or_else(|| PathBuf::from("config.lua"))
}

/// Runs `~/.config/hyprtodo/config.lua` (falling back to the bundled
/// default if it doesn't exist) in a sandboxed Lua VM and applies the
/// result to the database. Sandboxed = no `io`, `os`, `require`,
/// `dofile`/`loadfile` — a config file can define categories and layout,
/// it cannot touch the filesystem or shell out.
pub fn load_and_apply(pool: &Pool) -> Result<()> {
    let path = user_config_path();
    let source = std::fs::read_to_string(&path).unwrap_or_else(|_| BUNDLED_DEFAULT.to_string());

    let lua = Lua::new();
    let globals = lua.globals();
    for name in ["io", "os", "require", "dofile", "loadfile"] {
        globals.set(name, Value::Nil)?;
    }

    let collected_categories: Rc<RefCell<Vec<NewCategory>>> = Rc::new(RefCell::new(Vec::new()));
    let collected_columns: Rc<RefCell<u32>> = Rc::new(RefCell::new(2));
    let collected_preferences = Rc::new(RefCell::new(Preferences {
        theme: serde_json::json!({}),
        keybindings: serde_json::json!({}),
        workspace: "todo".to_string(),
    }));

    {
        let out = collected_categories.clone();
        let f = lua.create_function(move |_, (id, opts): (String, Table)| {
            let name: Option<String> = opts.get("name")?;
            let icon: Option<String> = opts.get("icon")?;
            let color: Option<String> = opts.get("color")?;
            out.borrow_mut().push(NewCategory {
                name: name.unwrap_or_else(|| id.clone()),
                id,
                icon,
                color,
            });
            Ok(())
        })?;
        globals.set("category", f)?;
    }
    {
        let out = collected_columns.clone();
        let f = lua.create_function(move |_, n: u32| {
            *out.borrow_mut() = n.clamp(1, 6);
            Ok(())
        })?;
        globals.set("columns", f)?;
    }
    {
        let out = collected_preferences.clone();
        let f = lua.create_function(move |_, opts: Table| {
            let mut preferences = out.borrow_mut();
            let theme: Option<Table> = opts.get("theme")?;
            let keybindings: Option<Table> = opts.get("keybindings")?;
            let workspace: Option<String> = opts.get("workspace")?;
            if let Some(value) = theme {
                preferences.theme = serde_json::json!({
                    "background": value.get::<_, Option<String>>("background")?,
                    "panel_bg": value.get::<_, Option<String>>("panel_bg")?,
                    "foreground": value.get::<_, Option<String>>("foreground")?,
                    "muted": value.get::<_, Option<String>>("muted")?,
                    "accent": value.get::<_, Option<String>>("accent")?,
                    "border": value.get::<_, Option<String>>("border")?,
                });
            }
            if let Some(value) = keybindings {
                let mut pairs = serde_json::Map::new();
                for pair in value.pairs::<String, String>() {
                    let (key, action) = pair?;
                    pairs.insert(key, serde_json::Value::String(action));
                }
                preferences.keybindings = serde_json::Value::Object(pairs);
            }
            if let Some(value) = workspace {
                preferences.workspace = value;
            }
            Ok(())
        })?;
        globals.set("preferences", f)?;
    }

    lua.load(&source)
        .exec()
        .with_context(|| format!("running lua config at {:?}", path))?;

    for cat in collected_categories.borrow().iter() {
        categories::upsert(pool, cat)?;
    }
    db::set_meta(pool, "columns", &collected_columns.borrow().to_string())?;
    db::set_meta(pool, "preferences", &serde_json::to_string(&*collected_preferences.borrow())?)?;

    Ok(())
}
