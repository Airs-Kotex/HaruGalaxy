// SPDX-License-Identifier: Apache-2.0
#import <Foundation/Foundation.h>
FOUNDATION_EXPORT void MWLog(NSString *event, NSDictionary *fields);
FOUNDATION_EXPORT void MWTrace(NSString *event, NSDictionary *fields);
FOUNDATION_EXPORT NSDictionary *MWErrorFields(NSError *error);
FOUNDATION_EXPORT NSString *const MWKeyboardDiagnosticSampleNotification;

@interface MWDiagnostics : NSObject
+ (instancetype)shared;
@property(nonatomic) BOOL detailed;
@property(nonatomic,copy,readonly) NSString *sessionIdentifier;
- (void)start;
- (void)flush;
- (void)flushSoon;
- (void)markProblem;
- (void)startKeyboardCapture;
@property(nonatomic,readonly) BOOL keyboardCaptureActive;
- (NSDictionary *)environmentSnapshot;
- (void)exportWithCompletion:(void (^)(NSURL *file, NSError *error))completion;
- (void)clearWithCompletion:(void (^)(NSError *error))completion;
@end
