#import "InfoViewController.h"

@interface InfoViewController ()
@property(nonatomic,strong) UISegmentedControl *sectionsControl;
@property(nonatomic, copy) NSArray<NSArray<NSDictionary<NSString *, NSString *> *> *> *controls;
@property(nonatomic, copy) NSArray<NSArray<NSDictionary<NSString *, NSString *> *> *> *credits;
@end

@implementation InfoViewController

- (instancetype)initShowingCredits:(BOOL)showCredits {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (!self) return nil;

    self.title = @"Minotaur Project";
    self.sectionsControl = [[UISegmentedControl alloc] initWithItems:@[@"About", @"Joystick"]];
    self.sectionsControl.selectedSegmentIndex = showCredits ? 0 : 1;
    [self.sectionsControl addTarget:self action:@selector(changeSection) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.sectionsControl;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];

    self.controls = @[
        @[
            @{@"title": @"Connect your controller first",
              @"detail": @"Pair your controller in Settings before opening a game. If you connect during play, return to the picker and reopen the game. Games open with touch controls when no controller is connected. Button names use the Xbox layout."}
        ],
        @[
            @{@"title": @"Gridrunner",
              @"detail": @"Left stick moves. A selects or starts, Start pauses, and the right shoulder button cycles orientations."},
            @{@"title": @"Super Ox Wars",
              @"detail": @"Left stick moves, A starts, and Start pauses."},
            @{@"title": @"Minotron: 2112",
              @"detail": @"Left stick moves and right stick aims. In menus, move the pointer with the left stick and press A to select. Start pauses."},
            @{@"title": @"Minotaur Rescue",
              @"detail": @"Left stick steers. In menus, move the pointer with the left stick and press A to select. Start plays or pauses."},
            @{@"title": @"Five A Day",
              @"detail": @"Left stick moves, A starts, and Start pauses."},
            @{@"title": @"Deflex",
              @"detail": @"D-pad or stick left and right operate the paddles. A selects, X plays, and Start pauses."},
            @{@"title": @"Caverns of Minos",
              @"detail": @"Left stick steers and right stick tilts. A or right trigger thrusts, and Start pauses."},
            @{@"title": @"GoatUp",
              @"detail": @"Select Control Type C in the game for stick movement. Left stick or D-pad moves, A jumps, and Start pauses."},
            @{@"title": @"GoatUp 2",
              @"detail": @"Select tilt mode in the game. Left stick tilts, A jumps, and Start pauses. X changes the control mode while paused."}
        ]
    ];
    self.credits = @[
        @[
            @{@"title": @"Llamasoft",
              @"detail": @"Original games by Jeff Minter and Ivan Zorzin. Games and artwork © Llamasoft and their respective owners.",
              @"url": @"https://store.steampowered.com/search/?developer=Llamasoft+Ltd."}
        ],
        @[
            @{@"title": @"Minotaur Project Remastered",
              @"detail": @"The Windows collection, controller mappings and runtime fork by jedeyesniv-art.",
              @"url": @"https://github.com/jedeyesniv-art/MinotaurProjectRemastered"},
            @{@"title": @"Minotaur Project Remastered for Apple",
              @"detail": @"An unofficial fan adaptation for Mac, iPhone and iPad, developed with Codex assistance."}
        ],
        @[
            @{@"title": @"touchHLE",
              @"detail": @"Compatibility runtime by hikari_no_yume and contributors.",
              @"url": @"https://github.com/touchHLE/touchHLE"},
            @{@"title": @"Dynarmic",
              @"detail": @"Tools for translating and checking the original ARM code.",
              @"url": @"https://github.com/touchHLE/dynarmic"},
            @{@"title": @"SDL",
              @"detail": @"Windowing and controller input.",
              @"url": @"https://github.com/libsdl-org/SDL"}
        ]
    ];
    return self;
}

- (BOOL)showingCredits {
    return self.sectionsControl.selectedSegmentIndex == 0;
}

- (NSArray<NSArray<NSDictionary<NSString *, NSString *> *> *> *)sections {
    return self.showingCredits ? self.credits : self.controls;
}

- (void)changeSection {
    [self.tableView reloadData];
    [self.tableView setContentOffset:CGPointMake(0, -self.tableView.adjustedContentInset.top) animated:NO];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.sections[section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSArray<NSString *> *titles = self.showingCredits
        ? @[@"Original games", @"Remastered collection", @"Open source"]
        : @[@"Setup", @"Game mappings"];
    return titles[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"InfoRow"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"InfoRow"];

    NSDictionary<NSString *, NSString *> *row = self.sections[indexPath.section][indexPath.row];
    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.text = row[@"title"];
    content.secondaryText = row[@"detail"];
    content.textProperties.numberOfLines = 0;
    content.secondaryTextProperties.numberOfLines = 0;
    cell.contentConfiguration = content;
    BOOL hasLink = row[@"url"] != nil;
    cell.accessoryType = hasLink ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = hasLink ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    cell.accessibilityTraits = hasLink ? UIAccessibilityTraitLink : UIAccessibilityTraitNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *link = self.sections[indexPath.section][indexPath.row][@"url"];
    if (link) [UIApplication.sharedApplication openURL:[NSURL URLWithString:link] options:@{} completionHandler:nil];
}

@end
