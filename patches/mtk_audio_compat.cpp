#include <stdint.h>

// Acer's MT8163 audio HAL was built against MediaTek additions to
// AudioSystem. Voice-unlock is not used on this tablet, but the dynamic linker
// must resolve the methods before it can load the primary audio module.

extern "C" uintptr_t mtk_get_voice_unlock_dl_instance()
    __asm__("_ZN7android11AudioSystem24getVoiceUnlockDLInstanceEv");
extern "C" uintptr_t mtk_get_voice_unlock_dl_instance() { return 0; }

extern "C" uintptr_t mtk_free_voice_unlock_dl_instance()
    __asm__("_ZN7android11AudioSystem25freeVoiceUnlockDLInstanceEv");
extern "C" uintptr_t mtk_free_voice_unlock_dl_instance() { return 0; }

extern "C" uintptr_t mtk_start_voice_unlock_dl()
    __asm__("_ZN7android11AudioSystem18startVoiceUnlockDLEv");
extern "C" uintptr_t mtk_start_voice_unlock_dl() { return 0; }

extern "C" uintptr_t mtk_stop_voice_unlock_dl()
    __asm__("_ZN7android11AudioSystem17stopVoiceUnlockDLEv");
extern "C" uintptr_t mtk_stop_voice_unlock_dl() { return 0; }

extern "C" uintptr_t mtk_get_voice_unlock_dl_latency()
    __asm__("_ZN7android11AudioSystem23GetVoiceUnlockDLLatencyEv");
extern "C" uintptr_t mtk_get_voice_unlock_dl_latency() { return 0; }

extern "C" uintptr_t mtk_set_voice_unlock_src(uint32_t, uint32_t)
    __asm__("_ZN7android11AudioSystem17SetVoiceUnlockSRCEjj");
extern "C" uintptr_t mtk_set_voice_unlock_src(uint32_t, uint32_t) { return 0; }

extern "C" uintptr_t mtk_read_ref_from_ring(void*, uint32_t, void*)
    __asm__("_ZN7android11AudioSystem15ReadRefFromRingEPvjS1_");
extern "C" uintptr_t mtk_read_ref_from_ring(void*, uint32_t, void*) { return 0; }

extern "C" uintptr_t mtk_get_voice_unlock_ul_time(void*)
    __asm__("_ZN7android11AudioSystem20GetVoiceUnlockULTimeEPv");
extern "C" uintptr_t mtk_get_voice_unlock_ul_time(void*) { return 0; }
