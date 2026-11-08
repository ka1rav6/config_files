use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "dev", version, about = "Project scaffolding helpers")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Java / Maven project helpers
    Java {
        #[command(subcommand)]
        cmd: JavaCmd,
    },
}

#[derive(Subcommand)]
enum JavaCmd {
    /// Scaffold a Maven project into an existing directory
    Init {
        /// Directory to scaffold into
        #[arg(default_value = ".")]
        path: PathBuf,
        /// Project name / artifactId (default: the directory's name)
        #[arg(long)]
        name: Option<String>,
        /// Base package (default: com.kairav.<name>)
        #[arg(long)]
        package: Option<String>,
        /// Java release to target
        #[arg(long, default_value = "21")]
        java: String,
        /// Overwrite files that already exist
        #[arg(long)]
        force: bool,
        /// Skip `git init`
        #[arg(long)]
        no_git: bool,
    },
    /// Create a directory and scaffold a Maven project into it
    New {
        name: String,
        #[arg(long)]
        package: Option<String>,
        #[arg(long, default_value = "21")]
        java: String,
        #[arg(long)]
        no_git: bool,
    },
    /// Create a class from a fully-qualified name, making its package dirs
    Class {
        /// e.g. com.kairav.myproject.cache.LruCache
        fqn: String,
        /// Put it under src/test/java as a JUnit 5 test instead
        #[arg(long)]
        test: bool,
    },
    /// Add a dependency to pom.xml: group:artifact:version
    Add {
        coords: String,
        /// Give it <scope>test</scope>
        #[arg(long)]
        test: bool,
    },
}

fn main() -> ExitCode {
    match run(Cli::parse()) {
        Ok(()) => ExitCode::SUCCESS,
        Err(msg) => {
            eprintln!("dev: {msg}");
            ExitCode::FAILURE
        }
    }
}

fn run(cli: Cli) -> Result<(), String> {
    match cli.cmd {
        Cmd::Java { cmd } => match cmd {
            JavaCmd::Init {
                path,
                name,
                package,
                java,
                force,
                no_git,
            } => {
                let name = match name {
                    Some(n) => n,
                    None => dir_name(&path)?,
                };
                scaffold(&path, &name, package, &java, force, no_git)
            }
            JavaCmd::New {
                name,
                package,
                java,
                no_git,
            } => {
                let path = PathBuf::from(&name);
                if path.exists() {
                    return Err(format!("{} already exists", path.display()));
                }
                fs::create_dir_all(&path).map_err(|e| e.to_string())?;
                scaffold(&path, &name, package, &java, false, no_git)
            }
            JavaCmd::Class { fqn, test } => make_class(&fqn, test),
            JavaCmd::Add { coords, test } => add_dep(&coords, test),
        },
    }
}

/// `.` and `..` carry no name, so resolve against the real path first.
fn dir_name(path: &Path) -> Result<String, String> {
    let abs = path
        .canonicalize()
        .map_err(|e| format!("{}: {e}", path.display()))?;
    abs.file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .ok_or_else(|| format!("cannot derive a name from {}", abs.display()))
}

/// Java package segments are lowercase, alphanumeric, and cannot lead with a digit.
fn sanitize_segment(s: &str) -> String {
    let cleaned: String = s
        .chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .flat_map(|c| c.to_lowercase())
        .collect();
    if cleaned.is_empty() {
        "app".to_string()
    } else if cleaned.starts_with(|c: char| c.is_ascii_digit()) {
        format!("p{cleaned}")
    } else {
        cleaned
    }
}

fn scaffold(
    dir: &Path,
    name: &str,
    package: Option<String>,
    java: &str,
    force: bool,
    no_git: bool,
) -> Result<(), String> {
    if !dir.is_dir() {
        return Err(format!("{} is not a directory", dir.display()));
    }
    let package = package.unwrap_or_else(|| format!("com.kairav.{}", sanitize_segment(name)));
    let pkg_path = package.replace('.', "/");
    let main_class = format!("{package}.Main");

    let fill = |t: &str| {
        t.replace("{{NAME}}", name)
            .replace("{{PACKAGE}}", &package)
            .replace("{{MAIN_CLASS}}", &main_class)
            .replace("{{JAVA}}", java)
    };

    let files: Vec<(PathBuf, String)> = vec![
        (dir.join("pom.xml"), fill(POM)),
        (dir.join("Makefile"), fill(MAKEFILE).replace("\n~", "\n\t")),
        (dir.join(".gitignore"), GITIGNORE.to_string()),
        (dir.join("README.md"), fill(README)),
        (
            dir.join(format!("src/main/java/{pkg_path}/Main.java")),
            fill(MAIN_JAVA),
        ),
        (
            dir.join(format!("src/test/java/{pkg_path}/MainTest.java")),
            fill(MAIN_TEST),
        ),
        (dir.join("src/main/resources/.gitkeep"), String::new()),
    ];

    if !force {
        let clashes: Vec<String> = files
            .iter()
            .filter(|(p, _)| p.exists())
            .map(|(p, _)| p.display().to_string())
            .collect();
        if !clashes.is_empty() {
            return Err(format!(
                "these already exist (use --force to overwrite):\n  {}",
                clashes.join("\n  ")
            ));
        }
    }

    for (path, body) in &files {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|e| format!("{}: {e}", parent.display()))?;
        }
        fs::write(path, body).map_err(|e| format!("{}: {e}", path.display()))?;
    }

    println!("scaffolded {name} in {}", dir.display());
    println!("  package {package}");

    if !no_git {
        match git_init(dir) {
            GitInit::Created => println!("  git repo initialized"),
            GitInit::AlreadyInRepo => println!("  already inside a git repo, left alone"),
            GitInit::Failed(e) => eprintln!("  warning: git init skipped: {e}"),
        }
    }

    println!("\nnext: make test");
    Ok(())
}

enum GitInit {
    Created,
    AlreadyInRepo,
    Failed(String),
}

/// `git init` inside an existing worktree would nest a second repo, so check first.
fn git_init(dir: &Path) -> GitInit {
    let inside = Command::new("git")
        .args(["rev-parse", "--is-inside-work-tree"])
        .current_dir(dir)
        .output();
    match inside {
        Ok(out) if out.status.success() => return GitInit::AlreadyInRepo,
        Err(e) => return GitInit::Failed(e.to_string()),
        Ok(_) => {}
    }
    match Command::new("git").arg("init").current_dir(dir).output() {
        Ok(out) if out.status.success() => GitInit::Created,
        Ok(out) => GitInit::Failed(String::from_utf8_lossy(&out.stderr).trim().to_string()),
        Err(e) => GitInit::Failed(e.to_string()),
    }
}

fn find_root() -> Result<PathBuf, String> {
    let mut dir = std::env::current_dir().map_err(|e| e.to_string())?;
    loop {
        if dir.join("pom.xml").is_file() {
            return Ok(dir);
        }
        if !dir.pop() {
            return Err("no pom.xml in this directory or any parent".to_string());
        }
    }
}

fn make_class(fqn: &str, test: bool) -> Result<(), String> {
    let (package, class) = fqn
        .rsplit_once('.')
        .ok_or_else(|| format!("{fqn} is not a fully-qualified name (want com.foo.Bar)"))?;
    if class.is_empty() || package.is_empty() {
        return Err(format!(
            "{fqn} is not a fully-qualified name (want com.foo.Bar)"
        ));
    }

    let root = find_root()?;
    let tree = if test {
        "src/test/java"
    } else {
        "src/main/java"
    };
    let path = root
        .join(tree)
        .join(package.replace('.', "/"))
        .join(format!("{class}.java"));
    if path.exists() {
        return Err(format!("{} already exists", path.display()));
    }

    let template = if test { CLASS_TEST } else { CLASS_MAIN };
    let body = template
        .replace("{{PACKAGE}}", package)
        .replace("{{CLASS}}", class);

    let parent = path.parent().unwrap();
    fs::create_dir_all(parent).map_err(|e| format!("{}: {e}", parent.display()))?;
    fs::write(&path, body).map_err(|e| format!("{}: {e}", path.display()))?;
    println!("{}", path.display());
    Ok(())
}

fn add_dep(coords: &str, test: bool) -> Result<(), String> {
    let parts: Vec<&str> = coords.split(':').collect();
    let [group, artifact, version] = parts.as_slice() else {
        return Err(format!(
            "{coords} is not group:artifact:version (no version lookup, pass it explicitly)"
        ));
    };

    let root = find_root()?;
    let pom_path = root.join("pom.xml");
    let pom = fs::read_to_string(&pom_path).map_err(|e| format!("{}: {e}", pom_path.display()))?;

    if pom.contains(&format!("<artifactId>{artifact}</artifactId>"))
        && pom.contains(&format!("<groupId>{group}</groupId>"))
    {
        return Err(format!("{group}:{artifact} is already in pom.xml"));
    }

    let anchor = "</dependencies>";
    let at = pom
        .find(anchor)
        .ok_or("pom.xml has no <dependencies> block to add to")?;

    let scope = if test {
        "\n      <scope>test</scope>"
    } else {
        ""
    };
    let entry = format!(
        "    <dependency>\n      <groupId>{group}</groupId>\n      <artifactId>{artifact}</artifactId>\n      <version>{version}</version>{scope}\n    </dependency>\n  "
    );

    let mut out = String::with_capacity(pom.len() + entry.len());
    out.push_str(&pom[..at]);
    out.push_str(&entry);
    out.push_str(&pom[at..]);
    fs::write(&pom_path, out).map_err(|e| format!("{}: {e}", pom_path.display()))?;

    println!(
        "added {group}:{artifact}:{version}{}",
        if test { " (test)" } else { "" }
    );
    Ok(())
}

const POM: &str = r##"<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>com.kairav</groupId>
  <artifactId>{{NAME}}</artifactId>
  <version>1.0-SNAPSHOT</version>

  <properties>
    <!-- `release` and not source/target: the old pair compiles against this JDK's
         APIs while claiming an older bytecode level, which fails at runtime. -->
    <maven.compiler.release>{{JAVA}}</maven.compiler.release>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <exec.mainClass>{{MAIN_CLASS}}</exec.mainClass>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.junit.jupiter</groupId>
      <artifactId>junit-jupiter</artifactId>
      <version>5.11.3</version>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.assertj</groupId>
      <artifactId>assertj-core</artifactId>
      <version>3.26.3</version>
      <scope>test</scope>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <!-- Pinned: the maven-compiler-plugin Debian/Ubuntu's Maven binds by default
           is 3.1, which ignores maven.compiler.release and falls back to source 5. -->
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>3.13.0</version>
      </plugin>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-surefire-plugin</artifactId>
        <version>3.5.2</version>
      </plugin>
      <plugin>
        <groupId>org.codehaus.mojo</groupId>
        <artifactId>exec-maven-plugin</artifactId>
        <version>3.5.0</version>
      </plugin>
    </plugins>
  </build>
</project>
"##;

const MAKEFILE: &str = r##"# Generated by `dev java init`. Every target is a plain `mvn` call underneath.
MVN  := mvn -q
MAIN := {{MAIN_CLASS}}

.DEFAULT_GOAL := help
.PHONY: help run test build jar clean deps repl watch

help:
~@grep -E '^[a-z]+:.*?##' $(MAKEFILE_LIST) | sed 's/:.*##/\t/' | expand -t16

run: ## run Main; pass args with ARGS="a b"
~$(MVN) compile exec:java -Dexec.args="$(ARGS)"

# Not $(MVN): -q hides surefire's "Tests run:" summary, so a green run prints nothing.
test: ## run tests; one class/method with T=MainTest or T=MainTest#greetsByName
~$(if $(T),mvn test -Dtest=$(T) -DfailIfNoSpecifiedTests=false,mvn test)

build: ## compile only
~$(MVN) compile

jar: ## package into target/
~$(MVN) package

clean: ## delete target/
~$(MVN) clean

deps: ## print the dependency tree
~mvn dependency:tree

repl: ## jshell with this project and its deps on the classpath
~$(MVN) compile
~$(MVN) dependency:build-classpath -Dmdep.outputFile=target/cp.txt
~jshell --class-path "target/classes:$$(cat target/cp.txt)"

watch: ## rerun tests on save (needs: sudo apt install entr)
~@command -v entr >/dev/null || { echo "entr not installed: sudo apt install entr"; exit 1; }
~find src -name '*.java' | entr -c $(MVN) test
"##;

const GITIGNORE: &str = r##"target/
*.class
*.jar

# Eclipse/jdtls droppings
.classpath
.project
.settings/
.factorypath

.idea/
*.iml
"##;

const README: &str = r##"# {{NAME}}

Java {{JAVA}}, Maven. Base package `{{PACKAGE}}`.

```
make           # list targets
make run       # run Main        (ARGS="a b" to pass arguments)
make test      # run all tests   (T=MainTest#greetsByName for one)
make repl      # jshell with the project on the classpath
make watch     # rerun tests on save
make deps      # dependency tree
```

Scaffolding helpers:

```
dev java class {{PACKAGE}}.cache.LruCache    # makes the package dirs too
dev java class {{PACKAGE}}.cache.LruCacheTest --test
dev java add com.google.guava:guava:33.4.0-jre
```
"##;

const MAIN_JAVA: &str = r##"package {{PACKAGE}};

public class Main {
    public static void main(String[] args) {
        System.out.println(greet(args.length > 0 ? args[0] : "world"));
    }

    static String greet(String who) {
        return "Hello, " + who + "!";
    }
}
"##;

const MAIN_TEST: &str = r##"package {{PACKAGE}};

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class MainTest {
    @Test
    void greetsByName() {
        assertThat(Main.greet("kairav")).isEqualTo("Hello, kairav!");
    }
}
"##;

const CLASS_MAIN: &str = r##"package {{PACKAGE}};

public class {{CLASS}} {
}
"##;

const CLASS_TEST: &str = r##"package {{PACKAGE}};

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class {{CLASS}} {
    @Test
    void placeholder() {
        assertThat(true).isTrue();
    }
}
"##;

#[cfg(test)]
mod tests {
    use super::sanitize_segment;

    #[test]
    fn package_segments_are_legal_java() {
        assert_eq!(sanitize_segment("myProject"), "myproject");
        assert_eq!(sanitize_segment("my-cool_app"), "mycoolapp");
        assert_eq!(sanitize_segment("3d-engine"), "p3dengine"); // cannot lead with a digit
        assert_eq!(sanitize_segment("---"), "app");
    }
}
