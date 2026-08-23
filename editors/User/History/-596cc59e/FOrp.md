# Vela

Vela is a small, fast, embeddable rule engine written in C. You give it a JSON file describing facts and rules, it builds an internal representation once, and then evaluates rules against your facts as fast as possible. It's designed to be dropped directly into a C/C++ project rather than run as a separate service.

## Why Vela

Most rule engines either pull in a scripting language runtime or re-parse/re-walk a tree on every evaluation. Vela avoids both. Rules are compiled once — first into an AST, then into a flat bytecode program — and after that, evaluating a rule is a tight loop over an array with no recursion and no tree pointer chasing. Boolean facts are stored as bits in a fixed bitmask rather than as individual heap-allocated booleans, so checking a fact is a single shift-and-mask instead of a struct dereference.
In a project like a game engine, vela shines. If you have to have a function that gets called even once per frame and it has 50 conditions (player.isAlive() etc etc), thats still50 conditions recomputed every single time! With vela, you can change the facts and have a very fast computation! It wont even need to recompute all rules : just the ones that are affected by those fact changes ! [ FUTURE IMPROVEMENT : DEPENDENCY TRACKING ]

## How it works

### 1. JSON in, AST out

You describe facts and rules in a JSON file:

```json
{
  "facts": {
    "isAdmin": true,
    "age": 25,
    "balance": 1500
  },
  "rules": [
    {
      "name": "rule_adult_admin",
      "action": "GRANT_ACCESS",
      "if": {
        "and": ["isAdmin", { ">": ["age", 18] }]
      }
    }
  ]
}
```

`jsonParser.c` reads this with [yyjson](https://github.com/ibireme/yyjson) and walks it recursively, turning each condition into a tree of `Node`s (`ConditionTree.h`). `AND`/`OR`/`NOT` become internal nodes, fact references and comparisons become leaves. A `semanticChecker` pass runs alongside this to catch malformed rules early — undefined facts, type mismatches (comparing a bool fact like it's numeric), empty `and`/`or` arrays, duplicate rule names — and fails fast with `FATAL` rather than building a broken engine.

### 2. AST → bytecode

Once a rule's condition tree is built, it's compiled a second time — this time into a flat bytecode program (`bytecode.c`). The AST is walked once in postorder and turned into a sequence of stack-machine instructions:

```
PUSH_FACT isAdmin
PUSH_CMP  age > 18
OP_AND
OP_HALT
```

At runtime, evaluating a rule means running this instruction list through a small VM with a fixed-size operand stack — no recursive function calls, no pointer chasing through scattered tree nodes, just a sequential array walk. The tree is still built and kept around, but it's the bytecode that actually gets executed every cycle.

### 3. Facts: bitmask for bools, hash table for numbers

Boolean facts don't get a `bool` field stored per-entry. Instead, each bool fact name is assigned a bit index the first time it's seen, and its value lives in a fixed `uint64_t[]` bitmask on the `FactDB`. Checking a bool fact is `testBit()` — a single shift and AND. Setting one is `setBit()`/`clearBit()`. The hash table (via [uthash](https://github.com/troydhanson/uthash)) still maps fact *names* to bit indices, since rule conditions reference facts by string, but the actual value storage is packed bits, not scattered heap allocations.

Numeric facts stay in a standard uthash hash table mapping name → `double`, since they need arbitrary comparison operators (`<`, `<=`, `>`, `>=`, `==`, `!=`) rather than a single bit test.

### 4. Memory: arena allocator

Everything tied to a rule engine's lifetime — `Rule` structs, AST `Node`s, compiled `Bytecode`, duplicated strings — is allocated out of a single arena (`arena.c`), backed by one `mmap` call per engine. There's no per-node `malloc`/`free` bookkeeping during parsing, and teardown is a single `munmap` plus freeing the arena's own control struct. Fact storage (the hash tables and bitmask) lives outside the arena on the regular heap, since facts can be added/updated independently of rule compilation.

### 5. Actions: a registry, not a switch statement

Instead of hardcoding what each action name does, Vela uses an action registry (`ActionEntry.c`) — a hash table mapping action name strings to C function pointers (`Action_f`) plus an optional context pointer. You register your callbacks with `registerTheAction()` either before or after building the engine; if a rule's `action` field matches a registered name, that rule's `func`/`ctx` get wired up automatically. This means the JSON file only needs to name *what* should happen, and your C code decides *how*, without Vela needing to know anything about your application logic.

## Architecture at a glance

```
test.json
    │
    ▼
jsonParser.c ──► semanticChecker.c (validates facts/rules as it parses)
    │
    ▼
ConditionTree (AST, arena-allocated)
    │
    ▼
bytecode.c (compiles AST → flat instruction array)
    │
    ▼
rule.c (RuleEngine: hash table of Rules, each with condition + bytecode)
    │
    ▼
engine.c (ties FactDB + RuleEngine + ActionEntry registry together)
    │
    ▼
runEngine() ──► runs bytecode VM per rule against FactDB ──► fires registered Action_f callbacks
```

## File overview

| File | Responsibility |
|---|---|
| `common.h` | Shared includes and the `FATAL` error macro |
| `arena.c/h` | mmap-backed arena allocator used for all AST/rule/bytecode memory |
| `ConditionTree.c/h` | `Node` definition and constructor for the condition AST |
| `factdb.c/h` | Fact storage: bitmask for bools, hash table for numerics; recursive `evaluate()` kept for reference/fallback |
| `bytecode.c/h` | Compiles a `Node` tree into a flat instruction array; stack-machine VM (`runBytecode`) executes it |
| `jsonParser.c/h` | Parses the JSON file with yyjson, builds facts and the rule AST |
| `semanticChecker.c/h` | Validation: operator legality, fact existence, type consistency, duplicate rule names |
| `rule.c/h` | `Rule` and `RuleEngine` definitions, rule storage/lookup, the run loop |
| `ActionEntry.c/h` | Action name → function pointer registry |
| `engine.c/h` | Top-level `Engine` type tying everything together; public API surface |

## Usage

```c
#include "engine.h"

void on_grant_access(FactDB* db, void* ctx) {
    printf("access granted: %s\n", (char*)ctx);
}

int main(void) {
    Engine* e = createEngine("rules.json");

    registerTheAction(e, "GRANT_ACCESS", on_grant_access, "some context");

    runEngine(e);

    deleteEngine(e);
    return 0;
}
```

Actions can be registered before or after `createEngine()` — if registered after, `registerTheAction` retroactively patches any already-parsed rules that reference that action name.

## Building

Vela depends on [yyjson](https://github.com/ibireme/yyjson) (vendored or linked) and [uthash](https://github.com/troydhanson/uthash) (single header, vendored). A typical CMake build:

```bash
mkdir build && cd build
cmake ..
make
```

## Status

Core engine, parser, semantic checker, arena allocator, action registry, bitmask fact storage, and the bytecode compiler/VM are implemented and passing the full test suite (27 rules covering simple bools, all six comparison operators, AND/OR/NOT including deep nesting, and mixed bool+numeric conditions). Memory has been checked under Valgrind with no leaks in engine teardown.

See the bottom of this file for what's planned next.

## Roadmap

- [x] Fact and rule lookup via hash tables
- [x] Custom arena allocator
- [x] Bitmask-backed boolean fact storage
- [x] AST → bytecode compiler and VM
- [x] Semantic checker (operator validity, fact existence, type checks, duplicate rule names)
- [x] Action registry with function pointer dispatch
- [ ] Custom simpler language with option for user to choose between uploading JSON or that language files
- [ ] Dependency tracking — only re-evaluate rules whose referenced facts actually changed
- [ ] Compile numeric comparisons into derived boolean facts at parse time, so every leaf evaluation is a single bit test
- [ ] Update rules at runtime without rewriting the JSON file
- [ ] Additional operators: `BETWEEN`, `IN`
- [ ] Friendlier integration API for C/C++ host projects

## How to install and use

Linux/ MacOS:
```bash
    git clone git@github.com:ka1rav6/vela.git
    cd vela
    mkdir build && cd build
    cmake .. && make
```
Please make sure you have `yyjson` installed or else install it from here: https://github.com/ibireme/yyjson


Run the `engine` executable file created in the build directory. For sample usage please checkout `testFuncs.c` and `test.json`

## License

Apache 2.0 — see `LICENSE`.
