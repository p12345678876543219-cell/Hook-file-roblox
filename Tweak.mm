#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Khai báo biến giao diện toàn cục
static UIWindow *overlayWindow = nil;
static UIButton *floatingBtn = nil;
static UIView *menuView = nil;
static UILabel *infoLabel = nil;
static BOOL isMenuOpen = NO;

// Khai báo trước các hàm xử lý
void toggleMenu(void);
void updateProfileInfo(void);

// Xử lý kéo thả và sự kiện nút bấm
@interface ButtonHandler : NSObject
+ (void)btnTapped;
+ (void)panDetected:(UIPanGestureRecognizer *)gesture;
@end

@implementation ButtonHandler
+ (void)btnTapped {
    toggleMenu();
}
+ (void)panDetected:(UIPanGestureRecognizer *)gesture {
    UIView *btn = gesture.view;
    CGPoint translation = [gesture translationInView:btn.superview];
    CGPoint newCenter = CGPointMake(btn.center.x + translation.x, btn.center.y + translation.y);
    btn.center = newCenter;
    [gesture setTranslation:CGPointZero inView:btn.superview];
}
@end

// Hàm lấy thông tin (Giả lập qua cơ chế Roblox Client)
NSString *getRobloxUsername(void) {
    return @"Player_Roblox123"; 
}

NSString *getAccountAgeAndCreation(void) {
    return @"Ngày tạo: 15/05/2023\nTuổi thọ: 3 năm 5 tháng";
}

NSString *getCurrentGameName(void) {
    return @"Blox Fruits / Sea 2";
}

// Hàm cập nhật nội dung thông tin lên Menu
void updateProfileInfo(void) {
    if (!infoLabel) return;
    
    NSString *name = getRobloxUsername();
    NSString *ageInfo = getAccountAgeAndCreation();
    NSString *game = getCurrentGameName();
    
    infoLabel.text = [NSString stringWithFormat:@"👤 Tên: %@\n\n📅 %@\n\n🎮 Đang chơi:\n%@", name, ageInfo, game];
}

// Xử lý sự kiện bấm nút mở/đóng Menu
void toggleMenu(void) {
    isMenuOpen = !isMenuOpen;
    menuView.hidden = !isMenuOpen;
    if (isMenuOpen) {
        updateProfileInfo();
        [menuView.superview bringSubviewToFront:menuView];
    }
}

// Khởi tạo giao diện Menu nổi
void setupFloatingMenu(void) {
    if (overlayWindow) return;
    
    // Tạo UIWindow riêng nằm đè lên game
    UIWindowScene *scene = (UIWindowScene *)[[UIApplication sharedApplication].connectedScenes anyObject];
    if (scene) {
        overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
    } else {
        overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    
    overlayWindow.windowLevel = UIWindowLevelAlert + 999;
    overlayWindow.backgroundColor = [UIColor clearColor];
    overlayWindow.hidden = NO;
    
    // View chứa phần tử giao diện
    UIView *rootView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    rootView.userInteractionEnabled = NO;
    overlayWindow.rootViewController = [UIViewController new];
    [overlayWindow.rootViewController.view addSubview:rootView];

    // 1. Nút Bật/Tắt Menu (Floating Button) nổi trên màn hình
    floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    floatingBtn.frame = CGRectMake(20, 100, 50, 50);
    floatingBtn.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.8];
    [floatingBtn setTitle:@"🪝" forState:UIControlStateNormal];
    floatingBtn.layer.cornerRadius = 25;
    floatingBtn.layer.borderWidth = 1.5;
    floatingBtn.layer.borderColor = [UIColor cyanColor].CGColor;
    floatingBtn.userInteractionEnabled = YES;
    
    [floatingBtn addTarget:[ButtonHandler class] action:@selector(btnTapped) forControlEvents:UIControlEventTouchUpInside];
    
    // Thêm cử chỉ kéo thả (Pan Gesture) cho nút nổi
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[ButtonHandler class] action:@selector(panDetected:)];
    [floatingBtn addGestureRecognizer:pan];
    
    [rootView addSubview:floatingBtn];

    // 2. Bảng Menu chính
    menuView = [[UIView alloc] initWithFrame:CGRectMake(80, 100, 260, 240)];
    menuView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:0.95];
    menuView.layer.cornerRadius = 14;
    menuView.layer.borderWidth = 1;
    menuView.layer.borderColor = [UIColor systemIndigoColor].CGColor;
    menuView.hidden = YES;
    menuView.userInteractionEnabled = YES;
    
    // Tiêu đề Menu
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, 230, 30)];
    titleLabel.text = @"🚀 Roblox Profile Menu";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [menuView addSubview:titleLabel];
    
    // Label hiển thị thông tin chi tiết
    infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 50, 230, 170)];
    infoLabel.textColor = [UIColor lightGrayColor];
    infoLabel.font = [UIFont systemFontOfSize:13];
    infoLabel.numberOfLines = 0;
    [menuView addSubview:infoLabel];
    
    [rootView addSubview:menuView];
}

// Hook vào chu trình chạy để khởi tạo menu sau khi game load
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupFloatingMenu();
    });
}
