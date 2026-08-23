#include "common.h"

#include <yyjson.h>
#include "rule.h"
#include "ActionEntry.h"
#include "arena.h"

yyjson_doc* parseJSON(const char*); 

RuleEngine* build_ast(yyjson_doc*, FactDB*, ActionEntry*);

Node* build_node(Arena*, FactDB*, yyjson_val*);
Node* build_and_or(Arena*, FactDB*, yyjson_val*, Type);
Node* build_fact(Arena*, FactDB*, yyjson_val*);
Node* build_not(Arena*, FactDB*, yyjson_val*);
Node* build_compare(Arena*, FactDB*, const char*, yyjson_val*);
void build_factdb(FactDB*, yyjson_val*);
