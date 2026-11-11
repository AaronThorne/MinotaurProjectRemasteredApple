#import <AppKit/AppKit.h>
#include <unistd.h>
#import "GoatControls.h"

int main(int argc, char **argv) {
    @autoreleasepool {
        NSBundle *bundle = NSBundle.mainBundle;
        NSString *game = [bundle objectForInfoDictionaryKey:@"MPRGameIdentifier"];
        NSURL *contents = [[bundle.bundleURL URLByDeletingLastPathComponent] URLByDeletingLastPathComponent];
        NSURL *resources = [contents URLByAppendingPathComponent:@"Resources"];
        NSFileManager *files = NSFileManager.defaultManager;
        NSURL *support = [files URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
        NSURL *data = [support URLByAppendingPathComponent:[@"MinotaurProjectRemastered for Apple/GameData" stringByAppendingPathComponent:game]];
        NSURL *seed = [resources URLByAppendingPathComponent:[@"Support/GameData" stringByAppendingPathComponent:game]];
        NSError *error = nil;
        if (![files fileExistsAtPath:data.path]) {
            [files createDirectoryAtURL:[data URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
            if (!error) [files copyItemAtURL:seed toURL:data error:&error];
        }
        if (error) {
            [NSApplication sharedApplication];
            [[NSAlert alertWithError:error] runModal];
            return 1;
        }
        if ([game isEqualToString:@"GoatUp"]) {
            const char *choice=getenv("MPR_GOAT_GAMEPAD");
            BOOL gamepad=!choice || strcmp(choice,"0")!=0;
            if (!MPRConfigureGoatControls(data,resources,gamepad,&error)) {
                [NSApplication sharedApplication];[[NSAlert alertWithError:error] runModal];return 1;
            }
        }
        NSURL *runtime = [resources URLByAppendingPathComponent:@"Support/Runtime"];
        NSURL *engine = [bundle.bundleURL URLByAppendingPathComponent:@"Contents/MacOS/GridrunnerAOT"];
        setenv("MPR_RESOURCE_DIR", runtime.path.fileSystemRepresentation, 1);
        setenv("MPR_DATA_DIR", data.path.fileSystemRepresentation, 1);
        argv[0] = (char *)engine.path.fileSystemRepresentation;
        execv(argv[0], argv);
        perror("Could not start game");
        return 1;
    }
}
