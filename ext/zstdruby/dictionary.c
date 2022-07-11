#include <common.h>

extern VALUE rb_cDDictionary;

static void ddictionary_free(void *p) { ZSTD_freeDDict(p); }


static VALUE
ddictionary_new(VALUE class, VALUE dict)
{
  char* dict_buffer = RSTRING_PTR(dict);
  size_t dict_size = RSTRING_LEN(dict);
  ZSTD_DDict* const ddict = ZSTD_createDDict(dict_buffer, dict_size);
  if (ddict == NULL) {
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createDDict failed");
  }

  VALUE tdata = Data_Wrap_Struct(class, 0, ddictionary_free, ddict);
  rb_obj_call_init(tdata, 0, NULL);
  return tdata;
}


void
zstd_ruby_dictionary_init(void)
{
  // rb_define_alloc_func(rb_cCContext, ccontext_alloc);
  rb_define_singleton_method(rb_cDDictionary, "new", ddictionary_new, 1);
}
