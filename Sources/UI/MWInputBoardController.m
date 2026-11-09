// SPDX-License-Identifier: Apache-2.0
#import "MWInputBoardController.h"
#import "../Platform/MWKeyboardFocus.h"
#import "../Diagnostics/MWDiagnostics.h"

@implementation MWInputBoardController {
    UITextView *_editor;
    UILabel *_hint;
    UIButton *_openOriginal;
    UIBarButtonItem *_copyItem, *_originalItem;
    BOOL _finished;
    NSUInteger _focusGeneration;
    CGFloat _keyboardOverlap;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title=self.applicationName.length ? [NSString stringWithFormat:@"输入 · %@",self.applicationName] : @"输入板";
    self.view.backgroundColor=UIColor.systemGroupedBackgroundColor;
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
        target:self action:@selector(cancel)];
    _copyItem=[[UIBarButtonItem alloc] initWithTitle:@"复制并返回" style:UIBarButtonItemStyleDone
        target:self action:@selector(copyAndReturn)];
    self.navigationItem.rightBarButtonItem=_copyItem;
    if(self.originalApplicationHandler) {
        _originalItem=[[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.up.forward.app"]
            style:UIBarButtonItemStylePlain target:self action:@selector(openOriginal)];
        _originalItem.accessibilityLabel=@"在原应用中输入";
    }
    _hint=[UILabel new]; _hint.numberOfLines=0; _hint.font=[UIFont systemFontOfSize:14];
    _hint.textColor=UIColor.secondaryLabelColor;
    _hint.text=@"在这里输入，复制后回到小窗文本框长按粘贴。\n复制仅保存在此设备，10 分钟后过期。";
    [self.view addSubview:_hint];
    _editor=[UITextView new]; _editor.font=[UIFont systemFontOfSize:19];
    _editor.backgroundColor=UIColor.secondarySystemGroupedBackgroundColor;
    _editor.textColor=UIColor.labelColor; _editor.layer.cornerRadius=14;
    _editor.textContainerInset=UIEdgeInsetsMake(14,12,14,12);
    _editor.accessibilityLabel=@"输入要复制的文字";
    _editor.accessibilityIdentifier=@"harugalaxy.input.board";
    [self.view addSubview:_editor];
    _openOriginal=[UIButton buttonWithType:UIButtonTypeSystem];
    [_openOriginal setTitle:@"在原应用中输入" forState:UIControlStateNormal];
    [_openOriginal addTarget:self action:@selector(openOriginal) forControlEvents:UIControlEventTouchUpInside];
    _openOriginal.hidden=!self.originalApplicationHandler; [self.view addSubview:_openOriginal];
    NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [center addObserver:self selector:@selector(keyboardHidden:) name:UIKeyboardWillHideNotification object:nil];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSUInteger generation=++_focusGeneration;
    __weak typeof(self) weakSelf=self;
    dispatch_async(dispatch_get_main_queue(),^{
        MWInputBoardController *board=weakSelf;
        if(!board || board->_finished || generation!=board->_focusGeneration || !board.viewIfLoaded.window) return;
        UIWindow *window=board.view.window; [window makeKeyWindow];
        [MWKeyboardFocus.shared focusHostWindow:window reason:@"input_board"];
        BOOL accepted=[board->_editor becomeFirstResponder];
        MWLog(@"input_board.focus",@{@"accepted":@(accepted),@"keyWindow":@(window.isKeyWindow)});
    });
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated]; _focusGeneration++;
    [self.viewIfLoaded endEditing:YES];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect bounds=self.view.bounds; UIEdgeInsets safe=self.view.safeAreaInsets;
    CGFloat left=safe.left+16,width=MAX(1,bounds.size.width-safe.left-safe.right-32);
    CGFloat top=safe.top+8;
    CGFloat bottom=MAX(top,bounds.size.height-MAX(safe.bottom,_keyboardOverlap)-8);
    BOOL compact=bottom-top<180;
    _hint.hidden=compact;
    _openOriginal.hidden=compact || !self.originalApplicationHandler;
    // In short landscape layouts the ordinary-App action moves into the
    // navigation bar, leaving the editor inside the area above the keyboard.
    NSUInteger itemCount=compact && _originalItem ? 2 : 1;
    if(self.navigationItem.rightBarButtonItems.count!=itemCount)
        self.navigationItem.rightBarButtonItems=itemCount==2 ? @[_copyItem,_originalItem] : @[_copyItem];
    CGSize hint=[_hint sizeThatFits:CGSizeMake(width,CGFLOAT_MAX)];
    _hint.frame=CGRectMake(left,top,width,compact ? 0 : hint.height);
    CGFloat extra=_openOriginal.hidden ? 0 : 44;
    CGFloat y=compact ? top : CGRectGetMaxY(_hint.frame)+12;
    _editor.frame=CGRectMake(left,y,width,MAX(0,bottom-y-extra));
    _openOriginal.frame=CGRectMake(left,CGRectGetMaxY(_editor.frame),width,extra);
}
- (void)keyboardChanged:(NSNotification *)notification {
    UIWindow *window=self.viewIfLoaded.window; if(!window || _finished) return;
    if([notification.object isKindOfClass:UIScreen.class] && notification.object!=window.screen) return;
    CGRect frame=[notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect local=[window.screen.coordinateSpace convertRect:frame toCoordinateSpace:self.view];
    CGRect overlap=CGRectIntersection(self.view.bounds,local);
    _keyboardOverlap=!CGRectIsNull(overlap) && CGRectGetMaxY(overlap)>=CGRectGetMaxY(self.view.bounds)-1 ? overlap.size.height : 0;
    [self.view setNeedsLayout];
    MWTrace(@"input_board.keyboard",@{@"overlap":@(_keyboardOverlap)});
}
- (void)keyboardHidden:(NSNotification *)notification {
    (void)notification; _keyboardOverlap=0; [self.viewIfLoaded setNeedsLayout];
}
- (void)invalidateInput {
    _finished=YES; _focusGeneration++;
    [self.viewIfLoaded endEditing:YES]; _editor.text=@"";
}
- (void)finishCopied:(BOOL)copied openOriginal:(BOOL)openOriginal {
    if(_finished) return;
    if(copied) {
        NSString *text=[_editor.text copy] ?: @"";
        if(!text.length) { [_editor becomeFirstResponder]; return; }
        // Clipboard is written only by this explicit user action; never read
        // another App's clipboard or persist the draft in files/defaults/logs.
        [UIPasteboard.generalPasteboard setItems:@[@{@"public.utf8-plain-text":text}]
            options:@{UIPasteboardOptionLocalOnly:@YES,
                      UIPasteboardOptionExpirationDate:[NSDate dateWithTimeIntervalSinceNow:600]}];
    }
    void (^completion)(BOOL)=self.completionHandler;
    dispatch_block_t original=self.originalApplicationHandler;
    [self invalidateInput];
    MWLog(@"input_board.finished",@{@"copied":@(copied),@"openOriginal":@(openOriginal)});
    UIViewController *container=self.navigationController ?: self;
    UIViewController *presenter=container.presentingViewController;
    dispatch_block_t done=^{if(openOriginal && original) original(); else if(completion) completion(copied);};
    if(presenter) [presenter dismissViewControllerAnimated:YES completion:done]; else done();
}
- (void)copyAndReturn { [self finishCopied:YES openOriginal:NO]; }
- (void)cancel { [self finishCopied:NO openOriginal:NO]; }
- (void)openOriginal { [self finishCopied:NO openOriginal:YES]; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end
