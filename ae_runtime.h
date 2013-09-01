#ifndef AE_RUNTIME_H
#define AE_RUNTIME_H

typedef struct {
    const char *type;
    void *value;
} value_t;


int         store_int(const char *name, int v);
float       store_float(const char *name, float v);
const char *store_string(const char *name, const char *v);

int         get_int(const char *name);
float       get_float(const char *name);
const char *get_string(const char *name);


_Bool is_int(const value_t *v);
_Bool is_float(const value_t *v);
_Bool is_string(const value_t *v);


void print_result();


#endif // AE_RUNTIME_H
