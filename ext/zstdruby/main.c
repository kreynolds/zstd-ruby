#include <common.h>

VALUE rb_mZstd;
VALUE rb_cCContext;
VALUE rb_cDContext;
VALUE rb_cDDictionary;

void zstd_ruby_init(void);
void zstd_ruby_compressor_init(void);
void zstd_ruby_context_init(void);
void zstd_ruby_dictionary_init(void);
void zstd_ruby_streaming_compress_init(void);
void zstd_ruby_streaming_decompress_init(void);

void
Init_zstdruby(void)
{
  rb_mZstd = rb_define_module("Zstd");
  rb_cCContext = rb_define_class_under(rb_mZstd, "CContext", rb_cObject);
  rb_cDContext = rb_define_class_under(rb_mZstd, "DContext", rb_cObject);
  rb_cDDictionary = rb_define_class_under(rb_mZstd, "DDictionary", rb_cObject);

  zstd_ruby_init();
  zstd_ruby_context_init();
  zstd_ruby_dictionary_init();
  zstd_ruby_streaming_compress_init();
  zstd_ruby_streaming_decompress_init();
}
