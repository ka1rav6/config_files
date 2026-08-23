#include "common.h"

#include <yyjson.h>
#include "rule.h"
#include "ActionEntry.h"
#include "arena.h"

static yyjson_doc* parseJSON(const char*); 

static RuleEngine* build_ast(yyjson_doc*, FactDB*, ActionEntry*);

static Node* build_node(Arena*, FactDB*, yyjson_val*);
static Node* build_and_or(Arena*, FactDB*, yyjson_val*, Type);
static Node* build_fact(Arena*, FactDB*, yyjson_val*);
static Node* build_not(Arena*, FactDB*, yyjson_val*);
static Node* build_compare(Arena*, FactDB*, const char*, yyjson_val*);
static void build_factdb(FactDB*, yyjson_val*);
