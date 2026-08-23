#include <stdio.h>
#include <string.h>
#include <yyjson.h>
#include "rule.h"
#include "ActionEntry.h"

yyjson_doc* parseJSON(const char*); 

RuleEngine* build_ast(yyjson_doc*, FactDB*, ActionEntry*);

Node* build_node(FactDB*, yyjson_val*);
Node* build_and_or(FactDB*, yyjson_val*, Type);
Node* build_fact(FactDB*, yyjson_val*);
Node* build_not(FactDB*, yyjson_val*);
Node* build_compare(FactDB*, const char*, yyjson_val*);
void build_factdb(FactDB*, yyjson_val*);
