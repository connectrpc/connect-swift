// Copyright 2022-2024 The Connect Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef zliblinux_h
#define zliblinux_h

#include <zlib.h>

static inline int CNIOExtrasZlib_deflateInit2(z_streamp strm,
                                              int level,
                                              int method,
                                              int windowBits,
                                              int memLevel,
                                              int strategy) {
    return deflateInit2(strm, level, method, windowBits, memLevel, strategy);
}

static inline int CNIOExtrasZlib_inflateInit2(z_streamp strm, int windowBits) {
    return inflateInit2(strm, windowBits);
}

static inline Bytef *CNIOExtrasZlib_voidPtr_to_BytefPtr(void *in) {
    return (Bytef *)in;
}

#endif /* zliblinux_h */
