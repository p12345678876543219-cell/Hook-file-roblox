#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <mach/mach.h>
#import <dlfcn.h>

@interface RobloxMenuManager : NSObject
+ (instancetype)sharedInstance;
- (void)setupMenu;
@end

@implementation RobloxMenuManager {
    UIWindow *menuWindow;
    UIButton *toggleButton;
    UIView *menuView;
    
    UILabel *fpsLabel;
    UILabel *nameLabel;
    UILabel *gameLabel;
    UILabel *createdLabel;
    UILabel *ageLabel;
    
    CADisplayLink *displayLink;
    CFTimeInterval lastTime;
    int frameCount;
}

+ (instancetype)sharedInstance {
    static RobloxMenuManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[RobloxMenuManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        if ([NSThread isMainThread]) {
            [self setupMenu];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setupMenu];
            });
        }
    }
    return self;
}

- (void)setupMenu {
    // Đảm bảo không tạo trùng window nếu đã khởi tạo trước đó
    if (menuWindow) return;

    UIWindowScene *scene = nil;
    for (UIWindowScene *s in [UIApplication sharedApplication].connectedScenes) {
        if (s.activationState == UISceneActivationStateForegroundActive) {
            scene = s;
            break;
        }
    }
    
    if (scene) {
        menuWindow = [[UIWindow alloc] initWithWindowScene:scene];
    } else {
        menuWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    
    menuWindow.windowLevel = UIWindowLevelAlert + 999;
    menuWindow.backgroundColor = [UIColor clearColor];
    menuWindow.hidden = NO;
    
    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    menuWindow.rootViewController = rootVC;
    
    // --- 1. NÚT BẬT/TẮT MENU (FLOATING TOGGLE BUTTON) ---
    toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    toggleButton.frame = CGRectMake(30, 140, 48, 48);
    toggleButton.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.18 alpha:0.90];
    [toggleButton setTitle:@"🛡️" forState:UIControlStateNormal];
    toggleButton.titleLabel.font = [UIFont systemFontOfSize:24];
    toggleButton.layer.cornerRadius = 24.0;
    toggleButton.layer.borderWidth = 1.5;
    toggleButton.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:1.0].CGColor;
    toggleButton.layer.shadowColor = [UIColor blackColor].CGColor;
    toggleButton.layer.shadowOffset = CGSizeMake(0, 3);
    toggleButton.layer.shadowOpacity = 0.4;
    toggleButton.layer.shadowRadius = 4.0;
    
    [toggleButton addTarget:self action:@selector(toggleMenu:) forControlEvents:UIControlEventTouchUpInside];
    
    // Thêm gesture kéo thả mượt mà cho nút toggle
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragButton:)];
    [toggleButton addGestureRecognizer:pan];
    [rootVC.view addSubview:toggleButton];
    
    // --- 2. KHUNG MENU CHÍNH ---
    menuView = [[UIView alloc] initWithFrame:CGRectMake(90, 140, 255, 235)];
    menuView.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.10 alpha:0.95];
    menuView.layer.cornerRadius = 16;
    menuView.layer.borderWidth = 1.2;
    menuView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.6 blue:1.0 alpha:0.85].CGColor;
    menuView.layer.shadowColor = [UIColor blackColor].CGColor;
    menuView.layer.shadowOffset = CGSizeMake(0, 4);
    menuView.layer.shadowOpacity = 0.5;
    menuView.layer.shadowRadius = 6.0;
    menuView.hidden = YES; // Mặc định ẩn khi khởi động
    
    // Tiêu đề Menu
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 12, 225, 22)];
    titleLabel.text = @"ROBLOX INFO HUD";
    titleLabel.textColor = [UIColor colorWithRed:0.2 green:0.9 blue:1.0 alpha:1.0];
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [menuView addSubview:titleLabel];
    
    // Đường kẻ ngang phân cách
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(15, 39, 225, 1)];
    line.backgroundColor = [UIColor colorWithWhite:0.35 alpha:1.0];
    [menuView addSubview:line];
    
    // Khởi tạo các nhãn thông tin chi tiết
    CGFloat startY = 46;
    CGFloat h = 31;
    
    fpsLabel = [self createLabelWithFrame:CGRectMake(15, startY, 225, h) text:@"FPS: Đang tính..."];
    nameLabel = [self createLabelWithFrame:CGRectMake(15, startY + h, 225, h) text:@"Tên: Đang tải..."];
    gameLabel = [self createLabelWithFrame:CGRectMake(15, startY + h * 2, 225, h) text:@"Game ID: Đang tải..."];
    createdLabel = [self createLabelWithFrame:CGRectMake(15, startY + h * 3, 225, h) text:@"Ngày tạo: Đang tải..."];
    ageLabel = [self createLabelWithFrame:CGRectMake(15, startY + h * 4, 225, h) text:@"Tuổi thọ: Đang tính..."];
    
    [menuView addSubview:fpsLabel];
    [menuView addSubview:nameLabel];
    [menuView addSubview:gameLabel];
    [menuView addSubview:createdLabel];
    [menuView addSubview:ageLabel];
    
    [rootVC.view addSubview:menuView];
    
    // --- 3. BỘ ĐO FPS & TIMER CẬP NHẬT ---
    displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFPS:)];
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    // Timer cập nhật thông tin tài khoản mỗi 2 giây
    [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(updatePlayerStats) userInfo:nil repeats:YES];
}

- (UILabel *)createLabelWithFrame:(CGRect)frame text:(NSString *)text {
    UILabel *lbl = [[UILabel alloc] initWithFrame:frame];
    lbl.text = text;
    lbl.textColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    lbl.font = [UIFont fontWithName:@"Helvetica-Bold" size:12] ?: [UIFont systemFontOfSize:12];
    return lbl;
}

- (void)toggleMenu:(UIButton *)sender {
    menuView.hidden = !menuView.hidden;
}

- (void)dragButton:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:menuWindow];
    CGPoint center = pan.view.center;
    
    CGFloat newX = center.x + translation.x;
    CGFloat newY = center.y + translation.y;
    
    // Giới hạn nút không bị kéo ra ngoài màn hình
    CGSize screenBounds = [UIScreen mainScreen].bounds.size;
    newX = MAX(30, MIN(screenBounds.width - 30, newX));
    newY = MAX(40, MIN(screenBounds.height - 40, newY));
    
    pan.view.center = CGPointMake(newX, newY);
    [pan setTranslation:CGPointZero inView:menuWindow];
    
    // Giữ menu đi kèm vị trí nút toggle
    if (!menuView.hidden) {
        CGFloat menuX = newX + 60;
        if (menuX + 255 > screenBounds.width) {
            menuX = newX - 270; // Tự động dịch menu sang trái nếu chạm mép phải màn hình
        }
        menuView.center = CGPointMake(menuX + 127.5, newY);
    }
}

- (void)updateFPS:(CADisplayLink *)link {
    if (lastTime == 0) {
        lastTime = link.timestamp;
        return;
    }
    frameCount++;
    CFTimeInterval elapsed = link.timestamp - lastTime;
    if (elapsed >= 1.0) {
        int fps = (int)(frameCount / elapsed);
        
        // Đổi màu chữ FPS theo mức độ mượt mà
        UIColor *fpsColor = [UIColor greenColor];
        if (fps < 30) fpsColor = [UIColor redColor];
        else if (fps < 50) fpsColor = [UIColor orangeColor];
        
        fpsLabel.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"FPS: %d", fps]
                                                                  attributes:@{NSForegroundColorAttributeName: fpsColor}];
        frameCount = 0;
        lastTime = link.timestamp;
    }
}

- (void)updatePlayerStats {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Trích xuất thông tin thực tế từ môi trường Roblox / Executor Runtime
        NSString *playerName = [self fetchLuauString:@"local p = game.Players.LocalPlayer; return p and p.Name or 'Guest'"];
        NSUInteger placeId = (NSUInteger)[self fetchLuauNumber:@"return game.PlaceId"];
        NSInteger accountAgeDays = (NSInteger)[self fetchLuauNumber:@"local p = game.Players.LocalPlayer; return p and p.AccountAge or 0"];
        
        // Nếu chưa kết nối được engine hoặc đang ở sảnh chờ, dùng dữ liệu an toàn mặc định
        if (!playerName || playerName.length == 0) {
            playerName = @"RobloxPlayer";
        }
        
        // Tính toán thời gian tạo tài khoản & tuổi thọ chi tiết
        int days = (int)accountAgeDays;
        
        // Lấy thời điểm hiện tại trừ đi số ngày tuổi thọ để ra ngày tạo chính xác
        NSDate *createdDate = [[NSDate date] dateByAddingTimeInterval:-(accountAgeDays * 24 * 3600)];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"dd/MM/yyyy"];
        NSString *createdString = [formatter stringFromDate:createdDate];
        
        // Tính số giờ phụ trội trong ngày hiện tại dựa trên Session time
        static NSDate *sessionStart = nil;
        if (!sessionStart) sessionStart = [NSDate date];
        int sessionHours = (int)([[NSDate date] timeIntervalSinceDate:sessionStart] / 3600);
        int totalHours = (days * 24) + sessionHours;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            nameLabel.text = [NSString stringWithFormat:@"Tên: %@", playerName];
            gameLabel.text = [NSString stringWithFormat:@"Game ID: %lu", (unsigned long)placeId];
            createdLabel.text = [NSString stringWithFormat:@"Ngày tạo: %@", createdString];
            ageLabel.text = [NSString stringWithFormat:@"Tuổi thọ: %d ngày (%d giờ)", days, totalHours];
        });
    });
}

// Hàm cầu nối giao tiếp với môi trường Luau an toàn
- (NSString *)fetchLuauString:(NSString *)script {
    // [Tích hợp Executor Bridge]: Nếu môi trường Delta hoặc dylib có hàm thực thi script,
    // gọi hàm evaluate Lua tại đây. Ví dụ trả về chuỗi kết quả thực tế từ engine:
    return nil; // Trả về nil để hệ thống tự xử lý fallback an toàn
}

- (double)fetchLuauNumber:(NSString *)script {
    // Trả về số thực thi từ engine Lua (PlaceId, AccountAge)
    return 0; 
}

@end

// Constructor tự động kích hoạt ngay khi tệp .dylib được inject thành công vào tiến trình Roblox
__attribute__((constructor)) static void initializeDylib() {
    @autoreleasepool {
        [[RobloxMenuManager sharedInstance] performSelectorOnMainThread:@selector(setupMenu) withObject:nil waitUntilDone:NO];
    }
}
