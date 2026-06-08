#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PontificateProject PontificateProject;

enum {
    PONTIFICATE_STATUS_OK = 0,
    PONTIFICATE_STATUS_NULL_ARGUMENT = 1,
    PONTIFICATE_STATUS_OUT_OF_MEMORY = 2,
    PONTIFICATE_STATUS_IO_ERROR = 3,
    PONTIFICATE_STATUS_UNSUPPORTED = 4,
    PONTIFICATE_STATUS_DUPLICATE = 5,
    PONTIFICATE_STATUS_MISSING = 6,
    PONTIFICATE_STATUS_OUT_OF_RANGE = 7,
    PONTIFICATE_STATUS_BUFFER_TOO_SMALL = 8,
    PONTIFICATE_STATUS_INVALID = 9
};

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

/* Returns NULL on allocation or load failure. Destroy accepts NULL. */
PontificateProject *pontificate_project_create(void);
void pontificate_project_destroy(PontificateProject *project);
PontificateProject *pontificate_project_load(const char *path);
uint32_t pontificate_project_save(const PontificateProject *project, const char *path);
uint32_t pontificate_project_import_path(PontificateProject *project, const char *path);
uint32_t pontificate_project_asset_count(const PontificateProject *project);

/*
 * Summary functions write a NUL-terminated UTF-8 summary into caller-owned
 * storage. They return PONTIFICATE_STATUS_BUFFER_TOO_SMALL without writing a
 * partial summary when buffer_len cannot hold the full text plus terminator.
 * Summaries are pipe-delimited key=value fields. Field text is not escaped in
 * schema v1, so callers should treat summaries as display text, not a parser
 * contract for arbitrary paths containing '|'.
 */
uint32_t pontificate_project_asset_summary(
    const PontificateProject *project,
    uint32_t index,
    char *buffer,
    uint32_t buffer_len);

uint32_t pontificate_project_add_asset_to_timeline(PontificateProject *project, uint32_t asset_index);
uint32_t pontificate_project_clip_count(const PontificateProject *project);
uint32_t pontificate_project_clip_summary(
    const PontificateProject *project,
    uint32_t index,
    char *buffer,
    uint32_t buffer_len);

#ifdef __cplusplus
}
#endif
