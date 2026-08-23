
#include "factdb.h"
#include "rule.h"
#include "jsonParser.h"

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
    for (size_t i = 0; i < db->boolCount; i++)
    {
        printf("  %s = %s\n",
            db->boolFacts[i].name,
            db->boolFacts[i].val ? "true" : "false");
    }

    printf("\n[NUM FACTS]\n");
    for (size_t i = 0; i < db->numCount; i++)
    {
        printf("  %s = %.2f\n",
            db->numFacts[i].name,
            db->numFacts[i].val);
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
    for (size_t i = 0; i < engine->ruleCount; i++){
        printf("Rule Name: %s\n", engine->rules[i].ruleName);
        printf("Action: %s\n", engine->rules[i].action);
        printf("Condition AST:\n");
        printAST(engine->rules[i].condition, 1);
        printf("\n");
    }

    run(engine, db);

    deleteEngine(engine);
    deleteFactDB(db);
    return 0;
}
