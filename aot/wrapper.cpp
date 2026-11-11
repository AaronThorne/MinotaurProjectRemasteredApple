#include "state.h"
#ifdef MPR_LIBGCC_DIVISION
#include "libgcc-division.inc"
#endif
#include <utility>
struct Context {uint32_t regs[16],extregs[64],cpsr,fpscr;};
extern "C" {
State* touchHLE_DynarmicWrapper_new(void*,size_t){std::fprintf(stderr,"GRIDRUNNER AOT: static CPU backend; no JIT or interpreter fallback.\n");return new State;}
void touchHLE_DynarmicWrapper_delete(State*s){report_lookup_stats();delete s;}
const uint32_t* touchHLE_DynarmicWrapper_regs_const(const State*s){return s->r;}
uint32_t* touchHLE_DynarmicWrapper_regs_mut(State*s){return s->r;}
uint32_t touchHLE_DynarmicWrapper_cpsr(const State*s){return s->cpsr;}
void touchHLE_DynarmicWrapper_set_cpsr(State*s,uint32_t v){s->cpsr=v;}
void touchHLE_DynarmicWrapper_swap_context(State*s,Context*c){
 for(int i=0;i<16;i++)std::swap(s->r[i],c->regs[i]);
 for(int i=0;i<64;i++)std::swap(s->ext[i],c->extregs[i]);
 std::swap(s->cpsr,c->cpsr);std::swap(s->fpscr,c->fpscr);
}
void touchHLE_DynarmicWrapper_invalidate_cache_range(State*,uint32_t,uint32_t){}
int32_t touchHLE_DynarmicWrapper_run_or_step(State*s,void*mem,uint64_t*ticks){
 s->mem=mem;s->status=-1;uint64_t remaining=ticks?*ticks:1;
 while(remaining && s->status==-1){
  uint64_t key=location(*s);auto block=find_block(key);
#ifdef MPR_LIBGCC_DIVISION
  if (!block) block = mpr_libgcc_division::find_block(key);
#endif
  if(!block && !(s->cpsr&32)){auto pc=s->r[15];auto instruction=read32(*s,pc);auto next=read32(*s,pc+4);if((instruction&0xff000000u)==0xef000000u && ((instruction&0x800000u)||next==0xe12fff1eu||next==0xe7ffdefeu)){s->r[15]+=4;s->status=instruction&0xffffffu;remaining--;continue;}}
  if(!block){std::fprintf(stderr,"AOT missing location 0x%llx; pc=0x%08x cpsr=0x%08x\n",(unsigned long long)key,s->r[15],s->cpsr);std::fprintf(stderr,"AOT code words: %08x %08x\n",read32(*s,s->r[15]&~3u),read32(*s,(s->r[15]&~3u)+4));s->status=-3;break;}
  block(*s);remaining--;
 }
 if(ticks)*ticks=remaining;
 s->mem=nullptr;return s->status;
}
}
