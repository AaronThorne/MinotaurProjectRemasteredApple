// Differential check: the native translations versus the existing ARM engine.
#include "state.h"
#include <array>
#include <fstream>
#include <vector>
#include <random>
#include "dynarmic/interface/A32/a32.h"
#include "dynarmic/interface/A32/config.h"
struct Memory {std::array<uint8_t,65536> bytes{};uint32_t pc,a,b;};
#define RD(N) extern "C" uint##N##_t touchHLE_cpu_read_u##N(void*m,uint32_t a,bool*e){*e=false;uint##N##_t v=0;auto&mem=*(Memory*)m;for(unsigned i=0;i<N/8;i++)v|=uint##N##_t(mem.bytes[(a+i)&65535])<<(i*8);return v;}
#define WR(N) extern "C" bool touchHLE_cpu_write_u##N(void*m,uint32_t a,uint##N##_t v){auto&mem=*(Memory*)m;for(unsigned i=0;i<N/8;i++)mem.bytes[(a+i)&65535]=v>>(i*8);return false;}
RD(8) RD(16)
extern "C" uint32_t touchHLE_cpu_read_u32(void*m,uint32_t a,bool*e){*e=false;auto&mem=*(Memory*)m;if(a==(mem.pc&~3u))return mem.a;if(a==(mem.pc&~3u)+4)return mem.b;uint32_t v=0;for(unsigned i=0;i<4;i++)v|=uint32_t(mem.bytes[(a+i)&65535])<<(i*8);return v;}
RD(64) WR(8) WR(16) WR(32) WR(64)
struct Callbacks : Dynarmic::A32::UserCallbacks {
 Memory mem;bool error=false;
 std::optional<uint32_t> MemoryReadCode(uint32_t a) override {if(a==(mem.pc&~3u))return mem.a;if(a==(mem.pc&~3u)+4)return mem.b;return std::nullopt;}
 uint8_t MemoryRead8(uint32_t a)override{return touchHLE_cpu_read_u8(&mem,a,&error);}
 uint16_t MemoryRead16(uint32_t a)override{return touchHLE_cpu_read_u16(&mem,a,&error);}
 uint32_t MemoryRead32(uint32_t a)override{return touchHLE_cpu_read_u32(&mem,a,&error);}
 uint64_t MemoryRead64(uint32_t a)override{return touchHLE_cpu_read_u64(&mem,a,&error);}
 void MemoryWrite8(uint32_t a,uint8_t v)override{touchHLE_cpu_write_u8(&mem,a,v);}
 void MemoryWrite16(uint32_t a,uint16_t v)override{touchHLE_cpu_write_u16(&mem,a,v);}
 void MemoryWrite32(uint32_t a,uint32_t v)override{touchHLE_cpu_write_u32(&mem,a,v);}
 void MemoryWrite64(uint32_t a,uint64_t v)override{touchHLE_cpu_write_u64(&mem,a,v);}
 void InterpreterFallback(uint32_t,size_t)override{error=true;}
 void CallSVC(uint32_t)override{error=true;}
 void ExceptionRaised(uint32_t,Dynarmic::A32::Exception e)override{
  using E=Dynarmic::A32::Exception;
  if(e==E::PreloadData || e==E::PreloadDataWithIntentToWrite || e==E::PreloadInstruction)return;
  error=true;
 }
 void AddTicks(uint64_t)override{}
 uint64_t GetTicksRemaining()override{return 1;}
};
int main(int argc,char**argv){
 std::ifstream in(argv[1],std::ios::binary);uint64_t loc;uint32_t a,b;std::mt19937 rng(20261109);unsigned tests=0,fail=0;
 std::array<std::array<uint8_t,65536>,4> patterns{};
 for(size_t n=0;n<65536;n++){patterns[0][n]=0;patterns[1][n]=255;patterns[2][n]=uint8_t(n);patterns[3][n]=uint8_t(rng());}
 Callbacks cb;Dynarmic::A32::UserConfig config;config.callbacks=&cb;Dynarmic::A32::Jit jit(config);
 while(in.read((char*)&loc,8)&&in.read((char*)&a,4)&&in.read((char*)&b,4)){
  auto block=find_block(loc);if(!block){std::fprintf(stderr,"Missing compiled check location %llx\n",(unsigned long long)loc);return 2;}
  for(int trial=0;trial<4;trial++){
   State s;link(s,loc);s.cpsr|=(rng()&0xf0000000)|0x10;s.mem=&cb.mem;
   for(int n=0;n<15;n++)s.r[n]=trial==0?(rng()&65532)+4096:trial==1?rng():trial==2?std::array<uint32_t,5>{0,1,0x7fffffff,0x80000000,0xffffffff}[(n+tests)%5]:(rng()&~3u);
   for(int n=0;n<64;n++)s.ext[n]=bits32(float(int(rng()%2000)-1000)*0.1f);
   cb.mem.pc=uint32_t(loc);cb.mem.a=a;cb.mem.b=b;cb.error=false;
   cb.mem.bytes=patterns[trial];
   Memory expected=cb.mem;
   for(int n=0;n<16;n++)jit.Regs()[n]=s.r[n];
   for(int n=0;n<64;n++)jit.ExtRegs()[n]=s.ext[n];
   jit.SetCpsr(s.cpsr);jit.SetFpscr(s.fpscr);jit.ClearCache();
   jit.Step();if(cb.error)continue;
   std::swap(expected,cb.mem);block(s);tests++;if(tests%1000==0)std::fprintf(stderr,"checked %u\n",tests);
   bool bad=false;for(int n=0;n<16;n++)if(jit.Regs()[n]!=s.r[n])bad=true;
   // Compare integer state first; floating-point status needs separate conformance work.
   if(jit.Cpsr()!=s.cpsr)bad=true;
   for(int n=0;n<64;n++)if(jit.ExtRegs()[n]!=s.ext[n])bad=true;
   if(expected.bytes!=cb.mem.bytes)bad=true;
   if(bad&&fail++<12){std::printf("Mismatch key=%llx cpsr native=%08x reference=%08x\n",(unsigned long long)loc,s.cpsr,jit.Cpsr());for(int n=0;n<16;n++)if(jit.Regs()[n]!=s.r[n])std::printf(" r%d native=%08x reference=%08x\n",n,s.r[n],jit.Regs()[n]);}
  }
 }
 std::printf("%u tested; %u mismatches\n",tests,fail);return fail?1:0;
}
