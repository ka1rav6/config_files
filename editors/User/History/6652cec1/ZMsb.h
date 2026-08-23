#include <stdio.h>
#include <string.h>
#include <yyjson.h>
#include "rule.h"

yyjson_doc* parseJSON(const char*); 

RuleEngine* build_ast(yyjson_doc*, FactDB*);

Node* build_node(yyjson_val*);
Node* build_and(yyjson_val*);
Node* build_fact(yyjson_val*);
Node* build_not(yyjson_val*);
Node* build_or(yyjson_val*);
Node* build_compare(const char*, yyjson_val*);
void build_factdb(FactDB*, yyjson_val*);