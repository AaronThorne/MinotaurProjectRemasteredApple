// Offline ARM/Thumb lifting probe. No original game bytes are checked in.
#include <cstdio>
#include <cstdint>
#include <map>
#include <unordered_map>
#include <string>
#include <fstream>
#include <vector>
#include <set>
#include <deque>
#include <cstring>
#include <functional>
#include "dynarmic/frontend/A32/translate/a32_translate.h"
#include "dynarmic/frontend/A32/translate/translate_callbacks.h"
#include "dynarmic/frontend/A32/a32_location_descriptor.h"
#include "dynarmic/frontend/A32/a32_ir_emitter.h"
#include "dynarmic/ir/basic_block.h"
#include "dynarmic/ir/opcodes.h"
#include "dynarmic/ir/cond.h"
#include "dynarmic/ir/value.h"
#include "dynarmic/ir/type.h"
#include "dynarmic/ir/acc_type.h"
using namespace Dynarmic;
struct Callbacks : A32::TranslateCallbacks {
 std::map<uint32_t,uint32_t> words;
 std::optional<uint32_t> MemoryReadCode(uint32_t addr) override { auto i=words.find(addr);return i==words.end()?std::nullopt:std::optional<uint32_t>(i->second); }
 bool PreCodeReadHook(bool,uint32_t,A32::IREmitter&) override{return true;}
 void PreCodeTranslationHook(bool,uint32_t,A32::IREmitter&) override{}
 uint64_t GetTicksForCode(bool,uint32_t,uint32_t) override{return 1;}
};
struct TermDump : boost::static_visitor<std::string> {
 TermDump() = default;
 std::string operator()(const IR::Term::Invalid&) const {return "{\"type\":\"Invalid\"}";}
 std::string operator()(const IR::Term::Interpret& t) const {return "{\"type\":\"Interpret\",\"next\":"+std::to_string(t.next.Value())+"}";}
 std::string operator()(const IR::Term::ReturnToDispatch&) const{return "{\"type\":\"Dispatch\"}";}
 std::string operator()(const IR::Term::PopRSBHint&) const{return "{\"type\":\"Dispatch\"}";}
 std::string operator()(const IR::Term::FastDispatchHint&) const{return "{\"type\":\"Dispatch\"}";}
 std::string operator()(const IR::Term::LinkBlock& t) const{return "{\"type\":\"Link\",\"next\":"+std::to_string(t.next.Value())+"}";}
 std::string operator()(const IR::Term::LinkBlockFast& t) const{return "{\"type\":\"Link\",\"next\":"+std::to_string(t.next.Value())+"}";}
 std::string operator()(const IR::Term::If& t) const{return "{\"type\":\"If\",\"cond\":"+std::to_string(int(t.if_))+",\"yes\":"+boost::apply_visitor(*this,t.then_)+",\"no\":"+boost::apply_visitor(*this,t.else_)+"}";}
 std::string operator()(const IR::Term::CheckBit& t) const{return "{\"type\":\"CheckBit\",\"yes\":"+boost::apply_visitor(*this,t.then_)+",\"no\":"+boost::apply_visitor(*this,t.else_)+"}";}
 std::string operator()(const IR::Term::CheckHalt& t) const{return "{\"type\":\"CheckHalt\",\"no\":"+boost::apply_visitor(*this,t.else_)+"}";}
};
int main(int argc,char **argv){
 if(argc<2){std::fprintf(stderr,"Usage: dump-ir trace.bin\n");return 2;}
 std::ifstream in(argv[1],std::ios::binary); if(!in)return 2;
 uint64_t loc;uint32_t a,b;std::map<uint64_t,std::pair<uint32_t,uint32_t>> records;
 while(in.read((char*)&loc,8)&&in.read((char*)&a,4)&&in.read((char*)&b,4)) records[loc]={a,b};
 Callbacks image;
 if(argc>=3){
  std::ifstream binary(argv[2],std::ios::binary);std::vector<char> bytes((std::istreambuf_iterator<char>(binary)),{});
  uint32_t image_base=argc>=4?std::strtoul(argv[3],nullptr,0):0x1000;
  for(size_t off=0;off+4<=bytes.size();off+=4){uint32_t word;std::memcpy(&word,bytes.data()+off,4);image.words[uint32_t(off)+image_base]=word;}
 }
 for(auto &[key,words]:records){image.words[uint32_t(key)&~3u]=words.first;image.words[(uint32_t(key)&~3u)+4]=words.second;}
 std::deque<uint64_t> pending;std::set<uint64_t> visited;
 for(auto &[key,words]:records)pending.push_back(key);
 std::map<std::string,int> counts;
 while(!pending.empty()){
  auto key=pending.front()&~(4ULL<<32);pending.pop_front();
  if(!visited.insert(key).second)continue;
  uint32_t pc=uint32_t(key);Callbacks &cb=image;
  if(auto record=records.find(key);record!=records.end()){cb.words[pc&~3u]=record->second.first;cb.words[(pc&~3u)+4]=record->second.second;}
  if(!image.words.count(pc&~3u))continue;
  A32::LocationDescriptor desc(IR::LocationDescriptor{key});
  auto block=A32::Translate(desc.SetSingleStepping(true),&cb,{A32::ArchVersion::v7,false,false});
  std::printf("{\"location\":%llu,\"words\":[%u,%u],\"condition\":%d,\"failed\":%llu,\"end\":%llu,\"terminal\":%s,\"ops\":[",(unsigned long long)key,cb.MemoryReadCode(pc&~3u).value_or(0),cb.MemoryReadCode((pc&~3u)+4).value_or(0),int(block.GetCondition()),(unsigned long long)(block.HasConditionFailedLocation()?block.ConditionFailedLocation().Value():0),(unsigned long long)block.EndLocation().Value(),boost::apply_visitor(TermDump{},block.GetTerminal()).c_str());
  std::unordered_map<const IR::Inst*,int> ids;int id=0;for(const auto &i:block)ids[&i]=id++;
  if(argc>=3){
   auto enqueue=[&](uint64_t next){next&=~(4ULL<<32);if(image.words.count(uint32_t(next)&~3u)&&!visited.count(next))pending.push_back(next);};
   std::function<void(const IR::Terminal&)> follow;
   follow=[&](const IR::Terminal&t){
    if(auto p=boost::get<IR::Term::LinkBlock>(&t))enqueue(p->next.Value());
    if(auto p=boost::get<IR::Term::LinkBlockFast>(&t))enqueue(p->next.Value());
    if(auto p=boost::get<IR::Term::If>(&t)){follow(p->then_);follow(p->else_);}
    if(auto p=boost::get<IR::Term::CheckBit>(&t)){follow(p->then_);follow(p->else_);}
    if(auto p=boost::get<IR::Term::CheckHalt>(&t))follow(p->else_);
   };
   follow(block.GetTerminal());
   // Cache hints return through the dispatcher, but execution continues at
   // the next instruction. Recover that path just like a normal fallthrough.
   for(const auto &inst:block)if(IR::GetNameOf(inst.GetOpcode())=="ExceptionRaised" && inst.GetArg(1).IsImmediate()){
    auto exception=inst.GetArg(1).GetImmediateAsU64();
    if(exception>=9 && exception<=11)enqueue(block.EndLocation().Value());
   }
   for(const auto &inst:block)if(inst.GetOpcode()==IR::Opcode::PushRSB && inst.GetArg(0).IsImmediate())enqueue(inst.GetArg(0).GetImmediateAsU64());
   if(block.HasConditionFailedLocation())enqueue(block.ConditionFailedLocation().Value());
  }
  bool comma=false;
  for(const auto &i:block){
   auto op=IR::GetNameOf(i.GetOpcode());counts[op]++;
   std::printf("%s{\"op\":\"%s\",\"type\":\"%s\",\"args\":[",comma?",":"",op.c_str(),IR::GetNameOf(i.GetType()).c_str());comma=true;
   for(size_t j=0;j<i.NumArgs();j++){
    auto v=i.GetArg(j);if(j)std::printf(",");
    if(!v.IsImmediate()){std::printf("{\"ref\":%d}",ids.at(v.GetInst()));continue;}
    uint64_t value=0;
    switch(v.GetType()){
     case IR::Type::A32Reg:value=int(v.GetA32RegRef());break;
     case IR::Type::A32ExtReg:value=int(v.GetA32ExtRegRef());break;
     case IR::Type::Cond:value=int(v.GetCond());break;
     case IR::Type::AccType:value=int(v.GetAccType());break;
     case IR::Type::CoprocInfo:{auto x=v.GetCoprocInfo();for(int n=0;n<8;n++)value|=uint64_t(x[n])<<(8*n);break;}
     case IR::Type::Void:break;
     default:value=v.GetImmediateAsU64();break;
    }
    std::printf("{\"imm\":%llu}",(unsigned long long)value);
   }
   std::printf("]}");
  }
  std::printf("]}\n");
 }
 for(auto &[name,count]:counts)std::fprintf(stderr,"%s %d\n",name.c_str(),count);
}
