#include <common.h>

extern VALUE rb_cCContext;
extern VALUE rb_cDContext;

static void ccontext_free(void *p) { ZSTD_freeCCtx(p); }
static void dcontext_free(void *p) { ZSTD_freeDCtx(p); }


static VALUE
ccontext_alloc(VALUE class)
{
  ZSTD_CCtx* cctx = ZSTD_createCCtx();
  if (cctx == NULL) {
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createCCtx failed");
  }

  return Data_Wrap_Struct(class, NULL, ccontext_free, cctx);
}


static VALUE
dcontext_alloc(VALUE class)
{
  ZSTD_DCtx* dctx = ZSTD_createDCtx();
  if (dctx == NULL) {
    rb_raise(rb_eRuntimeError, "%s", "ZSTD_createDCtx failed");
  }

  return Data_Wrap_Struct(class, NULL, dcontext_free, dctx);
}


void
zstd_ruby_context_init(void)
{
  rb_define_alloc_func(rb_cCContext, ccontext_alloc);
  rb_define_alloc_func(rb_cDContext, dcontext_alloc);
}
