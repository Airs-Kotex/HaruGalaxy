// SPDX-License-Identifier: Apache-2.0
#import "MWWindowControlImages.h"

UIImage *MWParkingControlImage(BOOL restore) {
    // Native vector drawing, independent of the installed SF Symbols catalog.
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(20,18)];
    UIImage *image=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        (void)context; [UIColor.blackColor setStroke]; [UIColor.blackColor setFill];
        UIBezierPath *frame=[UIBezierPath bezierPathWithRoundedRect:CGRectMake(1,2,18,14) cornerRadius:2];
        frame.lineWidth=1.5; [frame stroke];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(11,9,6,5) cornerRadius:1] fill];
        UIBezierPath *arrow=[UIBezierPath bezierPath]; arrow.lineWidth=1.6; arrow.lineCapStyle=kCGLineCapRound;
        if(restore) {
            [arrow moveToPoint:CGPointMake(10,9)]; [arrow addLineToPoint:CGPointMake(5,5)];
            [arrow moveToPoint:CGPointMake(5,8)]; [arrow addLineToPoint:CGPointMake(5,5)]; [arrow addLineToPoint:CGPointMake(8,5)];
        } else {
            [arrow moveToPoint:CGPointMake(5,5)]; [arrow addLineToPoint:CGPointMake(10,9)];
            [arrow moveToPoint:CGPointMake(7,9)]; [arrow addLineToPoint:CGPointMake(10,9)]; [arrow addLineToPoint:CGPointMake(10,6)];
        }
        [arrow stroke];
    }];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}
