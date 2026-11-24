.pragma library

// =============================================================================
// calc.js — the drawer calculator's arithmetic.
// =============================================================================
// A tokenizer and a shunting-yard evaluator for + - * / % ^, unary minus,
// parentheses and decimals. Written out rather than handed to eval(), because
// anything typed into a desktop panel is not code, and eval() of user text is
// how "2+2" quietly becomes "run this". Also accepts x and × for multiply and
// ÷ for divide, since those are what people type.
//
// evaluate(text) -> { ok: true, value } | { ok: false, error }
// =============================================================================

function tokenize(text) {
    const out = [];
    const s = text.replace(/[x×]/g, "*").replace(/÷/g, "/").replace(/,/g, ".");
    let i = 0;
    while (i < s.length) {
        const c = s[i];
        if (c === " ") { i++; continue; }
        if ((c >= "0" && c <= "9") || c === ".") {
            let j = i;
            while (j < s.length && ((s[j] >= "0" && s[j] <= "9") || s[j] === ".")) j++;
            const n = Number(s.slice(i, j));
            if (isNaN(n)) throw "bad number";
            out.push({ t: "num", v: n });
            i = j;
            continue;
        }
        if ("+-*/%^()".indexOf(c) >= 0) {
            out.push({ t: "op", v: c });
            i++;
            continue;
        }
        throw "unexpected '" + c + "'";
    }
    return out;
}

// Unary minus binds tighter than * but looser than ^, so -3^2 is -9 as on
// paper, and 2*-3 is -6.
const PREC = { "+": 1, "-": 1, "*": 2, "/": 2, "%": 2, "neg": 2.5, "^": 3 };
const RIGHT = { "^": true, "neg": true };

function toRpn(tokens) {
    const out = [], ops = [];
    let prev = null;
    for (const tk of tokens) {
        if (tk.t === "num") {
            out.push(tk);
        } else if (tk.v === "(") {
            ops.push("(");
        } else if (tk.v === ")") {
            while (ops.length && ops[ops.length - 1] !== "(") out.push({ t: "op", v: ops.pop() });
            if (!ops.length) throw "unbalanced )";
            ops.pop();
        } else {
            // A minus with nothing, an operator or "(" before it is unary.
            let op = tk.v;
            if (op === "-" && (prev === null || (prev.t === "op" && prev.v !== ")"))) op = "neg";
            // A prefix operator has no left operand, so it pops nothing.
            while (op !== "neg" && ops.length) {
                const top = ops[ops.length - 1];
                if (top === "(") break;
                if (PREC[top] > PREC[op] || (PREC[top] === PREC[op] && !RIGHT[op])) out.push({ t: "op", v: ops.pop() });
                else break;
            }
            ops.push(op);
        }
        prev = tk;
    }
    while (ops.length) {
        const op = ops.pop();
        if (op === "(") throw "unbalanced (";
        out.push({ t: "op", v: op });
    }
    return out;
}

function run(rpn) {
    const st = [];
    for (const tk of rpn) {
        if (tk.t === "num") { st.push(tk.v); continue; }
        if (tk.v === "neg") {
            if (!st.length) throw "incomplete";
            st.push(-st.pop());
            continue;
        }
        if (st.length < 2) throw "incomplete";
        const b = st.pop(), a = st.pop();
        switch (tk.v) {
        case "+": st.push(a + b); break;
        case "-": st.push(a - b); break;
        case "*": st.push(a * b); break;
        case "/": st.push(a / b); break;
        case "%": st.push(a % b); break;
        case "^": st.push(Math.pow(a, b)); break;
        }
    }
    if (st.length !== 1) throw "incomplete";
    return st[0];
}

function evaluate(text) {
    if (!text || !text.trim()) return { ok: false, error: "" };
    try {
        const v = run(toRpn(tokenize(text)));
        if (!isFinite(v)) return { ok: false, error: "not a number" };
        // Twelve significant digits hides float noise (0.1 + 0.2) without
        // hiding anything a person typed.
        return { ok: true, value: Number(v.toPrecision(12)) };
    } catch (e) {
        return { ok: false, error: String(e) };
    }
}
