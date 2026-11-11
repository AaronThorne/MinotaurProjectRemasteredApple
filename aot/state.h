#pragma once
#include <cstdint>
#include <cstring>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <algorithm>
struct State {
 uint32_t r[16]{}, ext[64]{}, cpsr=0x10, fpscr=0;
 void *mem=nullptr; bool check=false; int32_t status=-1;
 uint32_t cp15=0;
};
struct Result { uint64_t v; bool c=false,o=false; };
inline uint32_t nz(uint32_t x){return (x&0x80000000u)|(x==0?0x40000000u:0);}
inline Result add32(uint32_t a,uint32_t b,bool c){uint64_t v=uint64_t(a)+b+c;return {uint32_t(v),bool(v>>32),bool((~(a^b)&(a^uint32_t(v)))>>31)};}
inline Result sub32(uint32_t a,uint32_t b,bool c){return add32(a,~b,c);}
inline Result shl32(uint32_t a,uint8_t n,bool c){return {n<32?uint32_t(a<<n):0,n==0?c:n<=32?bool((a>>(32-n))&1):false};}
inline Result shr32(uint32_t a,uint8_t n,bool c){return {n<32?a>>n:0,n==0?c:n<=32?bool((a>>(n-1))&1):false};}
inline Result asr32(uint32_t a,uint8_t n,bool c){return {uint32_t(int32_t(a)>>std::min<unsigned>(n,31)),n==0?c:bool((a>>(std::min<unsigned>(n,32)-1))&1)};}
inline Result ror32(uint32_t a,uint8_t n,bool c){unsigned k=n&31;uint32_t v=k?(a>>k)|(a<<(32-k)):a;return {v,n?bool(v>>31):c};}
inline bool cond(State&s,unsigned c){bool n=s.cpsr>>31,z=(s.cpsr>>30)&1,carry=(s.cpsr>>29)&1,v=(s.cpsr>>28)&1;switch(c){case 0:return z;case 1:return !z;case 2:return carry;case 3:return !carry;case 4:return n;case 5:return !n;case 6:return v;case 7:return !v;case 8:return carry&&!z;case 9:return !carry||z;case 10:return n==v;case 11:return n!=v;case 12:return !z&&n==v;case 13:return z||n!=v;case 14:return true;default:return false;}}
inline uint64_t location(State&s){uint64_t upper=(s.fpscr&0x07f70000)|((s.cpsr>>5)&1)|((s.cpsr>>8)&2)|(((s.cpsr>>25)&3)<<8)|(((s.cpsr>>10)&0x3f)<<10);return s.r[15]|(upper<<32);}
inline void link(State&s,uint64_t loc){uint32_t u=loc>>32;s.r[15]=uint32_t(loc);s.cpsr=(s.cpsr&~0x0600fe20u)|((u&1)<<5)|((u&2)<<8)|(((u>>8)&3)<<25)|(((u>>10)&63)<<10);}
inline void bx(State&s,uint32_t addr){s.cpsr=(s.cpsr&~0x0600fc20u)|((addr&1)<<5);s.r[15]=addr&((addr&1)?~1u:~3u);}
extern "C" {
uint8_t touchHLE_cpu_read_u8(void*,uint32_t,bool*);
uint16_t touchHLE_cpu_read_u16(void*,uint32_t,bool*);
uint32_t touchHLE_cpu_read_u32(void*,uint32_t,bool*);
uint64_t touchHLE_cpu_read_u64(void*,uint32_t,bool*);
bool touchHLE_cpu_write_u8(void*,uint32_t,uint8_t);
bool touchHLE_cpu_write_u16(void*,uint32_t,uint16_t);
bool touchHLE_cpu_write_u32(void*,uint32_t,uint32_t);
bool touchHLE_cpu_write_u64(void*,uint32_t,uint64_t);
}
#define READ(N) inline uint##N##_t read##N(State&s,uint32_t a){bool e=false;auto v=touchHLE_cpu_read_u##N(s.mem,a,&e);if(e)s.status=-2;return v;}
READ(8) READ(16) READ(32) READ(64)
#define WRITE(N) inline void write##N(State&s,uint32_t a,uint##N##_t v){if(touchHLE_cpu_write_u##N(s.mem,a,v))s.status=-2;}
WRITE(8) WRITE(16) WRITE(32) WRITE(64)
inline float f32(uint32_t bits){float f;std::memcpy(&f,&bits,4);return f;}
inline double f64(uint64_t bits){double f;std::memcpy(&f,&bits,8);return f;}
inline uint32_t bits32(float f){uint32_t b;std::memcpy(&b,&f,4);return b;}
inline uint64_t bits64(double f){uint64_t b;std::memcpy(&b,&f,8);return b;}
using Block = void(*)(State&);
Block find_block(uint64_t);
void report_lookup_stats();
using U128 = __uint128_t;
inline U128 getvec(State&s,unsigned r){U128 v=0;unsigned off=r<64?(r-32)*2:(r-64)*4;std::memcpy(&v,s.ext+off,r<64?8:16);return v;}
inline void setvec(State&s,unsigned r,U128 v){unsigned off=r<64?(r-32)*2:(r-64)*4;std::memcpy(s.ext+off,&v,r<64?8:16);}
inline uint64_t getdouble(State&s,unsigned r){uint64_t v;std::memcpy(&v,s.ext+(r-32)*2,8);return v;}
inline void setdouble(State&s,unsigned r,uint64_t v){std::memcpy(s.ext+(r-32)*2,&v,8);}
inline uint32_t fcompare(double a,double b){return std::isnan(a)||std::isnan(b)?0x30000000u:a==b?0x60000000u:a<b?0x80000000u:0x20000000u;}
inline uint32_t toint(double x,bool sign,unsigned fractional,unsigned rounding){
 x=std::ldexp(x,fractional); if(std::isnan(x))return 0;
 x=rounding==3?std::trunc(x):rounding==2?std::floor(x):rounding==1?std::ceil(x):std::nearbyint(x);
 if(sign){if(x>=2147483647.)return 0x7fffffff;if(x<=-2147483648.)return 0x80000000;return uint32_t(int32_t(x));}
 if(x<=0)return 0;if(x>=4294967295.)return 0xffffffff;return uint32_t(x);
}
// touchHLE's documented lazy-link stub forms. This resolves imports, not game instructions.
inline bool import_stub(State&s,uint32_t pc){
 uint32_t word=read32(s,pc);
 if((word&0xff000000u)==0xef000000u)return false;
 if((word&0xfffff000u)==0xe59ff000u){bx(s,read32(s,pc+8+(word&0xfff)));return true;}
 if(word==0xe59fc000u && read32(s,pc+4)==0xe59cf000u){s.r[12]=read32(s,pc+8);bx(s,read32(s,s.r[12]));return true;}
 if(word==0xe59fc004u && read32(s,pc+4)==0xe08fc00cu && read32(s,pc+8)==0xe59cf000u){s.r[12]=read32(s,pc+12)+pc+12;bx(s,read32(s,s.r[12]));return true;}
 std::fprintf(stderr,"AOT import stub changed unexpectedly at %08x: %08x\n",pc,word);s.status=-3;return true;
}
