#pragma once

#include "rule.h"

// WILL CHANGE THIS SOON
#define RULE "RULE"
#define FACT "FACT"
#define COND "COND"
#define AND "AND"
#define OR "OR"
#define NOT "NOT"
#define HASTAG '#'


/*
NOTE THE ASSUMPTIONS:
1. Language has only keywords : RULE, FACT, COND, AND, OR, NOT (ALWAYS ALL CAPS)
2. Rest all names etc created by the user must be unique
3. The user should be able to update particular data points and it will not change on the file (as that is more expensive)
   and rather be changed in the tree straight away
4. All user defined names will be converted to lower case and hence they would have to be unique in a case sensitive way:
   this is to simplify usage of this API
5. Each rule/ fact or condition is written on a separate line with a simple identifier (of keywords)
6. each rule can be named something specific using this format:
                 RULE $RULE_NAME ruleconditions 
                 (note the dollar sign)
7. Single line comments can be created by using a '#' (HASHTAG)
8. normal parenthesis can be used to nest conditions
*/

/*
 * INFORMAL GRAMMAR PLAN:


program     -> statement*

statement   -> rule | fact | cond

rule        -> "RULE" "$" IDENT expression
fact        ->"FACT" IDENT
cond        ->"COND" expression

expression  -> term ( (AND | OR) term )*
term        -> NOT term | primary
primary     -> IDENT | '(' expression ')' | comparison

comparison  ->IDENT OP NUMBER
OP          -> < | > | <= | >= | == | !=
 *
 *
 * */


typedef struct {
    Rule* rules;
    int ruleCount;
    BoolFact* boolFacts;
    NumFact* numFacts;
    int boolCount;
    int numCount;
} Program;

typedef enum {
    TOK_RULE,
    TOK_FACT,
    TOK_COND,

    TOK_AND,
    TOK_OR,
    TOK_NOT,

    TOK_DOLLAR,

    TOK_IDENT,
    TOK_NUMBER,

    TOK_LT, TOK_GT,
    TOK_LE, TOK_GE,
    TOK_EQ, TOK_NE,

    TOK_LPAREN,
    TOK_RPAREN,

    TOK_END
} TokenType;

typedef struct {
    TokenType type;
    char text[64];   // for identifiers
    double number;   // for numeric values
} Token;

    
Program* readFile(const char* file); // reads a file and converts it into a program;  
Node* processLine(const char* line);
