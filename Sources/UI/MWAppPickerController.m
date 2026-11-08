// SPDX-License-Identifier: Apache-2.0
#import "MWAppPickerController.h"
#import "MWPreferences.h"

@interface MWAppPickerController () <UISearchResultsUpdating>
@end
@implementation MWAppPickerController {
    NSArray<MWApplication *> *_apps, *_filtered, *_recent;
    UISearchController *_search;
}
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"打开应用小窗";
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(dismiss)];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadApplications)];
    _search=[[UISearchController alloc] initWithSearchResultsController:nil];
    _search.searchResultsUpdater=self; _search.obscuresBackgroundDuringPresentation=NO;
    _search.searchBar.placeholder=@"搜索应用名称";
    self.navigationItem.searchController=_search;
    self.navigationItem.hidesSearchBarWhenScrolling=NO; self.definesPresentationContext=YES;
    self.tableView.rowHeight=64;
    [self reloadApplications];
}
- (void)dismiss { [self dismissViewControllerAnimated:YES completion:nil]; }
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
    MWApplication *app=[self appsForSection:indexPath.section][indexPath.row];
    void (^handler)(MWApplication *)=self.selectionHandler;
    [self dismissViewControllerAnimated:YES completion:^{ if(handler) handler(app); }];
}
@end

