#if defined(__apple_build_version__) && __apple_build_version__ >= 21000000
#include "absl/base/attributes.h"
#undef ABSL_ATTRIBUTE_LIFETIME_BOUND
#define ABSL_ATTRIBUTE_LIFETIME_BOUND
#endif
