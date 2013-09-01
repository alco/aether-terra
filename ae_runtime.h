#ifndef AE_RUNTIME_H
#define AE_RUNTIME_H

typedef struct {
    const char *type;
    void *value;
} value_t;

value_t make_int(int v);
int take_int(const value_t *v);
_Bool is_int(const value_t *v);

value_t make_float(float v);
float take_float(const value_t *v);
_Bool is_float(const value_t *v);

void set_var(const char *name, const value_t v);
const value_t *get_var(const char *name);


int         store_int(const char *name, int v);
float       store_float(const char *name, float v);
const char *store_string(const char *name, const char *v);


void print_val(const value_t *val);


#endif // AE_RUNTIME_H
