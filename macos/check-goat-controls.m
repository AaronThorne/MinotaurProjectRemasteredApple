#import "GoatControls.h"

static NSURL *prefs(NSURL *data) {
    return [data URLByAppendingPathComponent:@"touchHLE_sandbox/uk.co.llamasoft.Goat/Library/Preferences/uk.co.llamasoft.Goat.plist"];
}
int main(int argc,char **argv) {
    @autoreleasepool {
        NSURL *root=[NSURL fileURLWithPath:@(argv[1]) isDirectory:YES];
        NSURL *resources=[NSURL fileURLWithPath:@(argv[2]) isDirectory:YES];
        NSError *error=nil;
        NSURL *fresh=[root URLByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSCAssert(MPRConfigureGoatControls(fresh,resources,YES,&error),@"New profile: %@",error);
        NSMutableDictionary *original=[[NSDictionary dictionaryWithContentsOfURL:prefs(fresh)] mutableCopy];
        NSMutableData *saved=[original[@"deflex_savedata"] mutableCopy];
        // Simulate nonzero progress and unrelated settings that must survive.
        uint32_t sentinel=0x12345678;[saved replaceBytesInRange:NSMakeRange(0x100,4) withBytes:&sentinel];
        original[@"deflex_savedata"]=saved;original[@"unrelated-setting"]=@"keep me";
        [original writeToURL:prefs(fresh) atomically:YES];
        for(NSNumber *choice in @[@NO,@YES]) {
            NSCAssert(MPRConfigureGoatControls(fresh,resources,choice.boolValue,&error),@"Existing profile: %@",error);
            NSDictionary *updated=[NSDictionary dictionaryWithContentsOfURL:prefs(fresh)];
            NSMutableData *expected=[saved mutableCopy];uint32_t mode=CFSwapInt32HostToLittle(choice.boolValue?2:0);
            [expected replaceBytesInRange:NSMakeRange(0x50,4) withBytes:&mode];
            NSCAssert([updated[@"deflex_savedata"] isEqual:expected],@"Only the control word may change");
            NSCAssert([updated[@"unrelated-setting"] isEqual:@"keep me"],@"Other preferences must survive");
        }
        NSDictionary *invalid=@{@"deflex_savedata":[NSData dataWithBytes:"bad" length:3]};
        [invalid writeToURL:prefs(fresh) atomically:YES];
        NSData *before=[NSData dataWithContentsOfURL:prefs(fresh)];
        NSCAssert(!MPRConfigureGoatControls(fresh,resources,YES,&error),@"Unknown save layout must be rejected");
        NSCAssert([before isEqual:[NSData dataWithContentsOfURL:prefs(fresh)]],@"Rejected data must remain untouched");
        puts("First launch, both control modes, progress preservation and unknown-layout rejection passed.");
    }
}
