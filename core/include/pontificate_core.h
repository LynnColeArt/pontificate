#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

const char *pontificate_version(void);
const char *pontificate_default_project_summary(void);
uint32_t pontificate_default_track_count(void);
uint32_t pontificate_default_clip_count(void);
uint32_t pontificate_default_subtitle_cue_count(void);
double pontificate_evaluate_keyframe_linear(
    double start_value,
    double end_value,
    double start_time,
    double end_time,
    double at_time);

#ifdef __cplusplus
}
#endif
