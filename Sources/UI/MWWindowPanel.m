// SPDX-License-Identifier: Apache-2.0
#import "MWWindowPanel.h"
#import "MWWindowView.h"

@interface MWPanelRow : UIView
- (instancetype)initWithWindow:(MWWindowView *)window panel:(MWWindowPanel *)panel;
- (void)updateWindow:(MWWindowView *)window;
@end
@implementation MWPanelRow {
    UIButton *_main, *_options;
    UIButton *_minimize, *_fullscreen, *_park;
    UIStackView *_actions;
    __weak MWWindowPanel *_panel;
    NSString *_bundle;
}
- (instancetype)initWithWindow:(MWWindowView *)window panel:(MWWindowPanel *)panel {
    if((self=[super initWithFrame:CGRectZero])) {
        self.backgroundColor=MWGlassRowColor(); self.layer.cornerRadius=16;
        self.layer.cornerCurve=kCACornerCurveContinuous;
        self.layer.borderWidth=0.5; self.layer.borderColor=MWGlassBorderColor(self.traitCollection,NO).CGColor;
        _main=[UIButton buttonWithType:UIButtonTypeSystem];
        _main.titleLabel.numberOfLines=2; _main.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        _main.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft; _main.contentEdgeInsets=UIEdgeInsetsMake(8,12,8,12);
        [self addSubview:_main];
        NSString *bundle=[window.application.bundleIdentifier copy]; __weak MWWindowPanel *weakPanel=panel;
        _bundle=bundle; _panel=panel;
        [_main addAction:[UIAction actionWithHandler:^(__kindof UIAction *action){ (void)action; if(weakPanel.activateHandler) weakPanel.activateHandler(bundle); }] forControlEvents:UIControlEventTouchUpInside];
        _options=[UIButton buttonWithType:UIButtonTypeSystem];
        [_options setImage:[UIImage systemImageNamed:@"ellipsis.circle"] forState:UIControlStateNormal];
        _options.accessibilityLabel=@"显示兼容选项";
        _options.showsMenuAsPrimaryAction=YES; [self addSubview:_options];
        _minimize=[self action:@"minus" label:@"最小化到面板" handler:^{if(weakPanel.minimizeHandler) weakPanel.minimizeHandler(bundle);}];
        _fullscreen=[self action:@"arrow.up.left.and.arrow.down.right" label:@"铺满屏幕" handler:^{if(weakPanel.fullscreenHandler) weakPanel.fullscreenHandler(bundle);}];
        UIButton *close=[self action:@"xmark" label:@"关闭窗口" handler:^{if(weakPanel.closeHandler) weakPanel.closeHandler(bundle);}];
        _park=[self action:@"pip.enter" label:@"挂起到右上角" handler:^{if(weakPanel.parkHandler) weakPanel.parkHandler(bundle);}];
        _park.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        _park.accessibilityIdentifier=@"harugalaxy.panel.park";
        close.tintColor=UIColor.systemRedColor;
        _actions=[[UIStackView alloc] initWithArrangedSubviews:@[_minimize,_fullscreen,_park,close]];
        _actions.axis=UILayoutConstraintAxisHorizontal; _actions.distribution=UIStackViewDistributionFillEqually;
        [self addSubview:_actions];
        [self updateWindow:window];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshRowAppearance) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshRowAppearance) name:UIAccessibilityDarkerSystemColorsStatusDidChangeNotification object:nil];
    }
    return self;
}
- (void)updateWindow:(MWWindowView *)window {
    BOOL minimized=window.model.state==MWWindowMinimized;
    NSString *status=window.isParked ? @"已挂起 · 点按还原" : (minimized ? @"已收纳 · 点按恢复" :
        (window.model.state==MWWindowLoading ? @"启动中" : (window.model.state==MWWindowFailed ? @"启动失败 · 点按查看" :
        (window.compatibleCanvas ? @"兼容显示" : (window.model.maximized ? @"全屏" : @"窗口")))));
    [_main setTitle:[NSString stringWithFormat:@"%@\n%@",window.application.name,status] forState:UIControlStateNormal];
    [_minimize setImage:[UIImage systemImageNamed:minimized ? @"arrow.up.forward.app" : @"minus"] forState:UIControlStateNormal];
    _minimize.accessibilityLabel=minimized ? @"恢复窗口" : @"最小化到面板";
    [_fullscreen setImage:[UIImage systemImageNamed:window.model.maximized ? @"arrow.down.right.and.arrow.up.left" : @"arrow.up.left.and.arrow.down.right"] forState:UIControlStateNormal];
    _fullscreen.accessibilityLabel=window.model.maximized ? @"还原窗口" : @"铺满屏幕";
    _minimize.enabled=window.model.state==MWWindowVisible || minimized || window.isParked;
    _fullscreen.enabled=_minimize.enabled;
    _park.enabled=window.model.state==MWWindowVisible || window.isParked;
    [_park setImage:nil forState:UIControlStateNormal];
    [_park setTitle:window.isParked ? @"还原" : @"挂起" forState:UIControlStateNormal];
    _park.accessibilityLabel=window.isParked ? @"还原挂起窗口" : @"挂起到右上角";
    NSString *bundle=_bundle; __weak MWWindowPanel *panel=_panel;
    UIAction *compatible=[UIAction actionWithTitle:@"兼容显示并重新打开" image:[UIImage systemImageNamed:@"rectangle.inset.filled"]
        identifier:nil handler:^(__kindof UIAction *action) {
            (void)action; if(panel.compatibleCanvasHandler) panel.compatibleCanvasHandler(bundle,YES);
        }];
    UIAction *normal=[UIAction actionWithTitle:@"普通显示并重新打开" image:[UIImage systemImageNamed:@"rectangle"]
        identifier:nil handler:^(__kindof UIAction *action) {
            (void)action; if(panel.compatibleCanvasHandler) panel.compatibleCanvasHandler(bundle,NO);
        }];
    compatible.state=window.compatibleCanvas ? UIMenuElementStateOn : UIMenuElementStateOff;
    normal.state=window.compatibleCanvas ? UIMenuElementStateOff : UIMenuElementStateOn;
    UIAction *original=[UIAction actionWithTitle:@"结束小窗并打开原应用" image:[UIImage systemImageNamed:@"arrow.up.forward.app"]
        identifier:nil handler:^(__kindof UIAction *action) {
            (void)action; if(panel.openOriginalHandler) panel.openOriginalHandler(bundle);
        }];
    UIAction *park=[UIAction actionWithTitle:window.isParked ? @"还原挂起窗口" : @"挂起到右上角" image:nil identifier:nil
        handler:^(__kindof UIAction *action){(void)action;if(panel.parkHandler) panel.parkHandler(bundle);}];
    if(!_park.enabled) park.attributes=UIMenuElementAttributesDisabled;
    _options.menu=[UIMenu menuWithTitle:@"窗口选项" children:@[park,compatible,normal,original]];
}
- (UIButton *)action:(NSString *)symbol label:(NSString *)label handler:(dispatch_block_t)handler {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal]; button.accessibilityLabel=label;
    [button addAction:[UIAction actionWithHandler:^(__kindof UIAction *action){(void)action;handler();}] forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (void)layoutSubviews {
    [super layoutSubviews]; _main.frame=CGRectMake(0,0,MAX(0,self.bounds.size.width-44),54);
    _options.frame=CGRectMake(MAX(0,self.bounds.size.width-44),5,44,44);
    _actions.frame=CGRectMake(0,54,self.bounds.size.width,44);
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous]; [self refreshRowAppearance];
}
- (void)refreshRowAppearance {
    self.backgroundColor=MWGlassRowColor();
    self.layer.borderColor=MWGlassBorderColor(self.traitCollection,NO).CGColor;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end

@implementation MWWindowPanel {
    UILabel *_title, *_hint, *_empty;
    UIButton *_open, *_settings, *_parkingSettings;
    UIScrollView *_scroll;
    NSArray<MWPanelRow *> *_rows;
    NSDictionary<NSString *,MWPanelRow *> *_rowsByBundle;
    NSArray *_lastSnapshot;
    NSUInteger _createdRowCount;
}
@synthesize createdRowCount=_createdRowCount;
- (instancetype)init {
    if((self=[super initWithCornerRadius:24])) {
        _title=[UILabel new]; _title.text=@"窗口面板"; _title.font=[UIFont systemFontOfSize:18 weight:UIFontWeightSemibold]; [self.contentView addSubview:_title];
        _hint=[UILabel new]; _hint.text=@"挂起保留缩略窗 · 更多选项见 …"; _hint.font=[UIFont systemFontOfSize:11]; _hint.textColor=UIColor.secondaryLabelColor; [self.contentView addSubview:_hint];
        _open=[UIButton buttonWithType:UIButtonTypeSystem]; [_open setTitle:@"＋ 打开应用" forState:UIControlStateNormal];
        [_open addTarget:self action:@selector(openApplication) forControlEvents:UIControlEventTouchUpInside]; [self.contentView addSubview:_open];
        _parkingSettings=[UIButton buttonWithType:UIButtonTypeSystem];
        [_parkingSettings setTitle:@"挂起设置" forState:UIControlStateNormal];
        _parkingSettings.accessibilityIdentifier=@"harugalaxy.panel.parkingSettings";
        [_parkingSettings addTarget:self action:@selector(parkingSettings) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_parkingSettings];
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
- (void)parkingSettings { if(self.parkingSettingsHandler) self.parkingSettingsHandler(); }
- (void)updateWindows:(NSArray<MWWindowView *> *)windows {
    NSMutableArray *snapshot=[NSMutableArray arrayWithCapacity:windows.count];
    for(MWWindowView *window in windows) [snapshot addObject:@[
        window.application.bundleIdentifier,window.application.name ?: @"",@(window.model.state),@(window.model.maximized),@(window.compatibleCanvas)]];
    if([snapshot isEqual:_lastSnapshot]) return;
    NSMutableArray *rows=[NSMutableArray array];
    NSMutableDictionary *byBundle=[NSMutableDictionary dictionaryWithCapacity:windows.count];
    for(MWWindowView *window in windows) {
        NSString *bundle=window.application.bundleIdentifier;
        MWPanelRow *row=_rowsByBundle[bundle];
        if(!row) { row=[[MWPanelRow alloc] initWithWindow:window panel:self]; [_scroll addSubview:row]; _createdRowCount++; }
        else [row updateWindow:window];
        [rows addObject:row]; byBundle[bundle]=row;
    }
    for(NSString *bundle in _rowsByBundle) if(!byBundle[bundle]) [_rowsByBundle[bundle] removeFromSuperview];
    _rows=rows; _rowsByBundle=byBundle; _lastSnapshot=[snapshot copy];
    _empty.hidden=rows.count!=0; [self setNeedsLayout];
}
- (void)placeNearAnchor:(CGRect)anchor inBounds:(CGRect)bounds {
    MWRect rect=MWPanelPlacementRect((MWRect){bounds.origin.x,bounds.origin.y,bounds.size.width,bounds.size.height},
        (MWRect){anchor.origin.x,anchor.origin.y,anchor.size.width,anchor.size.height},MAX(220,118+_rows.count*108));
    CGRect next=CGRectMake(rect.x,rect.y,rect.width,rect.height);
    if(!CGRectEqualToRect(next,self.frame)) self.frame=next;
}
- (void)layoutSubviews {
    [super layoutSubviews]; CGFloat width=self.bounds.size.width;
    BOOL compact=self.bounds.size.height<228;
    _title.frame=CGRectMake(16,compact ? 8 : 14,width-72,26);
    _settings.frame=CGRectMake(width-56,compact ? 0 : 8,44,44);
    _hint.hidden=compact;
    _hint.frame=CGRectMake(16,43,width-32,18);
    _open.frame=CGRectMake(12,compact ? 42 : 68,(width-24)/2,44);
    _parkingSettings.frame=CGRectMake(CGRectGetMaxX(_open.frame),compact ? 42 : 68,(width-24)/2,44);
    _scroll.frame=CGRectMake(12,compact ? 90 : 118,width-24,MAX(1,self.bounds.size.height-(compact ? 102 : 130)));
    CGFloat y=0;
    for(MWPanelRow *row in _rows) { row.frame=CGRectMake(0,y,_scroll.bounds.size.width,98); y+=108; }
    _scroll.contentSize=CGSizeMake(_scroll.bounds.size.width,y);
    _empty.frame=_scroll.bounds;
}
@end
