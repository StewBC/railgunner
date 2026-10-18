/* Host-only semantic oracle for native assembly tests; never linked on IIgs. */
#define main reference_driver_main
#include "../../src/core/main.c"
#undef main
#include "game_init.h"
#include "score.h"
#include "tallies.h"
#include "hiscore.h"
#include "rail.h"
#include "bullets.h"
#include "player.h"
#include "drones.h"
#include "cargo.h"
#include "parcels.h"
#include "hud.h"
#include "waves.h"
#include "message.h"
#include "title.h"
#include "story.h"
#include "instructions.h"
#include "stage.h"
#include "life.h"
#include "play.h"
#include "typewriter.h"
#include "gameover.h"
#include "input.h"
#include "collision.h"

#include "data/tables.h"

static Game game;
static char initial_lines[10][HS_LINE_LEN];
static char initial_prompt[256];
static size_t prompt_count;

static void scalar(const char *name, unsigned long value) {
    printf(",\"%s\":%lu", name, value);
}
static void vector(const char *name, const uint8_t *values, size_t count) {
    size_t i;
    printf(",\"%s\":[", name);
    for (i = 0; i < count; ++i) printf("%s%u", i ? "," : "", values[i]);
    putchar(']');
}
static void pointer_state(void) {
    const char *tables[] = {story_text, instructions_text};
    unsigned id, offset;
    if (!game.type_src) { scalar("type_src_id", 0); scalar("type_src_offset", 0); return; }
    for (id = 0; id < 2; ++id) {
        offset = 0;
        do {
            if (game.type_src == tables[id] + offset) {
                scalar("type_src_id", id + 1); scalar("type_src_offset", offset); return;
            }
        } while (tables[id][offset++] != 0);
    }
    scalar("type_src_id", 255); scalar("type_src_offset", 0);
}
static void snapshot(void) {
    unsigned row, col;
    uint8_t lines[10 * HS_LINE_LEN];
    printf("{\"kind\":\"snapshot\",\"normalization\":1");
#define RG_SCALAR(n,t) scalar(#n, (unsigned long)game.n);
#define RG_ARRAY(n,t) vector(#n, game.n, sizeof(game.n));
#define RG_OBJECT(n) do { unsigned i; uint8_t v[OBJECT_CAPACITY]; for(i=0;i<OBJECT_CAPACITY;++i)v[i]=game.objects[i].n; vector("objects." #n,v,OBJECT_CAPACITY); } while(0);
#define RG_CELL(n) do { unsigned i; uint8_t v[SCREEN_W*SCREEN_H]; for(i=0;i<SCREEN_W*SCREEN_H;++i)v[i]=game.cells[i/SCREEN_W][i%SCREEN_W].n; vector("cells." #n,v,SCREEN_W*SCREEN_H); } while(0);
#include "native_oracle_fields.inc"
#undef RG_SCALAR
#undef RG_ARRAY
#undef RG_OBJECT
#undef RG_CELL
    pointer_state();
    for(row=0;row<10;++row)for(col=0;col<HS_LINE_LEN;++col)lines[row*HS_LINE_LEN+col]=(uint8_t)hs_lines[row][col];
    vector("hs_lines", lines, sizeof(lines));
    vector("str_hs_prompt", (const uint8_t *)str_hs_prompt, prompt_count);
    puts("}");
}
static int schema_first;
static void schema_entry(const char *name, size_t width, size_t count) {
    printf("%s\"%s\":{\"width\":%u,\"count\":%u}", schema_first ? "" : ",", name, (unsigned)width, (unsigned)count);
    schema_first=0;
}
static void schema(void) {
    schema_first=1; putchar('{');
#define RG_SCALAR(n,t) schema_entry(#n,sizeof(game.n),1);
#define RG_ARRAY(n,t) schema_entry(#n,sizeof(game.n[0]),sizeof(game.n)/sizeof(game.n[0]));
#define RG_OBJECT(n) schema_entry("objects." #n,1,OBJECT_CAPACITY);
#define RG_CELL(n) schema_entry("cells." #n,1,SCREEN_W*SCREEN_H);
#include "native_oracle_fields.inc"
#undef RG_SCALAR
#undef RG_ARRAY
#undef RG_OBJECT
#undef RG_CELL
    schema_entry("type_src_id",1,1); schema_entry("type_src_offset",2,1);
    schema_entry("hs_lines",1,10*HS_LINE_LEN); schema_entry("str_hs_prompt",1,prompt_count);
    puts("}");
}
static int set_field(const char *name, unsigned index, unsigned long value) {
#define RG_SCALAR(n,t) if(!strcmp(name,#n)&&index==0){game.n=(t)value;return 1;}
#define RG_ARRAY(n,t) if(!strcmp(name,#n)&&index<sizeof(game.n)/sizeof(game.n[0])){game.n[index]=(t)value;return 1;}
#define RG_OBJECT(n) if(!strcmp(name,"objects." #n)&&index<OBJECT_CAPACITY){game.objects[index].n=(uint8_t)value;return 1;}
#define RG_CELL(n) if(!strcmp(name,"cells." #n)&&index<SCREEN_W*SCREEN_H){game.cells[index/SCREEN_W][index%SCREEN_W].n=(uint8_t)value;return 1;}
#include "native_oracle_fields.inc"
#undef RG_SCALAR
#undef RG_ARRAY
#undef RG_OBJECT
#undef RG_CELL
    if(!strcmp(name,"hs_lines")&&index<10*HS_LINE_LEN){hs_lines[index/HS_LINE_LEN][index%HS_LINE_LEN]=(char)value;return 1;}
    if(!strcmp(name,"str_hs_prompt")&&index<prompt_count){str_hs_prompt[index]=(char)value;return 1;}
    return 0;
}
static void restore_tables(void) {
    unsigned i;
    for(i=0;i<10;++i)memcpy(hs_lines[i],initial_lines[i],HS_LINE_LEN);
    memcpy(str_hs_prompt,initial_prompt,prompt_count);
}
static int call_routine(const char *name, int argc, unsigned a, unsigned b, unsigned c) {
    uint8_t slot=255; int status;
#define CALL0(n,f) if(!strcmp(name,n)&&argc==0){f(&game);return 1;}
#define CALL1(n,f) if(!strcmp(name,n)&&argc==1){f(&game,(uint8_t)a);return 1;}
    CALL0("rail_reset",rail_reset)
    CALL0("rail_strike_frame_reset",rail_strike_frame_reset)
    CALL0("rail_clear_heal_marks",rail_clear_heal_marks)
    CALL0("rail_begin_repair",rail_begin_repair)
    CALL0("rail_repair_tick",rail_repair_tick)
    CALL0("bullets_init",bullets_init)
    CALL0("bullets_update",bullets_update)
    CALL0("player_begin_deploy",player_begin_deploy)
    CALL0("player_begin_death_fatal",player_begin_death_fatal)
    CALL0("player_begin_death_respawn",player_begin_death_respawn)
    CALL0("player_update",player_update)
    CALL1("rail_apply_ab_hit",rail_apply_ab_hit)
    CALL1("bullets_destroy",bullets_destroy)
    CALL0("drones_init",drones_init)
    CALL0("drones_update",drones_update)
    CALL0("drones_clear_field",drones_clear_field)
    CALL0("drones_roll_cooldown",drones_roll_cooldown)
    CALL0("cargo_init",cargo_init)
    CALL0("cargo_update",cargo_update)
    CALL0("cargo_reward_level_clear",cargo_reward_level_clear)
    CALL0("cargo_despawn_sprite",cargo_despawn_sprite)
    CALL0("cargo_clear_stacks",cargo_clear_stacks)
    CALL0("cargo_paint_ghij",cargo_paint_ghij)
    CALL0("cargo_detonate",cargo_detonate)
    CALL0("parcels_init",parcels_init)
    CALL0("parcels_level_reset",parcels_level_reset)
    CALL0("parcels_on_kill",parcels_on_kill)
    CALL0("parcels_update",parcels_update)
    CALL1("drones_apply_bullet_hit",drones_apply_bullet_hit)
    CALL1("drones_apply_rail_strikes",drones_apply_rail_strikes)
    CALL1("cargo_on_c_impact",cargo_on_c_impact)
    CALL0("hud_paint_status_if_dirty",hud_paint_status_if_dirty)
    CALL0("hud_paint_full_line",hud_paint_full_line)
    CALL0("waves_load",waves_load)
    CALL0("waves_note_kill",waves_note_kill)
    CALL0("waves_check_clear",waves_check_clear)
    CALL0("waves_update_banner",waves_update_banner)
    CALL0("message_clear_banner_zone",message_clear_banner_zone)
    CALL0("message_show_rank_banner",message_show_rank_banner)
    CALL0("message_tick_banner_color",message_tick_banner_color)
    CALL0("message_restore_hud_line",message_restore_hud_line)
    CALL0("tallies_paint_gameover",tallies_paint_gameover)
    CALL0("title_gfx_enter",title_gfx_enter)
    CALL0("title_gfx_update",title_gfx_update)
    CALL0("title_text_enter",title_text_enter)
    CALL0("title_text_update",title_text_update)
    CALL0("title_text_color_scores",title_text_color_scores)
    CALL0("title_text_rotate_colors",title_text_rotate_colors)
    CALL0("story_enter",story_enter)
    CALL0("story_update",story_update)
    CALL0("instructions_enter",instructions_enter)
    CALL0("instructions_update",instructions_update)
    CALL0("stage_init_enter",stage_init_enter)
    CALL0("stage_init_update",stage_init_update)
    CALL0("next_life_enter",next_life_enter)
    CALL0("next_life_update",next_life_update)
    CALL0("play_enter",play_enter)
    CALL0("play_update",play_update)
    CALL0("next_wave_enter",next_wave_enter)
    CALL0("next_wave_update",next_wave_update)
    CALL0("next_level_enter",next_level_enter)
    CALL0("next_level_update",next_level_update)
    CALL0("typewriter_init",typewriter_init)
    CALL0("typewriter_update",typewriter_update)
    CALL0("gameover_enter",gameover_enter)
    CALL0("gameover_update",gameover_update)
    CALL0("hiscore_reset",hiscore_reset)
    CALL0("hiscore_enter",hiscore_enter)
    CALL0("hiscore_update",hiscore_update)
    CALL0("hs_paint_table",hs_paint_table)
    CALL0("input_poll",input_poll)
    CALL0("collision_update",collision_update)
    CALL0("objects_init",objects_init)
    CALL0("objects_reap",objects_reap)
    CALL0("objects_hide_all",objects_hide_all)
    CALL1("objects_clear_slot",objects_clear_slot)
    CALL1("objects_discard_new",objects_discard_new)
    CALL0("cells_clear",cells_clear)
    CALL0("screen_clear",screen_clear)
    CALL0("screen_draw_playfield",screen_draw_playfield)
    CALL0("hud_color_static",hud_color_static)
    CALL0("score_reset",score_reset)
    CALL0("score_add_hit",score_add_hit)
    CALL1("score_add_n",score_add_n)
    CALL0("score_paint_if_dirty",score_paint_if_dirty)
    CALL0("tallies_reset",tallies_reset)
    CALL0("tallies_note_shot",tallies_note_shot)
    CALL1("tallies_note_kill",tallies_note_kill)
    CALL0("game_init_enter",game_init_enter)
    CALL0("game_init_update",game_init_update)
    CALL1("mode_set",mode_set)
    CALL0("mode_run",mode_run)
    CALL0("hiscore_insert",hiscore_insert)
#undef CALL0
#undef CALL1
    if(!strcmp(name,"drones_count_active")&&argc==0){printf("{\"kind\":\"call\",\"name\":\"%s\",\"value\":%u}\n",name,drones_count_active(&game));return 1;}
    if(!strcmp(name,"drones_rng8")&&argc==0){printf("{\"kind\":\"call\",\"name\":\"%s\",\"value\":%u}\n",name,drones_rng8(&game));return 1;}
    if(!strcmp(name,"hiscore_qualifies")&&argc==0){printf("{\"kind\":\"call\",\"name\":\"%s\",\"value\":%d}\n",name,hiscore_qualifies(&game));return 1;}
    if(!strcmp(name,"player_at_intersection")&&argc==0){printf("{\"kind\":\"call\",\"name\":\"%s\",\"value\":%d}\n",name,player_at_intersection(&game));return 1;}
    if(!strcmp(name,"bullets_find_at")&&argc==3){status=bullets_find_at(&game,(uint8_t)a,(uint8_t)b,(uint8_t)c,&slot);printf("{\"kind\":\"call\",\"name\":\"%s\",\"status\":%d,\"slot\":%u}\n",name,status,slot);return 1;}
    if(!strcmp(name,"bullets_half_from_glyph")&&argc==1){status=bullets_half_from_glyph((uint8_t)a,&slot);printf("{\"kind\":\"call\",\"name\":\"%s\",\"status\":%d,\"half\":%u}\n",name,status,slot);return 1;}
    if(!strcmp(name,"objects_alloc")&&argc==0){status=objects_alloc(&game,&slot);printf("{\"kind\":\"call\",\"name\":\"%s\",\"status\":%d,\"slot\":%u}\n",name,status,slot);return 1;}
    if(!strcmp(name,"objects_retire")&&argc==1){status=objects_retire(&game,(uint8_t)a);printf("{\"kind\":\"call\",\"name\":\"%s\",\"status\":%d}\n",name,status);return 1;}
    if(!strcmp(name,"screen_get_xy")&&argc==2){printf("{\"kind\":\"call\",\"name\":\"%s\",\"value\":%u}\n",name,screen_get_xy(&game,(uint8_t)a,(uint8_t)b));return 1;}
    if(!strcmp(name,"screen_put_xy")&&argc==3){screen_put_xy(&game,(uint8_t)a,(uint8_t)b,(uint8_t)c);return 1;}
    if(!strcmp(name,"screen_color_xy")&&argc==3){screen_color_xy(&game,(uint8_t)a,(uint8_t)b,(uint8_t)c);return 1;}
    if(!strcmp(name,"ascii_to_screen")&&argc==1){printf("{\"kind\":\"call\",\"name\":\"%s\",\"value\":%u}\n",name,ascii_to_screen((uint8_t)a));return 1;}
    if(!strcmp(name,"screen_print_fixture")&&argc==2){screen_print(&game,(uint8_t)a,(uint8_t)b," AZ09!?_az");return 1;}
    if(!strcmp(name,"screen_color_row")&&argc==2){screen_color_row(&game,(uint8_t)a,(uint8_t)b);return 1;}
    return 0;
}
int main(int argc, char **argv) {
    char buffer[256], name[64]; unsigned i; int each_tick=0, saw_dump=0;
    prompt_count=strlen(str_hs_prompt)+1;
    if(prompt_count>sizeof(initial_prompt))return 2;
    for(i=0;i<10;++i)memcpy(initial_lines[i],hs_lines[i],HS_LINE_LEN);
    memcpy(initial_prompt,str_hs_prompt,prompt_count);
    if(argc==2&&!strcmp(argv[1],"--schema")){schema();return 0;}
    if(argc==2&&!strcmp(argv[1],"--each-tick"))each_tick=1;
    else if(argc!=1){fprintf(stderr,"expected --schema or --each-tick\n");return 2;}
    sim_init(&game);
    while(fgets(buffer,sizeof(buffer),stdin)) {
        char *line=buffer; size_t len=strlen(line); unsigned a=0,b=0,c=0,index=0,count=0; unsigned long value=0; int parsed;
        while(len&&(line[len-1]=='\n'||line[len-1]=='\r'||line[len-1]==' '||line[len-1]=='\t'))line[--len]=0;
        while(*line==' '||*line=='\t')++line;
        if(!*line||*line=='#')continue;
        if(!strcmp(line,"dump")){snapshot();continue;}
        if(!strcmp(line,"reset")){restore_tables();sim_init(&game);continue;}
        if(!strcmp(line,"bare")){restore_tables();memset(&game,0,sizeof(game));continue;}
        if(!strcmp(line,"tick"))count=1;
        else if(!strncmp(line,"tick ",5)){if(sscanf(line+5,"%u",&count)!=1||count==0||count>65535){fprintf(stderr,"invalid tick count\n");return 1;}}
        if(count){for(i=0;i<count;++i){sim_tick(&game);if(each_tick)snapshot();}continue;}
        if(sscanf(line,"dirs %u",&a)==1&&!strncmp(line,"dirs ",5)){game.input_dirs=(uint8_t)a;continue;}
        if(sscanf(line,"set %63s %u %lu",name,&index,&value)==3&&!strncmp(line,"set ",4)&&set_field(name,index,value))continue;
        if(sscanf(line,"type-source %u %u",&a,&b)==2&&!strncmp(line,"type-source ",12)){
            const char *text=a==1?story_text:a==2?instructions_text:NULL;
            if(a==0&&b==0){game.type_src=NULL;continue;}
            if(text&&b<=strlen(text)){game.type_src=text+b;continue;}
        }
        if(!strncmp(line,"call ",5)){
            parsed=sscanf(line+5,"%63s %u %u %u",name,&a,&b,&c);
            if(parsed>=1&&call_routine(name,parsed-1,a,b,c))continue;
        }
        if(handle_line(&game,line,&saw_dump)){fprintf(stderr,"oracle command failed: %s\n",line);return 1;}
    }
    return ferror(stdin)?1:0;
}
