#ifndef AE_RUNTIME_H
#define AE_RUNTIME_H

typedef struct {
    const char *type;
    void *value;
} value_t;

value_t make_int(int v);
int take_int(const value_t *v);

void set_var(const char *name, const value_t v);
const value_t *get_var(const char *name);

#endif // AE_RUNTIME_H
