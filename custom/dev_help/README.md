# dev_help

Scaffolding CLI, installed as `dev`.

```
dev java init . --name "myProject"   # scaffold into an existing dir (+ git init)
dev java new myProject               # make the dir and scaffold into it
dev java class com.kairav.app.Foo    # create the class AND its package dirs
dev java class com.kairav.app.FooTest --test
dev java add com.google.guava:guava:33.4.0-jre
dev java add org.mockito:mockito-core:5.14.2 --test
```

`init` flags: `--package`, `--java <release>`, `--force`, `--no-git`.
`class` and `add` walk up from the cwd to find `pom.xml`, so they work from anywhere in a project.

## After editing the source

`cargo install` copies the binary; the source is not live.

```
cargo install --path ~/dev/dev_help
```
