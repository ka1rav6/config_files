#include "../../include/rule_internal.h"
#include "../../include/bytecode.h"

#define VELABC_MAGIC    0x524C4542
#define VELABC_VERSION  3

static uint32_t read_u32le(const uint8_t* buf)
{
    return (uint32_t)buf[0]
         | ((uint32_t)buf[1] << 8)
         | ((uint32_t)buf[2] << 16)
         | ((uint32_t)buf[3] << 24);
}

RuleEngine* loadBytecode(const char* file, FactDB* db, EngineError* err)
{
    (void)db;

    FILE* fp = fopen(file, "rb");
    if (!fp)
    {
        if (err) *err = ENGINE_ERR_CANT_OPEN_FILE;
        return NULL;
    }

    fseek(fp, 0, SEEK_END);
    long fileSize = ftell(fp);
    rewind(fp);

    if (fileSize < 16)
    {
        if (err) *err = ENGINE_ERR_FILE_TOO_SMALL;
        fclose(fp);
        return NULL;
    }

    uint8_t header[16];
    if (fread(header, 1, 16, fp) != 16)
    {
        if (err) *err = ENGINE_ERR_TRUNCATED_FILE;
        fclose(fp);
        return NULL;
    }

    uint32_t magic      = read_u32le(header);
    uint32_t version    = read_u32le(header + 4);
    uint32_t instrCount = read_u32le(header + 8);
    uint32_t ruleCount  = read_u32le(header + 12);

    if (magic != VELABC_MAGIC)
    {
        if (err) *err = ENGINE_ERR_INVALID_MAGIC;
        fclose(fp);
        return NULL;
    }
    if (version != VELABC_VERSION)
    {
        if (err) *err = ENGINE_ERR_INVALID_VERSION;
        fclose(fp);
        return NULL;
    }
    if (ruleCount == 0 || ruleCount > MAX_RULES)
    {
        if (err) *err = ENGINE_ERR_INVALID_RULE_COUNT;
        fclose(fp);
        return NULL;
    }
    if (instrCount == 0 || instrCount > 100000)
    {
        if (err) *err = ENGINE_ERR_INVALID_INSTR_COUNT;
        fclose(fp);
        return NULL;
    }

    RuleEngine* engine = createRuleEngine();
    if (!engine)
    {
        if (err) *err = ENGINE_ERR_OUT_OF_MEMORY;
        fclose(fp);
        return NULL;
    }

    for (uint32_t r = 0; r < ruleCount; r++)
    {
        uint8_t nameLen;
        if (fread(&nameLen, 1, 1, fp) != 1)
        {
            if (err) *err = ENGINE_ERR_TRUNCATED_FILE;
            fclose(fp);
            deleteRuleEngine(engine);
            return NULL;
        }
        if (nameLen >= MAX_RULE_NAME)
        {
            if (err) *err = ENGINE_ERR_RULE_NAME_TOO_LONG;
            fclose(fp);
            deleteRuleEngine(engine);
            return NULL;
        }

        char ruleName[MAX_RULE_NAME];
        if (nameLen > 0 && fread(ruleName, 1, nameLen, fp) != nameLen)
        {
            if (err) *err = ENGINE_ERR_TRUNCATED_FILE;
            fclose(fp);
            deleteRuleEngine(engine);
            return NULL;
        }
        ruleName[nameLen] = '\0';

        uint8_t actionLen;
        if (fread(&actionLen, 1, 1, fp) != 1)
        {
            if (err) *err = ENGINE_ERR_TRUNCATED_FILE;
            fclose(fp);
            deleteRuleEngine(engine);
            return NULL;
        }
        if (actionLen >= MAX_RULE_NAME)
        {
            if (err) *err = ENGINE_ERR_ACTION_NAME_TOO_LONG;
            fclose(fp);
            deleteRuleEngine(engine);
            return NULL;
        }

        char actionName[MAX_RULE_NAME];
        if (actionLen > 0 && fread(actionName, 1, actionLen, fp) != actionLen)
        {
            if (err) *err = ENGINE_ERR_TRUNCATED_FILE;
            fclose(fp);
            deleteRuleEngine(engine);
            return NULL;
        }
        actionName[actionLen] = '\0';

        long ruleStart = ftell(fp);
        uint32_t ruleInstrCount = 0;
        while (1)
        {
            uint8_t opcode;
            if (fread(&opcode, 1, 1, fp) != 1)
            {
                if (err) *err = ENGINE_ERR_TRUNCATED_FILE;
                fclose(fp);
                deleteRuleEngine(engine);
                return NULL;
            }
            ruleInstrCount++;
            if (opcode == OP_HALT)
                break;
            if (opcode == OP_PUSH_FACT || opcode == OP_PUSH_CMP || opcode == OP_PUSH_STR_CMP)
            {
                uint8_t cmp;
                if (fread(&cmp, 1, 1, fp) != 1) { if (err) *err = ENGINE_ERR_TRUNCATED_FILE; fclose(fp); deleteRuleEngine(engine); return NULL; }
                while (1)
                {
                    char ch;
                    if (fread(&ch, 1, 1, fp) != 1) { if (err) *err = ENGINE_ERR_TRUNCATED_FILE; fclose(fp); deleteRuleEngine(engine); return NULL; }
                    if (ch == '\0') break;
                }
                if (opcode == OP_PUSH_STR_CMP)
                {
                    while (1)
                    {
                        char ch;
                        if (fread(&ch, 1, 1, fp) != 1) { if (err) *err = ENGINE_ERR_TRUNCATED_FILE; fclose(fp); deleteRuleEngine(engine); return NULL; }
                        if (ch == '\0') break;
                    }
                }
                else
                {
                    if (fseek(fp, 8, SEEK_CUR) != 0) { if (err) *err = ENGINE_ERR_TRUNCATED_FILE; fclose(fp); deleteRuleEngine(engine); return NULL; }
                }
            }
        }
        fseek(fp, ruleStart, SEEK_SET);

        Bytecode* bc = arena_alloc(engine->arena, sizeof(Bytecode));
        if (!bc)
        {
            if (err) *err = ENGINE_ERR_ARENA_OOM;
            fclose(fp);
            deleteRuleEngine(engine);
            return NULL;
        }
        bc->capacity = ruleInstrCount;
        bc->count    = 0;
        bc->code     = arena_alloc(engine->arena, sizeof(Instr) * bc->capacity);
        if (!bc->code)
        {
            if (err) *err = ENGINE_ERR_ARENA_OOM;
            fclose(fp);
            deleteRuleEngine(engine);
            return NULL;
        }

        while (1)
        {
            uint8_t opcode;
            if (fread(&opcode, 1, 1, fp) != 1)
            {
                if (err) *err = ENGINE_ERR_TRUNCATED_FILE;
                fclose(fp);
                deleteRuleEngine(engine);
                return NULL;
            }

            Instr* instr = &bc->code[bc->count++];
            memset(instr, 0, sizeof(Instr));
            instr->op = (OpCode)opcode;

            if (opcode == OP_HALT)
                break;

            if (opcode == OP_PUSH_FACT || opcode == OP_PUSH_CMP || opcode == OP_PUSH_STR_CMP)
            {
                uint8_t cmp;
                if (fread(&cmp, 1, 1, fp) != 1)
                {
                    if (err) *err = ENGINE_ERR_TRUNCATED_FILE;
                    fclose(fp);
                    deleteRuleEngine(engine);
                    return NULL;
                }
                instr->cmp = (CompareOp)cmp;

                char nameBuf[256];
                size_t i = 0;
                while (1)
                {
                    char ch;
                    if (fread(&ch, 1, 1, fp) != 1)
                    {
                        if (err) *err = ENGINE_ERR_TRUNCATED_FILE;
                        fclose(fp);
                        deleteRuleEngine(engine);
                        return NULL;
                    }
                    if (ch == '\0')
                        break;
                    if (i >= sizeof(nameBuf) - 1)
                    {
                        if (err) *err = ENGINE_ERR_FACT_NAME_TOO_LONG;
                        fclose(fp);
                        deleteRuleEngine(engine);
                        return NULL;
                    }
                    nameBuf[i++] = ch;
                }
                nameBuf[i] = '\0';
                instr->factName = arena_strdup(engine->arena, nameBuf);

                if (opcode == OP_PUSH_STR_CMP)
                {
                    char strBuf[512];
                    size_t j = 0;
                    while (1)
                    {
                        char ch;
                        if (fread(&ch, 1, 1, fp) != 1)
                        {
                            if (err) *err = ENGINE_ERR_TRUNCATED_FILE;
                            fclose(fp);
                            deleteRuleEngine(engine);
                            return NULL;
                        }
                        if (ch == '\0')
                            break;
                        if (j >= sizeof(strBuf) - 1)
                        {
                            if (err) *err = ENGINE_ERR_FACT_NAME_TOO_LONG;
                            fclose(fp);
                            deleteRuleEngine(engine);
                            return NULL;
                        }
                        strBuf[j++] = ch;
                    }
                    strBuf[j] = '\0';
                    instr->strVal = arena_strdup(engine->arena, strBuf);
                    instr->val = 0.0;
                }
                else
                {
                    uint8_t valBytes[8];
                    if (fread(valBytes, 1, 8, fp) != 8)
                    {
                        if (err) *err = ENGINE_ERR_TRUNCATED_FILE;
                        fclose(fp);
                        deleteRuleEngine(engine);
                        return NULL;
                    }
                    memcpy(&instr->val, valBytes, sizeof(double));
                }
            }
        }

        if ((uint32_t)bc->count != ruleInstrCount)
        {
            if (err) *err = ENGINE_ERR_INSTRUCTION_COUNT_MISMATCH;
            fclose(fp);
            deleteRuleEngine(engine);
            return NULL;
        }

        Rule* rule = arena_alloc(engine->arena, sizeof(Rule));
        if (!rule)
        {
            if (err) *err = ENGINE_ERR_ARENA_OOM;
            fclose(fp);
            deleteRuleEngine(engine);
            return NULL;
        }
        memset(rule, 0, sizeof(Rule));
        strncpy(rule->ruleName, ruleName, MAX_RULE_NAME - 1);
        rule->ruleName[MAX_RULE_NAME - 1] = '\0';
        rule->action    = arena_strdup(engine->arena, actionName);
        rule->bc        = bc;
        rule->condition = NULL;
        rule->dirty     = true;
        collectBytecodeDeps(rule->bc, engine->arena, &rule->deps, &rule->dep_count);
        addRule(engine, rule);
    }

    fclose(fp);

    uint32_t readInstrs = 0;
    for (Rule *cr = engine->rules, *tmp; cr; cr = tmp)
    {
        tmp = cr->hh.next;
        readInstrs += cr->bc->count;
    }
    if (readInstrs != instrCount)
    {
        if (err) *err = ENGINE_ERR_INSTRUCTION_COUNT_MISMATCH;
        deleteRuleEngine(engine);
        return NULL;
    }

    return engine;
}
