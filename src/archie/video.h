#ifndef RG_ARCHIE_VIDEO_H
#define RG_ARCHIE_VIDEO_H
#include <stdint.h>
#define ARCHIE_STRIDE 160
#define ARCHIE_HEIGHT 256
#define ARCHIE_TOP 28
#define ARCHIE_SCREEN_BYTES (ARCHIE_STRIDE * ARCHIE_HEIGHT)
typedef struct {
    uint8_t *bank[2];
    unsigned hidden;
    uint32_t allocated;
    uint32_t palette[16];
} ArchieVideo;
int archie_video_open(ArchieVideo *v);
int archie_video_present(ArchieVideo *v);
void archie_video_close(void);
int archie_video_restore_ok(void);
uint32_t archie_video_previous_size(void);
uint32_t archie_video_restored_size(void);
uint32_t archie_time(void);
uint32_t archie_vsync_count(void);
const char *archie_video_error(void);
#endif
