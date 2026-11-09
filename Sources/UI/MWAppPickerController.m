// SPDX-License-Identifier: Apache-2.0
#import "MWAppPickerController.h"
#import "MWPreferences.h"
#import "../Diagnostics/MWDiagnostics.h"
#import "../Platform/MWKeyboardFocus.h"

@interface MWAppPickerController () <UISearchBarDelegate, UIAdaptivePresentationControllerDelegate>
@end
@implementation MWAppPickerController {
    NSArray<MWApplication *> *_apps, *_filtered, *_recent;
    UISearchBar *_searchBar;
    UIView *_searchHeader;
    BOOL _keyboardVisible, _searchExpected, _finished, _levelChanged, _receivedInput, _fallbackStarted;
    NSUInteger _focusGeneration;
    UIWindowLevel _originalLevel;
    __weak UIWindow *_searchWindow;
    UIButton *_fallback;
}
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"打开应用小窗";
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(dismiss)];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadApplications)];
    // Keep input in this sheet: UISearchController creates another presentation
    // whose lifecycle can invalidate focus/restore the floating window level.
    _searchBar=[UISearchBar new]; _searchBar.delegate=self;
    _searchBar.searchBarStyle=UISearchBarStyleMinimal;
    _searchBar.placeholder=@"搜索应用名称或标识";
    _searchBar.text=self.initialQuery ?: @"";
    _searchBar.searchTextField.autocorrectionType=UITextAutocorrectionTypeNo;
    _searchBar.searchTextField.autocapitalizationType=UITextAutocapitalizationTypeNone;
    _searchBar.searchTextField.accessibilityIdentifier=@"harugalaxy.application.search";
    _searchHeader=[UIView new]; [_searchHeader addSubview:_searchBar];
    self.tableView.tableHeaderView=_searchHeader;
    self.tableView.rowHeight=64;
    self.tableView.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag;
    NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(keyboardShown:) name:UIKeyboardDidShowNotification object:nil];
    [center addObserver:self selector:@selector(keyboardShown:) name:UIKeyboardDidChangeFrameNotification object:nil];
    [center addObserver:self selector:@selector(keyboardHidden:) name:UIKeyboardDidHideNotification object:nil];
    _fallback=[UIButton buttonWithType:UIButtonTypeSystem];
    [_fallback setTitle:@"在主应用中搜索" forState:UIControlStateNormal];
    _fallback.titleLabel.font=[UIFont systemFontOfSize:13];
    [_fallback addTarget:self action:@selector(useApplicationSearch) forControlEvents:UIControlEventTouchUpInside];
    [_searchHeader addSubview:_fallback]; _fallback.hidden=!self.searchFallbackHandler;
    [self reloadApplications];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width=self.tableView.bounds.size.width,height=self.searchFallbackHandler ? 100 : 60;
    _searchBar.frame=CGRectMake(8,2,MAX(1,width-16),54);
    _fallback.frame=CGRectMake(12,56,MAX(1,width-24),40);
    if(!CGSizeEqualToSize(_searchHeader.frame.size,CGSizeMake(width,height))) {
        _searchHeader.frame=CGRectMake(0,0,width,height);
        self.tableView.tableHeaderView=_searchHeader;
    }
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated]; self.navigationController.presentationController.delegate=self;
    if(self.automaticallyFocusSearch) {
        self.automaticallyFocusSearch=NO;
        NSUInteger generation=++_focusGeneration;
        __weak typeof(self) weakSelf=self;
        dispatch_async(dispatch_get_main_queue(),^{
            MWAppPickerController *controller=weakSelf;
            if(controller && generation==controller->_focusGeneration && !controller->_finished) [controller requestSearchFocus];
        });
    }
}
- (void)invalidateSearch {
    _finished=YES; _searchExpected=NO; _fallbackStarted=YES; _focusGeneration++;
    self.automaticallyFocusSearch=NO;
    [self.viewIfLoaded endEditing:YES]; [self restoreWindowLevel];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated]; _searchExpected=NO; _focusGeneration++; [self restoreWindowLevel];
}
- (void)restoreWindowLevel {
    if(_levelChanged) { _searchWindow.windowLevel=_originalLevel; _levelChanged=NO; }
}
- (void)prepareSearchWindow {
    UIWindow *window=self.view.window;
    _searchWindow=window;
    if(window && self.searchFallbackHandler && !_levelChanged) {
        _originalLevel=window.windowLevel; _levelChanged=YES;
        // Keep our search sheet below the system keyboard's window layer.
        window.windowLevel=UIWindowLevelNormal+1;
    }
    [window makeKeyWindow];
    [MWKeyboardFocus.shared focusHostWindow:window reason:@"application_search"];
}
- (void)requestSearchFocus {
    if(_finished || !self.viewIfLoaded.window) return;
    _searchExpected=YES; [self prepareSearchWindow];
    BOOL accepted=[_searchBar.searchTextField becomeFirstResponder];
    MWLog(@"search.focus_request",@{@"accepted":@(accepted),@"keyboard":[MWKeyboardFocus.shared snapshot],@"keyWindow":@(self.view.window.isKeyWindow),
        @"sceneState":@(self.view.window.windowScene.activationState),@"windowLevel":@(self.view.window.windowLevel),
        @"floating":@(self.searchFallbackHandler!=nil)});
    [self scheduleKeyboardCheck];
}
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    (void)searchBar;
    if(_finished) return NO;
    _searchExpected=YES; _receivedInput=NO;
    [self prepareSearchWindow]; [self scheduleKeyboardCheck];
    return YES;
}
- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    (void)searchBar; _searchExpected=YES;
}
- (void)scheduleKeyboardCheck {
    NSUInteger generation=++_focusGeneration;
    __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.9*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        [weakSelf checkKeyboard:generation retry:YES];
    });
}
- (void)checkKeyboard:(NSUInteger)generation retry:(BOOL)retry {
    if(generation!=_focusGeneration || !_searchExpected || _finished || !self.viewIfLoaded.window) return;
    MWLog(@"search.keyboard_check",@{@"visible":@(_keyboardVisible),@"firstResponder":@(_searchBar.searchTextField.isFirstResponder),
        @"keyWindow":@(self.view.window.isKeyWindow),@"receivedInput":@(_receivedInput),@"retry":@(retry)});
    if(_keyboardVisible || _receivedInput) return; // Hardware-keyboard input is sufficient.
    if(retry) {
        [self prepareSearchWindow];
        // Avoid recursively restarting the deadline when editing was refused.
        if(_searchBar.searchTextField.isFirstResponder) [_searchBar.searchTextField reloadInputViews];
        __weak typeof(self) weakSelf=self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.6*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            [weakSelf checkKeyboard:generation retry:NO];
        });
    } else if(self.searchFallbackHandler) {
        MWLog(@"search.handoff_automatic",@{});
        [self useApplicationSearch];
    } else {
        MWLog(@"search.keyboard_unavailable",@{@"sceneState":@(self.view.window.windowScene.activationState)});
    }
}
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    (void)searchBar; _searchExpected=NO; _focusGeneration++; [self restoreWindowLevel];
}
- (void)keyboardShown:(NSNotification *)notification {
    if(!_searchExpected || !_searchBar.searchTextField.isFirstResponder || !self.viewIfLoaded.window) return;
    UIWindow *window=self.view.window;
    if([notification.object isKindOfClass:UIScreen.class] && notification.object!=window.screen) return;
    CGRect frame=[notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect local=[window.screen.coordinateSpace convertRect:frame toCoordinateSpace:window];
    CGRect intersection=CGRectIntersection(window.bounds,local);
    _keyboardVisible=!CGRectIsNull(intersection) && intersection.size.width>0 && intersection.size.height>0;
    MWLog(@"search.keyboard_shown",@{@"visible":@(_keyboardVisible),@"height":@(_keyboardVisible ? intersection.size.height : 0),
        @"keyWindow":@(window.isKeyWindow)});
}
- (void)keyboardHidden:(NSNotification *)notification { (void)notification; _keyboardVisible=NO; }
- (void)useApplicationSearch {
    if(_finished || _fallbackStarted || !self.searchFallbackHandler) return;
    _fallbackStarted=YES; _finished=YES; _searchExpected=NO; _focusGeneration++;
    NSString *query=[_searchBar.text copy] ?: @"";
    void (^fallback)(NSString *)=self.searchFallbackHandler;
    [self.view endEditing:YES]; [self restoreWindowLevel];
    MWLog(@"search.main_scene_requested",@{});
    [self dismissPickerAnimated:NO completion:^{fallback(query);}];
}
- (void)dismiss {
    if(_finished) return; _finished=YES;
    [self.view endEditing:YES]; [self restoreWindowLevel];
    void (^cancel)(void)=self.cancellationHandler;
    [self dismissPickerAnimated:YES completion:^{if(cancel) cancel();}];
}
- (void)dismissPickerAnimated:(BOOL)animated completion:(dispatch_block_t)completion {
    UIViewController *container=self.navigationController ?: self;
    UIViewController *presenter=container.presentingViewController;
    _searchExpected=NO; _focusGeneration++; [self.view endEditing:YES]; [self restoreWindowLevel];
    if(presenter) [presenter dismissViewControllerAnimated:animated completion:completion];
    else if(completion) completion();
}
- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    (void)presentationController; [self restoreWindowLevel];
    if(!_finished) { _finished=YES; if(self.cancellationHandler) self.cancellationHandler(); }
}
- (void)reloadApplications {
    UIActivityIndicatorView *spinner=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    [spinner startAnimating]; self.tableView.backgroundView=spinner;
    self.navigationItem.rightBarButtonItem.enabled=NO;
    __weak typeof(self) weakSelf=self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSError *error=nil;
        NSArray *apps=[MWApplicationCatalog applicationsWithError:&error];
        dispatch_async(dispatch_get_main_queue(),^{
            MWAppPickerController *controller=weakSelf;
            if(!controller) return;
            controller->_apps=apps;
            controller.navigationItem.rightBarButtonItem.enabled=YES;
            if(error) {
                UILabel *message=[UILabel new]; message.text=error.localizedDescription;
                message.numberOfLines=0; message.textAlignment=NSTextAlignmentCenter;
                message.textColor=UIColor.secondaryLabelColor; controller.tableView.backgroundView=message;
                controller->_filtered=@[]; controller->_recent=@[]; [controller.tableView reloadData];
            } else [controller filterApplications];
        });
    });
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    (void)searchBar; (void)searchText;
    _receivedInput=YES; [self filterApplications];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar.searchTextField resignFirstResponder]; }
- (void)filterApplications {
    NSString *query=[_searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    _filtered=query.length ? [_apps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(MWApplication *app,NSDictionary *bindings) {
        (void)bindings;
        return [app.name localizedCaseInsensitiveContainsString:query] || [app.bundleIdentifier localizedCaseInsensitiveContainsString:query];
    }]] : _apps;
    NSMutableArray *recent=[NSMutableArray array];
    if(!query.length) for(NSString *bundle in MWPreferences.shared.recentBundleIDs)
        for(MWApplication *app in _apps) if([app.bundleIdentifier isEqual:bundle]) { [recent addObject:app]; break; }
    _recent=recent;
    if(!_filtered.count) {
        UILabel *empty=[UILabel new]; empty.text=query.length ? @"没有找到匹配的应用" : @"暂无可打开的应用，请点击右上角刷新。";
        empty.numberOfLines=0; empty.textAlignment=NSTextAlignmentCenter; empty.textColor=UIColor.secondaryLabelColor;
        self.tableView.backgroundView=empty;
    } else self.tableView.backgroundView=nil;
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return _recent.count ? 2 : 1; }
- (NSArray<MWApplication *> *)appsForSection:(NSInteger)section { return _recent.count && section==0 ? _recent : _filtered; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; return [self appsForSection:section].count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView; return _recent.count && section==0 ? @"最近使用" : @"所有应用";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"app"];
    if(!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"app"];
    MWApplication *app=[self appsForSection:indexPath.section][indexPath.row];
    UIListContentConfiguration *content=[UIListContentConfiguration subtitleCellConfiguration];
    content.text=app.name; content.secondaryText=app.bundleIdentifier;
    content.image=app.icon; content.imageProperties.maximumSize=CGSizeMake(40,40);
    content.imageProperties.cornerRadius=9;
    cell.contentConfiguration=content; cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if(_finished) return; _finished=YES;
    [self.view endEditing:YES]; [self restoreWindowLevel];
    MWApplication *app=[self appsForSection:indexPath.section][indexPath.row];
    void (^handler)(MWApplication *)=self.selectionHandler;
    [self dismissPickerAnimated:YES completion:^{ if(handler) handler(app); }];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end

