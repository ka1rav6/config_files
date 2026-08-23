#include "../../include/factdb_internal.h"

// gets the value of a numeric fact from the fact DB by searching for its name.
// Thread-safe: read-locked, since multiple readers can look up facts concurrently.
double getNumFact(FactDB* db, const char* name)
{
    pthread_rwlock_rdlock(&db->lock);

    NumFact* f;
    HASH_FIND_STR(db->numFacts, name, f);
    double result = f ? f->val : NOT_FOUND;
    pthread_rwlock_unlock(&db->lock);
    return result;
}

// Similar to getNumFact but for boolean facts
bool getBoolFact(FactDB* db, const char* name)
{
    pthread_rwlock_rdlock(&db->lock);
    BoolFact* f;
    HASH_FIND_STR(db->boolFacts, name, f);
    bool result = f ? f->val : false;
    pthread_rwlock_unlock(&db->lock);
    return result;
}

// constructor for factDB
FactDB* createFactDB()
{
    FactDB* temp = (FactDB*)malloc(sizeof(FactDB));
    if (!temp)
        return NULL;
    memset(temp, 0, sizeof(FactDB));
    if (pthread_rwlock_init(&temp->lock, NULL) != 0)
    {
        free(temp);
        return NULL;
    }
    return temp;
}

void deleteFactDB(FactDB* db)
{
    NumFact *currNum, *tempNum;
    HASH_ITER(hh, db->numFacts, currNum, tempNum)
    {
        HASH_DEL(db->numFacts, currNum);
        free(currNum);
    }
    BoolFact* currBool, *tempBool;
    HASH_ITER(hh, db->boolFacts, currBool, tempBool)
    {
        HASH_DEL(db->boolFacts,  currBool);
        free(currBool);
    }
    StrFact* currStr, *tempStr;
    HASH_ITER(hh, db->strFacts, currStr, tempStr)
    {
        HASH_DEL(db->strFacts, currStr);
        free(currStr->val);
        free(currStr);
    }
    pthread_rwlock_destroy(&db->lock);
    free(db);
}

void factdb_on_change(FactDB* db, FactChangeCB cb, void* user_data)
{
    pthread_rwlock_wrlock(&db->lock);
    db->on_change   = cb;
    db->change_data = user_data;
    pthread_rwlock_unlock(&db->lock);
}

void setBoolFact(FactDB* db, const char* name, bool val)
{
    pthread_rwlock_wrlock(&db->lock);
    BoolFact *f;
    HASH_FIND_STR(db->boolFacts, name, f);
    if (f)
    {
        f->val = val;
        pthread_rwlock_unlock(&db->lock);
        if (db->on_change) db->on_change(name, db->change_data);
        return;
    }
    if (strlen(name) > MAX_NAME)
    {
        pthread_rwlock_unlock(&db->lock);
        return;
    }
    f = (BoolFact*) malloc(sizeof(BoolFact));
    memset(f, 0, sizeof(BoolFact));
    strncpy(f->name, name, MAX_NAME - 1);
    f->name[MAX_NAME - 1] = '\0';
    f->val = val;
    HASH_ADD_STR(db->boolFacts, name, f);
    pthread_rwlock_unlock(&db->lock);
    if (db->on_change) db->on_change(name, db->change_data);
}

void setNumFact(FactDB* db, const char* name, double val)
{
    pthread_rwlock_wrlock(&db->lock);
    NumFact* f;
    HASH_FIND_STR(db->numFacts, name, f);
    if (f)
    {
        f->val = val;
        pthread_rwlock_unlock(&db->lock);
        if (db->on_change) db->on_change(name, db->change_data);
        return;
    }
    if (strlen(name) > MAX_NAME)
    {
        pthread_rwlock_unlock(&db->lock);
        return;
    }
    f = (NumFact*)malloc(sizeof(NumFact));
    memset(f, 0, sizeof(NumFact));
    strncpy(f->name, name, MAX_NAME - 1);
    f->name[MAX_NAME - 1] = '\0';
    f->val = val;
    HASH_ADD_STR(db->numFacts, name, f);
    pthread_rwlock_unlock(&db->lock);
    if (db->on_change) db->on_change(name, db->change_data);
}

char* getStringFact(FactDB* db, const char* name)
{
    pthread_rwlock_rdlock(&db->lock);
    StrFact* f;
    HASH_FIND_STR(db->strFacts, name, f);
    char* result = f ? f->val : NULL;
    pthread_rwlock_unlock(&db->lock);
    return result;
}

void setStringFact(FactDB* db, const char* name, const char* val)
{
    pthread_rwlock_wrlock(&db->lock);
    StrFact* f;
    HASH_FIND_STR(db->strFacts, name, f);
    if (f)
    {
        free(f->val);
        f->val = val ? strdup(val) : NULL;
        pthread_rwlock_unlock(&db->lock);
        if (db->on_change) db->on_change(name, db->change_data);
        return;
    }
    if (strlen(name) > MAX_NAME)
    {
        pthread_rwlock_unlock(&db->lock);
        return;
    }
    f = (StrFact*)malloc(sizeof(StrFact));
    memset(f, 0, sizeof(StrFact));
    strncpy(f->name, name, MAX_NAME - 1);
    f->name[MAX_NAME - 1] = '\0';
    f->val = val ? strdup(val) : NULL;
    HASH_ADD_STR(db->strFacts, name, f);
    pthread_rwlock_unlock(&db->lock);
    if (db->on_change) db->on_change(name, db->change_data);
}

bool factdb_has_bool(FactDB* db, const char* name)
{
    pthread_rwlock_rdlock(&db->lock);
    BoolFact* f;
    HASH_FIND_STR(db->boolFacts, name, f);
    bool found = (bool)f;
    pthread_rwlock_unlock(&db->lock);
    return found;
}

bool factdb_has_num(FactDB* db, const char* name)
{
    pthread_rwlock_rdlock(&db->lock);
    NumFact* f;
    HASH_FIND_STR(db->numFacts, name, f);
    bool found = (bool)f;
    pthread_rwlock_unlock(&db->lock);
    return found;
}

bool factdb_has_str(FactDB* db, const char* name)
{
    pthread_rwlock_rdlock(&db->lock);
    StrFact* f;
    HASH_FIND_STR(db->strFacts, name, f);
    bool found = (bool)f;
    pthread_rwlock_unlock(&db->lock);
    return found;
}

bool factdb_has_fact(FactDB* db, const char* name, factType t)
{
    switch (t)
    {
        case BOOL: return factdb_has_bool(db, name);
        case NUM:  return factdb_has_num(db, name);
        case STR:  return factdb_has_str(db, name);
    }
    return false;
}

void printFactDB(FactDB* db)
{
    pthread_rwlock_rdlock(&db->lock);
    printf("=== FACT DB ===\n");
    printf("[BOOL FACTS]\n");
    BoolFact* bf, *btmp;
    HASH_ITER(hh, db->boolFacts, bf, btmp)
        printf("  %s = %s\n", bf->name, bf->val ? "true" : "false");
    printf("[NUM FACTS]\n");
    NumFact* nf, *ntmp;
    HASH_ITER(hh, db->numFacts, nf, ntmp)
        printf("  %s = %.2f\n", nf->name, nf->val);
    printf("[STR FACTS]\n");
    StrFact* sf, *stmp;
    HASH_ITER(hh, db->strFacts, sf, stmp)
        printf("  %s = %s\n", sf->name, sf->val ? sf->val : "NULL");
    printf("================\n\n");
    pthread_rwlock_unlock(&db->lock);
}
