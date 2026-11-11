#import "GoatControls.h"

BOOL MPRConfigureGoatControls(NSURL *data, NSURL *resources, BOOL gamepad, NSError **error) {
    NSFileManager *files=NSFileManager.defaultManager;
    NSURL *preferences=[data URLByAppendingPathComponent:@"touchHLE_sandbox/uk.co.llamasoft.Goat/Library/Preferences/uk.co.llamasoft.Goat.plist"];
    BOOL exists=[files fileExistsAtPath:preferences.path];
    NSURL *source=exists ? preferences : [resources URLByAppendingPathComponent:@"GoatUpDefaultPreferences.plist"];
    NSData *encoded=[NSData dataWithContentsOfURL:source options:0 error:error];
    if(!encoded)return NO;
    NSPropertyListFormat format=NSPropertyListBinaryFormat_v1_0;
    NSMutableDictionary *plist=[NSPropertyListSerialization propertyListWithData:encoded options:NSPropertyListMutableContainersAndLeaves format:&format error:error];
    NSData *saved=[plist isKindOfClass:NSDictionary.class] ? plist[@"deflex_savedata"] : nil;
    uint32_t mode=UINT32_MAX;
    if([saved isKindOfClass:NSData.class] && saved.length==0xd00) {
        [saved getBytes:&mode range:NSMakeRange(0x50,4)];
        mode=CFSwapInt32LittleToHost(mode);
    }
    // Verified by changing A -> B -> C in the original game: only this word
    // changes, 0 -> 1 -> 2. Refuse any unrecognised save layout.
    if(mode>2) {
        if(error)*error=[NSError errorWithDomain:@"MinotaurGoatControls" code:1 userInfo:@{NSLocalizedDescriptionKey:@"GoatUp's saved controls could not be recognised. Your save has been left unchanged."}];
        return NO;
    }
    uint32_t target=gamepad ? 2 : 0;
    if(exists && mode==target)return YES;
    NSMutableData *updated=[saved mutableCopy];
    uint32_t little=CFSwapInt32HostToLittle(target);
    [updated replaceBytesInRange:NSMakeRange(0x50,4) withBytes:&little];
    plist[@"deflex_savedata"]=updated;
    encoded=[NSPropertyListSerialization dataWithPropertyList:plist format:format options:0 error:error];
    if(!encoded)return NO;
    if(![files createDirectoryAtURL:preferences.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error])return NO;
    return [encoded writeToURL:preferences options:NSDataWritingAtomic error:error];
}
