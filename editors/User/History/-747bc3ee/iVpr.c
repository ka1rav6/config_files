#include "uthash.h"
#include "engine.h"

/* ── pass/fail counters ──────────────────────────────────────────────────── */

static int passed = 0;
static int failed = 0;

/* ── print helpers ───────────────────────────────────────────────────────── */

void printIndent(int depth){
    for (int i = 0; i < depth; i++) printf("  ");
}

void printAST(Node* n, int depth){
    if (!n) return;
    printIndent(depth);
    switch (n->type){
        case NODE_AND:
            printf("AND\n");
            printAST(n->data.op.left,  depth + 1);
            printAST(n->data.op.right, depth + 1);
            break;
        case NODE_OR:
            printf("OR\n");
            printAST(n->data.op.left,  depth + 1);
            printAST(n->data.op.right, depth + 1);
            break;
        case NODE_NOT:
            printf("NOT\n");
            printAST(n->data.unary.child, depth + 1);
            break;
        case NODE_FACT:
            printf("FACT(%s)\n", n->data.Fact.factName);
            break;
        case NODE_COMPARE:
            printf("COMPARE(%s op=%d %.2f)\n",
                n->data.Compare.factName,
                n->data.Compare.op,
                n->data.Compare.val);
            break;
    }
}

void printFactDB(FactDB* db){
    printf("=== FACT DB ===\n");
    printf("[BOOL FACTS]\n");
    BoolFact* bf, *btmp;
    HASH_ITER(hh, db->boolFacts, bf, btmp)
        printf("  %s = %s\n", bf->name, bf->val ? "true" : "false");
    printf("[NUM FACTS]\n");
    NumFact* nf, *ntmp;
    HASH_ITER(hh, db->numFacts, nf, ntmp)
        printf("  %s = %.2f\n", nf->name, nf->val);
    printf("================\n\n");
}

/* ── callbacks ───────────────────────────────────────────────────────────── */

/*
 * EXPECTED TO FIRE (24 rules):
 *   SIMPLE_BOOL_FIRED        isAdmin=true
 *   AGE_OVER_18              age(25) > 18
 *   SCORE_UNDER_100          score(42) < 100
 *   BALANCE_GE_1500          balance(1500) >= 1500
 *   LOGIN_ATTEMPTS_LE_5      loginAttempts(2) <= 5
 *   ITEM_COUNT_EQUALS_3      itemCount == 3
 *   FEVER_DETECTED           temperature(98.6) > 98.0
 *   ADMIN_AND_VERIFIED       isAdmin && isVerified
 *   REGULAR_OR_PREMIUM       isPremium=true
 *   NOT_BANNED               !isBanned
 *   ADMIN_VERIFIED_PREMIUM   isAdmin && isVerified && isPremium
 *   GUEST_OR_REGULAR_OR_ADMIN isAdmin=true
 *   ADULT_WITH_BALANCE       age>18 && balance>=1000
 *   HIGH_SCORE_OR_PREMIUM    isPremium=true
 *   NOT_HIGH_RISK_LOGIN      !(loginAttempts>10)
 *   NESTED_AND_OR_FIRED      isAdmin && (balance>500 || isPremium)
 *   NESTED_OR_AND_FIRED      isVerified && age>18
 *   DEEP_NEST_FIRED          complex nested condition
 *   NEITHER_BANNED_NOR_GUEST !(isBanned||isGuest)
 *   NOT_BOTH_GUEST_AND_BANNED !(isGuest&&isBanned)
 *   LOYAL_HIGH_SPENDER       accountAgeDays>=300 && balance>1000
 *   SCORE_IN_RANGE           0<=score<=100
 *   NO_DISCOUNT_HAS_ITEMS    discount==0 && itemCount>0
 *   FULL_ACCESS_GRANTED      all conditions satisfied
 *
 * EXPECTED NOT TO FIRE (3 rules):
 *   SHOULD_NOT_FIRE          isBanned=false
 *   DISCOUNT_NOT_ZERO        discount(0) != 0 → false
 *   SHOULD_NOT_FIRE_NOT      !isAdmin → false
 */

void cb_pass(FactDB* d, void* c){
    (void)d;
    printf("  [PASS] %s\n", (char*)c);
    passed++;
}

void cb_should_not_fire(FactDB* d, void* c){
    (void)d;
    printf("  [FAIL] fired but should NOT have: %s\n", (char*)c);
    failed++;
}

/* ── main ────────────────────────────────────────────────────────────────── */

int main(void){

    /* Register callbacks BEFORE creating the engine.
       The engine wires them automatically during build_ast. */
       
       /* Engine creation — callbacks are wired automatically */
       Engine* e = createEngine("../src/test.json");
    // --- rules that SHOULD fire ---
    registerTheAction(e, "SIMPLE_BOOL_FIRED",        cb_pass, "SIMPLE_BOOL_FIRED: isAdmin=true");
    registerTheAction(e, "AGE_OVER_18",              cb_pass, "AGE_OVER_18: age(25)>18");
    registerTheAction(e, "SCORE_UNDER_100",          cb_pass, "SCORE_UNDER_100: score(42)<100");
    registerTheAction(e, "BALANCE_GE_1500",          cb_pass, "BALANCE_GE_1500: balance(1500)>=1500");
    registerTheAction(e, "LOGIN_ATTEMPTS_LE_5",      cb_pass, "LOGIN_ATTEMPTS_LE_5: loginAttempts(2)<=5");
    registerTheAction(e, "ITEM_COUNT_EQUALS_3",      cb_pass, "ITEM_COUNT_EQUALS_3: itemCount==3");
    registerTheAction(e, "FEVER_DETECTED",           cb_pass, "FEVER_DETECTED: temperature(98.6)>98.0");
    registerTheAction(e, "ADMIN_AND_VERIFIED",       cb_pass, "ADMIN_AND_VERIFIED: isAdmin&&isVerified");
    registerTheAction(e, "REGULAR_OR_PREMIUM",       cb_pass, "REGULAR_OR_PREMIUM: isPremium=true");
    registerTheAction(e, "NOT_BANNED",               cb_pass, "NOT_BANNED: !isBanned");
    registerTheAction(e, "ADMIN_VERIFIED_PREMIUM",   cb_pass, "ADMIN_VERIFIED_PREMIUM");
    registerTheAction(e, "GUEST_OR_REGULAR_OR_ADMIN",cb_pass, "GUEST_OR_REGULAR_OR_ADMIN: isAdmin=true");
    registerTheAction(e, "ADULT_WITH_BALANCE",       cb_pass, "ADULT_WITH_BALANCE: age>18&&balance>=1000");
    registerTheAction(e, "HIGH_SCORE_OR_PREMIUM",    cb_pass, "HIGH_SCORE_OR_PREMIUM: isPremium=true");
    registerTheAction(e, "NOT_HIGH_RISK_LOGIN",      cb_pass, "NOT_HIGH_RISK_LOGIN: !(loginAttempts>10)");
    registerTheAction(e, "NESTED_AND_OR_FIRED",      cb_pass, "NESTED_AND_OR_FIRED");
    registerTheAction(e, "NESTED_OR_AND_FIRED",      cb_pass, "NESTED_OR_AND_FIRED: isVerified&&age>18");
    registerTheAction(e, "DEEP_NEST_FIRED",          cb_pass, "DEEP_NEST_FIRED");
    registerTheAction(e, "NEITHER_BANNED_NOR_GUEST", cb_pass, "NEITHER_BANNED_NOR_GUEST: !(banned||guest)");
    registerTheAction(e, "NOT_BOTH_GUEST_AND_BANNED",cb_pass, "NOT_BOTH_GUEST_AND_BANNED: !(guest&&banned)");
    registerTheAction(e, "LOYAL_HIGH_SPENDER",       cb_pass, "LOYAL_HIGH_SPENDER: accountAgeDays>=300&&balance>1000");
    registerTheAction(e, "SCORE_IN_RANGE",           cb_pass, "SCORE_IN_RANGE: 0<=score<=100");
    registerTheAction(e, "NO_DISCOUNT_HAS_ITEMS",    cb_pass, "NO_DISCOUNT_HAS_ITEMS: discount==0&&itemCount>0");
    registerTheAction(e, "FULL_ACCESS_GRANTED",      cb_pass, "FULL_ACCESS_GRANTED");

    // --- rules that should NOT fire ---
    registerTheAction(e, "SHOULD_NOT_FIRE",     cb_should_not_fire, "SHOULD_NOT_FIRE (isBanned=false)");
    registerTheAction(e, "DISCOUNT_NOT_ZERO",   cb_should_not_fire, "DISCOUNT_NOT_ZERO (discount==0)");
    registerTheAction(e, "SHOULD_NOT_FIRE_NOT", cb_should_not_fire, "SHOULD_NOT_FIRE_NOT (!isAdmin=false)");


    printf("\n=== FACT DATABASE ===\n");
    printFactDB(e->db);

    printf("=== RULE ASTs ===\n");
    Rule* r; Rule* tmp;
    HASH_ITER(hh, e->r_engine->rules, r, tmp){
        printf("Rule: %s  ->  action: %s\n", r->ruleName, r->action);
        printAST(r->condition, 1);
        printf("\n");
    }

    printf("=== RUNNING ENGINE ===\n");
    runEngine(e);

    printf("\n=== RESULTS ===\n");
    printf("  Expected to fire    : 24\n");
    printf("  Expected NOT to fire: 3\n");
    printf("  [PASS] callbacks    : %d\n", passed);
    printf("  [FAIL] callbacks    : %d\n", failed);
    if (failed == 0 && passed == 24)
        printf("  ALL TESTS PASSED\n");
    else
        printf("  SOMETHING IS WRONG\n");

    deleteEngine(e);
    return failed > 0 ? 1 : 0;
}
