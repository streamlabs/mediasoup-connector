#pragma once

#if defined(__clang__) && defined(__apple_build_version__) && (__clang_major__ >= 21)
#include <absl/base/attributes.h>
#undef ABSL_ATTRIBUTE_LIFETIME_BOUND
#define ABSL_ATTRIBUTE_LIFETIME_BOUND
#endif
