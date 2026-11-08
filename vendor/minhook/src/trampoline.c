/*
 *  MinHook - The Minimalistic API Hooking Library for x64/x86
 *  Copyright (C) 2009-2017 Tsuda Kageyu.
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 *  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 *  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER
 *  OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 *  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <windows.h>

#if defined(_MSC_VER) && !defined(MINHOOK_DISABLE_INTRINSICS)
    #define ALLOW_INTRINSICS
    #include <intrin.h>
#endif

#ifndef ARRAYSIZE
    #define ARRAYSIZE(A) (sizeof(A)/sizeof((A)[0]))
#endif

#if defined(_M_X64) || defined(__x86_64__)
    #include "./hde/hde64.h"
    typedef hde64s HDE;
    #define HDE_DISASM(code, hs) hde64_disasm(code, hs)
#else
    #include "./hde/hde32.h"
    typedef hde32s HDE;
    #define HDE_DISASM(code, hs) hde32_disasm(code, hs)
#endif

#include "trampoline.h"
#include "buffer.h"

// Maximum size of a trampoline function.
#if defined(_M_X64) || defined(__x86_64__)
    #define TRAMPOLINE_MAX_SIZE (MEMORY_SLOT_SIZE - sizeof(JMP_ABS))
#else
    #define TRAMPOLINE_MAX_SIZE MEMORY_SLOT_SIZE
#endif

//-------------------------------------------------------------------------
static BOOL IsCodePadding(LPBYTE pInst, UINT size)
{
    UINT i;

    if (pInst[0] != 0x00 && pInst[0] != 0x90 && pInst[0] != 0xCC)
        return FALSE;

    for (i = 1; i < size; ++i)
    {
        if (pInst[i] != pInst[0])
            return FALSE;
    }
    return TRUE;
}

//-------------------------------------------------------------------------
// Deliberately NOT a general far relocator. Only whole register/stack
// instructions are accepted. Any RIP-relative operand, branch, call or return
// in the overwritten range rejects the hook without changing target bytes.
BOOL CreateTrampolineFunction(PTRAMPOLINE ct)
{
    UINT8 pos = 0;
    JMP_ABS jump = {0xFF, 0x25, 0, 0};
    ct->patchAbove = FALSE;
    ct->nIP = 0;
    while (pos < sizeof(JMP_ABS)) {
        HDE hs;
        UINT len = HDE_DISASM((LPBYTE)ct->pTarget + pos, &hs);
        if (!len || (hs.flags & F_ERROR) || len > 15 || pos + len > 32)
            return FALSE;
        if ((hs.flags & F_MODRM) && (hs.modrm & 0xC7) == 0x05)
            return FALSE;
        if (hs.opcode == 0xE8 || hs.opcode == 0xE9 || hs.opcode == 0xEB
            || (hs.opcode & 0xF0) == 0x70 || (hs.opcode & 0xFC) == 0xE0
            || (hs.opcode == 0x0F && (hs.opcode2 & 0xF0) == 0x80)
            || hs.opcode == 0xC2 || hs.opcode == 0xC3 || hs.opcode == 0xCA || hs.opcode == 0xCB
            || (hs.opcode == 0xFF && hs.modrm_reg >= 2 && hs.modrm_reg <= 5))
            return FALSE;
        if (ct->nIP + 1 >= ARRAYSIZE(ct->oldIPs))
            return FALSE;
        ct->oldIPs[ct->nIP] = pos;
        ct->newIPs[ct->nIP] = pos;
        ++ct->nIP;
        memcpy((LPBYTE)ct->pTrampoline + pos, (LPBYTE)ct->pTarget + pos, len);
        pos += (UINT8)len;
    }
    if (pos + 2 * sizeof(JMP_ABS) > MEMORY_SLOT_SIZE)
        return FALSE;
    // Include the return-jump boundary in the original thread-IP repair table.
    ct->oldIPs[ct->nIP] = pos;
    ct->newIPs[ct->nIP] = pos;
    ++ct->nIP;
    jump.address = (ULONG_PTR)ct->pTarget + pos;
    memcpy((LPBYTE)ct->pTrampoline + pos, &jump, sizeof(jump));
    ct->pRelay = (LPBYTE)ct->pTrampoline + pos + sizeof(jump);
    jump.address = (ULONG_PTR)ct->pDetour;
    memcpy(ct->pRelay, &jump, sizeof(jump));
    return TRUE;
}
