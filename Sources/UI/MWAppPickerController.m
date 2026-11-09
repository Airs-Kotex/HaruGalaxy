// SPDX-License-Identifier: Apache-2.0
#import "MWAppPickerController.h"
#import "MWPreferences.h"
#import "../Diagnostics/MWDiagnostics.h"

@interface MWAppPickerController () <UISearchResultsUpdating, UISearchBarDelegate, UIAdaptivePresentationControllerDelegate>
@end
@implementation MWAppPickerController {
    NSArray<MWApplication *> *_apps, *_filtered, *_recent;
    UISearchController *_search;
    BOOL _keyboardVisible, _searchExpected, _finished, _levelChanged;
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
    _search=[[UISearchController alloc] initWithSearchResultsController:nil];
    _search.searchResultsUpdater=self; _search.obscuresBackgroundDuringPresentation=NO;
    _search.searchBar.delegate=self;
    _search.searchBar.placeholder=@"搜索应用名称";
    _search.searchBar.text=self.initialQuery ?: @"";
    self.navigationItem.searchController=_search;
    self.navigationItem.hidesSearchBarWhenScrolling=NO; self.definesPresentationContext=YES;
    self.tableView.rowHeight=64;
    NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(keyboardShown:) name:UIKeyboardDidShowNotification object:nil];
    [center addObserver:self selector:@selector(keyboardHidden:) name:UIKeyboardDidHideNotification object:nil];
    _fallback=[UIButton buttonWithType:UIButtonTypeSystem];
    [_fallback setTitle:@"键盘未显示？在主应用中输入" forState:UIControlStateNormal];
    _fallback.titleLabel.font=[UIFont systemFontOfSize:13];
    [_fallback addTarget:self action:@selector(useApplicationSearch) forControlEvents:UIControlEventTouchUpInside];
    [self reloadApplications];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated]; self.navigationController.presentationController.delegate=self;
    if(self.automaticallyFocusSearch) {
        self.automaticallyFocusSearch=NO; _search.active=YES;
        dispatch_async(dispatch_get_main_queue(),^{ if(self.view.window && !self->_finished) [self->_search.searchBar becomeFirstResponder]; });
    }
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated]; _focusGeneration++; [self restoreWindowLevel];
}
- (void)restoreWindowLevel {
    if(_levelChanged) { _searchWindow.windowLevel=_originalLevel; _levelChanged=NO; }
}
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    (void)searchBar;
    UIWindow *window=self.view.window;
    _searchWindow=window;
    if(window && !_levelChanged) {
        _originalLevel=window.windowLevel; _levelChanged=YES;
        // Keep our search sheet below the system keyboard's window layer.
        window.windowLevel=UIWindowLevelNormal+1; [window makeKeyWindow];
    }
    MWLog(@"search.focus_request",@{@"keyWindow":@(window.isKeyWindow),@"sceneState":@(window.windowScene.activationState),@"windowLevel":@(window.windowLevel)});
    return YES;
}
- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    _searchExpected=YES; NSUInteger generation=++_focusGeneration;
    __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.8*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        MWAppPickerController *controller=weakSelf;
        if(!controller || generation!=controller->_focusGeneration || !controller->_searchExpected || !controller.view.window) return;
        MWLog(@"search.keyboard_check",@{@"visible":@(controller->_keyboardVisible),@"firstResponder":@(searchBar.searchTextField.isFirstResponder),@"keyWindow":@(controller.view.window.isKeyWindow)});
        if(!controller->_keyboardVisible && controller.searchFallbackHandler) [controller showFallback];
    });
}
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    (void)searchBar; _searchExpected=NO; _focusGeneration++; [self restoreWindowLevel];
}
- (void)keyboardShown:(NSNotification *)notification {
    if(!_searchExpected || !_search.searchBar.searchTextField.isFirstResponder) return;
    CGRect frame=[notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    _keyboardVisible=frame.size.height>0;
    MWLog(@"search.keyboard_shown",@{@"height":@(frame.size.height),@"keyWindow":@(self.view.window.isKeyWindow)});
    self.tableView.tableHeaderView=nil;
}
- (void)keyboardHidden:(NSNotification *)notification { (void)notification; _keyboardVisible=NO; }
- (void)showFallback {
    _fallback.frame=CGRectMake(0,0,self.tableView.bounds.size.width,44);
    self.tableView.tableHeaderView=_fallback;
}
- (void)useApplicationSearch {
    if(_finished || !self.searchFallbackHandler) return;
    _finished=YES;
    NSString *query=[_search.searchBar.text copy] ?: @"";
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
    // A UISearchController can itself be presented by this table controller.
    // Dismiss the owner of the enclosing navigation sheet, not that child.
    UIViewController *container=self.navigationController ?: self;
    UIViewController *presenter=container.presentingViewController;
    _search.active=NO; [self.view endEditing:YES]; [self restoreWindowLevel];
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
            } else [controller updateSearchResultsForSearchController:controller->_search];
        });
    });
}
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query=[searchController.searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
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

