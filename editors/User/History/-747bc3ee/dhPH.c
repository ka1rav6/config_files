#include "uthash.h"
#include "factdb.h"
#include "rule.h"
#include "jsonParser.h"

// A SIMPLE TEST FILE TO TEST THE FUNCTIONALITY OF THE FACT DB AND THE AST BUILDING AND EVALUATION
// PRINTING FUNCTIONS AND A MAIN FUNCTION (mainly for testing purposes) ARE ALSO INCLUDED HERE


void printIndent(int depth){
    for (int i = 0; i < depth; i++)
        printf("  ");
}
void printAST(Node* n, int depth){
    if (!n)
        return;
    printIndent(depth);
    switch (n->type){
        case NODE_AND:
            printf("AND\n");
            printAST(n->data.op.left, depth + 1);
            printAST(n->data.op.right, depth + 1);
            break;
        case NODE_OR:
            printf("OR\n");
            printAST(n->data.op.left, depth + 1);
            printAST(n->data.op.right, depth + 1);
            break;
        case NODE_NOT:
            printf("NOT\n");
            printAST(n->data.unary.child, depth + 1);
            break;
        case NODE_FACT:
            printf("FACT(%s)\n",
                n->data.Fact.factName);
            break;
        case NODE_COMPARE:
            printf(
                "COMPARE(%s, op=%d, %.2f)\n",
                n->data.Compare.factName,
                n->data.Compare.op,
                n->data.Compare.val
            );
            break;
    }
}
void printFactDB(FactDB* db)
{
    printf("=== FACT DB ===\n");

    printf("\n[BOOL FACTS]\n");
    BoolFact* bf, *tmp;
    HASH_ITER(hh, db->boolFacts, bf, tmp){
        printf("%s = %d\n", bf->name, bf->val);
    }
    printf("\n[NUM FACTS]\n");
    NumFact* nf, *temp;
    HASH_ITER(hh, db->numFacts, nf, temp){
        printf("%s = %.2f\n", nf->name, nf->val);
    }
    printf("================\n\n");
}

int main(void){
    printf("Loading JSON...\n");
    yyjson_doc* doc = parseJSON("../src/test.json");
    printf("Building AST...\n");
    FactDB* db = createFactDB();
    RuleEngine* engine = build_ast(doc, db);


    printFactDB(db);

    printf("\n");
    Rule* r, *temp;
    HASH_ITER(hh, engine->rules, r, temp){
        printf("Rule Name: %s\n", r->ruleName);
        printf("Action: %s\n", r->action);
        printf("Condition AST:\n");
        printAST(r->condition, 1);
        printf("\n");
    }

    run(engine, db);

    deleteEngine(engine);
    deleteFactDB(db);
    return 0;
}
