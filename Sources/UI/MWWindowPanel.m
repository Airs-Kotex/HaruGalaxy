// SPDX-License-Identifier: Apache-2.0
#import "MWWindowPanel.h"
#import "MWWindowView.h"

@interface MWPanelRow : UIView
- (instancetype)initWithWindow:(MWWindowView *)window panel:(MWWindowPanel *)panel;
@end
@implementation MWPanelRow {
    UIButton *_main;
    UIStackView *_actions;
}
- (instancetype)initWithWindow:(MWWindowView *)window panel:(MWWindowPanel *)panel {
    if((self=[super initWithFrame:CGRectZero])) {
        self.backgroundColor=UIColor.tertiarySystemBackgroundColor; self.layer.cornerRadius=12;
        _main=[UIButton buttonWithType:UIButtonTypeSystem];
        NSString *status=window.model.state==MWWindowMinimized ? @"已收纳 · 点按恢复" :
            (window.model.state==MWWindowLoading ? @"启动中" : (window.model.state==MWWindowFailed ? @"启动失败 · 点按查看" : (window.model.maximized ? @"全屏" : @"窗口")));
        [_main setTitle:[NSString stringWithFormat:@"%@\n%@",window.application.name,status] forState:UIControlStateNormal];
        _main.titleLabel.numberOfLines=2; _main.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        _main.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft; _main.contentEdgeInsets=UIEdgeInsetsMake(8,12,8,12);
        [self addSubview:_main];
        NSString *bundle=[window.application.bundleIdentifier copy]; __weak MWWindowPanel *weakPanel=panel;
        [_main addAction:[UIAction actionWithHandler:^(__kindof UIAction *action){ (void)action; if(weakPanel.activateHandler) weakPanel.activateHandler(bundle); }] forControlEvents:UIControlEventTouchUpInside];
        UIButton *minimize=[self action:window.model.state==MWWindowMinimized ? @"arrow.up.forward.app" : @"minus" label:window.model.state==MWWindowMinimized ? @"恢复窗口" : @"最小化到面板" handler:^{if(weakPanel.minimizeHandler) weakPanel.minimizeHandler(bundle);}];
        UIButton *fullscreen=[self action:window.model.maximized ? @"arrow.down.right.and.arrow.up.left" : @"arrow.up.left.and.arrow.down.right" label:window.model.maximized ? @"还原窗口" : @"铺满屏幕" handler:^{if(weakPanel.fullscreenHandler) weakPanel.fullscreenHandler(bundle);}];
        UIButton *close=[self action:@"xmark" label:@"关闭窗口" handler:^{if(weakPanel.closeHandler) weakPanel.closeHandler(bundle);}];
        close.tintColor=UIColor.systemRedColor;
        minimize.enabled=window.model.state==MWWindowVisible || window.model.state==MWWindowMinimized;
        fullscreen.enabled=minimize.enabled;
        _actions=[[UIStackView alloc] initWithArrangedSubviews:@[minimize,fullscreen,close]];
        _actions.axis=UILayoutConstraintAxisHorizontal; _actions.distribution=UIStackViewDistributionFillEqually;
        [self addSubview:_actions];
    }
    return self;
}
- (UIButton *)action:(NSString *)symbol label:(NSString *)label handler:(dispatch_block_t)handler {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal]; button.accessibilityLabel=label;
    [button addAction:[UIAction actionWithHandler:^(__kindof UIAction *action){(void)action;handler();}] forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (void)layoutSubviews {
    [super layoutSubviews]; _main.frame=CGRectMake(0,0,self.bounds.size.width,54);
    _actions.frame=CGRectMake(0,54,self.bounds.size.width,44);
}
@end

@implementation MWWindowPanel {
    UILabel *_title, *_hint, *_empty;
    UIButton *_open, *_settings;
    UIScrollView *_scroll;
    NSArray<MWPanelRow *> *_rows;
}
- (instancetype)init {
    if((self=[super initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]])) {
        self.layer.cornerRadius=20; self.layer.cornerCurve=kCACornerCurveContinuous; self.clipsToBounds=YES;
        _title=[UILabel new]; _title.text=@"窗口面板"; _title.font=[UIFont systemFontOfSize:18 weight:UIFontWeightBold]; [self.contentView addSubview:_title];
        _hint=[UILabel new]; _hint.text=@"收纳后不占底部 · 轻点窗口恢复"; _hint.font=[UIFont systemFontOfSize:11]; _hint.textColor=UIColor.secondaryLabelColor; [self.contentView addSubview:_hint];
        _open=[UIButton buttonWithType:UIButtonTypeSystem]; [_open setTitle:@"＋ 打开应用" forState:UIControlStateNormal];
        [_open addTarget:self action:@selector(openApplication) forControlEvents:UIControlEventTouchUpInside]; [self.contentView addSubview:_open];
        _settings=[UIButton buttonWithType:UIButtonTypeSystem]; [_settings setImage:[UIImage systemImageNamed:@"slider.horizontal.3"] forState:UIControlStateNormal];
        _settings.accessibilityLabel=@"设置"; [_settings addTarget:self action:@selector(settings) forControlEvents:UIControlEventTouchUpInside]; [self.contentView addSubview:_settings];
        _scroll=[UIScrollView new]; [self.contentView addSubview:_scroll];
        _empty=[UILabel new]; _empty.text=@"暂无窗口\n点“打开应用”开始"; _empty.numberOfLines=2;
        _empty.textAlignment=NSTextAlignmentCenter; _empty.textColor=UIColor.secondaryLabelColor; _empty.font=[UIFont systemFontOfSize:14]; [_scroll addSubview:_empty];
        self.accessibilityViewIsModal=YES;
    }
    return self;
}
- (void)openApplication { if(self.openApplicationHandler) self.openApplicationHandler(); }
- (void)settings { if(self.settingsHandler) self.settingsHandler(); }
- (void)updateWindows:(NSArray<MWWindowView *> *)windows {
    for(UIView *row in _rows) [row removeFromSuperview];
    NSMutableArray *rows=[NSMutableArray array];
    for(MWWindowView *window in windows) { MWPanelRow *row=[[MWPanelRow alloc] initWithWindow:window panel:self]; [_scroll addSubview:row]; [rows addObject:row]; }
    _rows=rows; _empty.hidden=rows.count!=0; [self setNeedsLayout];
}
- (void)placeNearAnchor:(CGRect)anchor inBounds:(CGRect)bounds {
    CGFloat width=MIN(304,MAX(1,bounds.size.width-16)),height=MIN(MAX(220,118+_rows.count*108),MAX(1,bounds.size.height-16));
    BOOL right=CGRectGetMidX(anchor)>CGRectGetMidX(bounds);
    CGFloat x=right ? CGRectGetMinX(anchor)-width-8 : CGRectGetMaxX(anchor)+8;
    x=MAX(bounds.origin.x+8,MIN(x,CGRectGetMaxX(bounds)-width-8));
    CGFloat y=MAX(bounds.origin.y+8,MIN(CGRectGetMidY(anchor)-height/2,CGRectGetMaxY(bounds)-height-8));
    self.frame=CGRectMake(x,y,width,height);
}
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat width=self.bounds.size.width;
    _title.frame=CGRectMake(16,14,width-72,26); _settings.frame=CGRectMake(width-56,8,44,44);
    _hint.frame=CGRectMake(16,43,width-32,18);
    _open.frame=CGRectMake(12,68,width-24,44);
    _scroll.frame=CGRectMake(12,118,width-24,MAX(1,self.bounds.size.height-130));
    CGFloat y=0;
    for(MWPanelRow *row in _rows) { row.frame=CGRectMake(0,y,_scroll.bounds.size.width,98); y+=108; }
    _scroll.contentSize=CGSizeMake(_scroll.bounds.size.width,y);
    _empty.frame=_scroll.bounds;
}
@end
